package manfred.hearth.adapter.oauth;

import java.time.Clock;
import java.util.List;
import java.util.Map;

import jakarta.servlet.Filter;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.web.csrf.CsrfToken;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import manfred.hearth.adapter.web.security.LegacyHearthPrincipalMigrationFilter;
import manfred.hearth.adapter.web.security.SecurityConfig;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.MapPropertySource;
import org.springframework.mock.web.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.*;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.authorization.*;
import org.springframework.security.oauth2.server.authorization.client.*;
import org.springframework.security.oauth2.server.authorization.settings.*;
import org.springframework.web.context.support.AnnotationConfigWebApplicationContext;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class RememberMeAuthorizationFilterChainTest {
    private AnnotationConfigWebApplicationContext context;
    private Filter chain;

    @BeforeEach
    void openContext() {
        context = new AnnotationConfigWebApplicationContext();
        context.setServletContext(new MockServletContext());
        context.register(Fixtures.class, SecurityConfig.class, AuthorizationServerSecurityConfig.class);
        context.getEnvironment().getPropertySources().addFirst(new MapPropertySource(
                "test", Map.of("hearth.authentication.remember-me-key", "key")));
        context.refresh();
        chain = context.getBean("springSecurityFilterChain", Filter.class);
    }

    @AfterEach
    void closeContext() {
        SecurityContextHolder.clearContext();
        context.close();
    }

    @Test
    void firstAuthorizationWithOnlyRememberMeCookieIssuesCode() throws Exception {
        var request = authorizationRequest();
        request.setCookies(rememberedCookie());
        var response = new MockHttpServletResponse();
        chain.doFilter(request, response, new MockFilterChain());
        assertThat(response.getStatus()).as(response.getErrorMessage()).isEqualTo(302);
        assertThat(response.getRedirectedUrl()).startsWith("https://client.test/callback?code=")
                .doesNotContain("error=").contains("state=test-state");
    }

    @Test
    void restoredSessionIsSavedAndCanAuthorizeWithoutPersistentCookie() throws Exception {
        var anonymousSession = new MockHttpSession();
        String anonymousId = anonymousSession.getId();
        var request = authorizationRequest();
        request.setSession(anonymousSession);
        request.setCookies(rememberedCookie());
        assertCode(filter(request));
        var session = (MockHttpSession) request.getSession(false);
        assertThat(session).isNotNull();
        assertThat(session.getId()).isNotEqualTo(anonymousId);
        var saved = (SecurityContext) session.getAttribute("SPRING_SECURITY_CONTEXT");
        assertThat(saved.getAuthentication().getName()).isEqualTo("admin");
        assertThat(saved.getAuthentication().isAuthenticated()).isTrue();
        var next = authorizationRequest();
        next.setSession(session);
        assertCode(filter(next));
    }

    @ParameterizedTest
    @ValueSource(strings = {"missing", "invalid", "expired"})
    void unavailableRememberMeCookieRequiresLogin(String kind) throws Exception {
        var request = authorizationRequest();
        if ("invalid".equals(kind)) {
            request.setCookies(new Cookie("hearth-remember-me", Base64.getEncoder().encodeToString(
                    ("admin:" + (System.currentTimeMillis() + 60000) + ":SHA256:invalid-signature")
                            .getBytes(StandardCharsets.UTF_8))));
        } else if ("expired".equals(kind)) {
            request.setCookies(new ExpiredCookieServices().expiredCookie());
        }
        var response = filter(request);
        assertThat(response.getStatus()).isEqualTo(302);
        assertThat(response.getRedirectedUrl()).startsWith("/login?continue=")
                .doesNotContain("error=", "code=");
        var session = request.getSession(false);
        assertThat(session == null ? null : session.getAttribute("SPRING_SECURITY_CONTEXT")).isNull();
        if (!"missing".equals(kind)) {
            assertThat(response.getCookie("hearth-remember-me")).isNotNull();
            assertThat(response.getCookie("hearth-remember-me").getMaxAge()).isZero();
        }
    }

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void existingSessionIdentityTakesPriorityOverPersistentCookie(boolean withCookie) throws Exception {
        var user = User.withUsername("session-user").password("").authorities(List.of()).build();
        var security = SecurityContextHolder.createEmptyContext();
        security.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(user, null, user.getAuthorities()));
        var session = new MockHttpSession();
        session.setAttribute("SPRING_SECURITY_CONTEXT", security);
        var request = authorizationRequest();
        request.setSession(session);
        if (withCookie) request.setCookies(rememberedCookie());
        var response = filter(request);
        assertCode(response);
        String code = org.springframework.web.util.UriComponentsBuilder.fromUriString(response.getRedirectedUrl())
                .build().getQueryParams().getFirst("code");
        var authorization = context.getBean(OAuth2AuthorizationService.class)
                .findByToken(code, new OAuth2TokenType("code"));
        assertThat(authorization).isNotNull();
        assertThat(authorization.getPrincipalName()).isEqualTo("session-user");
    }

    @Test
    void rememberMeDoesNotBypassPkceValidation() throws Exception {
        var request = authorizationRequest();
        request.setCookies(rememberedCookie());
        request.removeParameter("code_challenge");
        request.removeParameter("code_challenge_method");
        var response = filter(request);
        assertThat(response.getRedirectedUrl()).contains("error=invalid_request", "code_challenge")
                .doesNotContain("?code=", "&code=");
    }

    @Test
    void localLogoutRequiresCsrfAndClearsRestoredSessionAndCookie() throws Exception {
        var request = authorizationRequest();
        request.setCookies(rememberedCookie());
        assertCode(filter(request));
        var session = (MockHttpSession) request.getSession(false);
        var withoutCsrf = new MockHttpServletRequest("POST", "/api/session/logout");
        withoutCsrf.setServletPath("/api/session/logout");
        withoutCsrf.setSession(session);
        assertThat(filter(withoutCsrf).getStatus()).isEqualTo(403);
        assertThat(session.isInvalid()).isFalse();

        var csrfRequest = new MockHttpServletRequest("GET", "/api/session");
        csrfRequest.setServletPath("/api/session");
        csrfRequest.setSession(session);
        var csrfResponse = filter(csrfRequest);
        var csrf = (CsrfToken) csrfRequest.getAttribute(CsrfToken.class.getName());
        String csrfValue = csrf.getToken();
        var logout = new MockHttpServletRequest("POST", "/api/session/logout");
        logout.setServletPath("/api/session/logout");
        logout.setSession(session);
        logout.setCookies(csrfResponse.getCookie("XSRF-TOKEN"), rememberedCookie());
        logout.addHeader(csrf.getHeaderName(), csrfValue);
        var response = filter(logout);
        assertThat(response.getStatus()).isEqualTo(204);
        assertThat(session.isInvalid()).isTrue();
        assertThat(response.getCookie("hearth-remember-me").getMaxAge()).isZero();
        assertThat(filter(authorizationRequest()).getRedirectedUrl()).contains("/login?continue=");
    }

    private MockHttpServletResponse filter(MockHttpServletRequest request) throws Exception {
        var response = new MockHttpServletResponse();
        chain.doFilter(request, response, new MockFilterChain());
        return response;
    }

    private void assertCode(MockHttpServletResponse response) {
        assertThat(response.getStatus()).isEqualTo(302);
        assertThat(response.getRedirectedUrl()).startsWith("https://client.test/callback?code=")
                .doesNotContain("error=").contains("state=test-state");
    }

    private Cookie rememberedCookie() {
        var user = User.withUsername("admin").password("hash").authorities(List.of()).build();
        var response = new MockHttpServletResponse();
        context.getBean(HearthRememberMeServices.class).onInteractiveLogin(new MockHttpServletRequest(), response,
                UsernamePasswordAuthenticationToken.authenticated(user, null, user.getAuthorities()), true);
        return response.getCookie("hearth-remember-me");
    }

    private static class ExpiredCookieServices extends HearthRememberMeServices {
        ExpiredCookieServices() {
            super("key", name -> User.withUsername(name).password("hash").authorities(List.of()).build(),
                    Clock.systemUTC(), false);
        }

        Cookie expiredCookie() {
            long expiry = System.currentTimeMillis() - 60000;
            String signature = makeTokenSignature(expiry, "admin", "hash", RememberMeTokenAlgorithm.SHA256);
            return new Cookie("hearth-remember-me", encodeCookie(
                    new String[]{"admin", Long.toString(expiry), "SHA256", signature}));
        }
    }

    private MockHttpServletRequest authorizationRequest() {
        var request = new MockHttpServletRequest("GET", "/oauth2/authorize");
        request.setServletPath("/oauth2/authorize");
        request.addParameter("response_type", "code");
        request.addParameter("client_id", "client");
        request.addParameter("redirect_uri", "https://client.test/callback");
        request.addParameter("scope", "openid");
        request.addParameter("state", "test-state");
        request.addParameter("nonce", "test-nonce");
        request.addParameter("code_challenge", "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
        request.addParameter("code_challenge_method", "S256");
        request.setQueryString("response_type=code&client_id=client&redirect_uri=https%3A%2F%2Fclient.test%2Fcallback"
                + "&scope=openid&state=test-state&nonce=test-nonce"
                + "&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256");
        return request;
    }

    @Configuration(proxyBeanMethods = false)
    @EnableWebSecurity
    static class Fixtures {
        @Bean Clock clock() { return Clock.systemUTC(); }
        @Bean UserDetailsService users() { return name -> User.withUsername(name).password("hash").authorities(List.of()).build(); }
        @Bean LegacyHearthPrincipalMigrationFilter migration(Clock clock) { return new LegacyHearthPrincipalMigrationFilter(clock); }
        @Bean JwtDecoder decoder() { return mock(JwtDecoder.class); }
        @Bean AuthorizationServerSettings settings() { return AuthorizationServerSettings.builder().issuer("https://hearth.test").build(); }
        @Bean RegisteredClientRepository clients() {
            return new InMemoryRegisteredClientRepository(RegisteredClient.withId("client-id").clientId("client")
                    .clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
                    .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
                    .redirectUri("https://client.test/callback").scope("openid")
                    .clientSettings(ClientSettings.builder().requireProofKey(true).build()).build());
        }
        @Bean OAuth2AuthorizationService authorizations() { return new InMemoryOAuth2AuthorizationService(); }
        @Bean OAuth2AuthorizationConsentService consents() { return new InMemoryOAuth2AuthorizationConsentService(); }
    }
}
