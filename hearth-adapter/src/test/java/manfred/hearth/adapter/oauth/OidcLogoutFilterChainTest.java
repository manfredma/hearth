package manfred.hearth.adapter.oauth;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import jakarta.servlet.Filter;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import manfred.hearth.adapter.web.security.LegacyHearthPrincipalMigrationFilter;
import manfred.hearth.adapter.web.security.SecurityConfig;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mock.web.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.*;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.core.oidc.OidcIdToken;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.authorization.*;
import org.springframework.security.oauth2.server.authorization.client.*;
import org.springframework.security.oauth2.server.authorization.settings.AuthorizationServerSettings;
import org.springframework.web.context.support.AnnotationConfigWebApplicationContext;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class OidcLogoutFilterChainTest {
    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void protocolLogoutClearsSessionAndPersistentCookie(boolean remembered) throws Exception {
        try (var context = new AnnotationConfigWebApplicationContext()) {
            context.setServletContext(new MockServletContext());
            context.register(Fixtures.class, SecurityConfig.class, AuthorizationServerSecurityConfig.class);
            context.getEnvironment().getPropertySources().addFirst(new org.springframework.core.env.MapPropertySource(
                    "test", Map.of("hearth.authentication.remember-me-key", "key")));
            context.refresh();
            var chain = context.getBean("springSecurityFilterChain", Filter.class);
            var services = context.getBean(HearthRememberMeServices.class);
            var user = User.withUsername("admin").password("hash").authorities(List.of()).build();
            var auth = UsernamePasswordAuthenticationToken.authenticated(user, null, user.getAuthorities());
            var loginResponse = new MockHttpServletResponse();
            services.onInteractiveLogin(new MockHttpServletRequest(), loginResponse, auth, remembered);
            var session = new MockHttpSession();
            var security = SecurityContextHolder.createEmptyContext();
            security.setAuthentication(auth);
            session.setAttribute("SPRING_SECURITY_CONTEXT", security);
            var client = context.getBean(RegisteredClientRepository.class).findByClientId("client");
            context.getBean(OAuth2AuthorizationService.class).save(OAuth2Authorization.withRegisteredClient(client)
                    .principalName("admin").authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
                    .attribute(java.security.Principal.class.getName(), auth)
                    .token(new OidcIdToken("id-token", Instant.now().minusSeconds(10), Instant.now().plusSeconds(60),
                            Map.of("sub", "subject", "aud", List.of("client")))).build());
            var request = new MockHttpServletRequest("GET", "/connect/logout");
            request.setServletPath("/connect/logout");
            request.setSession(session);
            if (remembered) request.setCookies(loginResponse.getCookie("hearth-remember-me"));
            request.addParameter("id_token_hint", "id-token");
            request.addParameter("post_logout_redirect_uri", "https://client.test/logged-out");
            request.setQueryString("id_token_hint=id-token&post_logout_redirect_uri=https%3A%2F%2Fclient.test%2Flogged-out");
            var response = new MockHttpServletResponse();
            chain.doFilter(request, response, new MockFilterChain());
            assertThat(response.getStatus()).as(response.getContentAsString()).isEqualTo(302);
            assertThat(response.getRedirectedUrl()).isEqualTo("https://client.test/logged-out");
            assertThat(session.isInvalid()).isTrue();
            assertThat(response.getCookie("hearth-remember-me")).isNotNull();
            assertThat(response.getCookie("hearth-remember-me").getMaxAge()).isZero();
            var after = new MockHttpServletRequest("GET", "/api/session");
            after.setServletPath("/api/session");
            var afterResponse = new MockHttpServletResponse();
            chain.doFilter(after, afterResponse, new MockFilterChain());
            assertThat(afterResponse.getStatus()).isEqualTo(403);
            // An RP may repeat a valid logout without a Hearth session.
            var anonymousLogout = new MockHttpServletRequest("GET", "/connect/logout");
            anonymousLogout.setServletPath("/connect/logout");
            anonymousLogout.addParameter("id_token_hint", "id-token");
            anonymousLogout.addParameter("post_logout_redirect_uri", "https://client.test/logged-out");
            anonymousLogout.setQueryString(request.getQueryString());
            var repeated = new MockHttpServletResponse();
            chain.doFilter(anonymousLogout, repeated, new MockFilterChain());
            assertThat(repeated.getRedirectedUrl()).isEqualTo("https://client.test/logged-out");
            assertThat(repeated.getCookie("hearth-remember-me").getMaxAge()).isZero();
        } finally {
            SecurityContextHolder.clearContext();
        }
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
                    .redirectUri("https://client.test/callback").postLogoutRedirectUri("https://client.test/logged-out")
                    .scope("openid").build());
        }
        @Bean OAuth2AuthorizationService authorizations() { return new InMemoryOAuth2AuthorizationService(); }
        @Bean OAuth2AuthorizationConsentService consents() { return new InMemoryOAuth2AuthorizationConsentService(); }
    }
}
