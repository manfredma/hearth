package manfred.hearth.adapter.web.security;

import java.time.*;
import java.util.*;
import manfred.hearth.app.identity.*;
import manfred.hearth.domain.identity.*;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.mock.web.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.*;
import org.springframework.security.oauth2.core.oidc.OidcIdToken;
import org.springframework.security.oauth2.core.oidc.user.*;
import org.springframework.web.context.request.ServletWebRequest;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class IdentityBoundaryTest {
    private final UUID id = UUID.randomUUID();
    private final IdentityCredentialPort credentials = mock(IdentityCredentialPort.class);
    private final IdentityDirectoryPort directory = mock(IdentityDirectoryPort.class);
    private final CurrentIdentityArgumentResolver resolver = new CurrentIdentityArgumentResolver(directory, credentials, new OidcIdentityMapper());

    @Test
    void resolvesLegacyAndLocalAndOidcPrincipalsButRejectsUnknownAccounts() {
        assertThat(resolve(new HearthPrincipal(id, "admin", "Admin", null))).isEqualTo(new CurrentIdentity(id, "admin", "Admin"));
        var user = User.withUsername("admin").password("").authorities(List.of()).build();
        assertThatThrownBy(() -> resolve(user)).hasMessageContaining("not found");
        when(credentials.findByLogin("admin")).thenReturn(Optional.of(new PasswordCredential(id, "admin", "hash", true, 0, null)));
        assertThatThrownBy(() -> resolve(user)).hasMessageContaining("not found");
        var account = new IdentityAccount(id, new IdentitySubject("https://hearth.test", "subject"), "Admin", null);
        when(directory.findById(id)).thenReturn(Optional.of(account));
        assertThat(resolve(user)).isEqualTo(new CurrentIdentity(id, "admin", "Admin"));
        when(directory.findOrCreate(any(), any())).thenReturn(account);
        assertThat(resolve(oidc(Map.of("name", "Admin")))).isEqualTo(new CurrentIdentity(id, "subject", "Admin"));
        assertThatThrownBy(() -> resolve("anonymous")).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> resolver.resolveArgument(null, null, new ServletWebRequest(new MockHttpServletRequest()), null))
                .isInstanceOf(IllegalStateException.class);
    }

    Object resolve(Object principal) {
        var request = new MockHttpServletRequest();
        request.setUserPrincipal(UsernamePasswordAuthenticationToken.authenticated(principal, null, List.of()));
        return resolver.resolveArgument(null, null, new ServletWebRequest(request), null);
    }

    @Test
    void registersOnlyCurrentIdentityParameters() throws Exception {
        var method = IdentityBoundaryTest.class.getDeclaredMethod("parameters", CurrentIdentity.class, String.class);
        assertThat(resolver.supportsParameter(new MethodParameter(method, 0))).isTrue();
        assertThat(resolver.supportsParameter(new MethodParameter(method, 1))).isFalse();
        var resolvers = new ArrayList<org.springframework.web.method.support.HandlerMethodArgumentResolver>();
        new WebMvcSecurityConfig(resolver).addArgumentResolvers(resolvers);
        assertThat(resolvers).containsExactly(resolver);
    }
    private void parameters(CurrentIdentity identity, String unrelated) { }

    @Test
    void profileFallbackAndInvalidSubjectsAreExplicit() throws Exception {
        var mapper = new OidcIdentityMapper();
        assertThat(mapper.map(oidc(Map.of("name", " ", "preferred_username", "login"))).profile().displayName()).isEqualTo("login");
        assertThat(mapper.map(oidc(Map.of("email", "admin@example.test"))).profile().displayName()).isEqualTo("admin@example.test");
        assertThat(mapper.map(oidc(Map.of())).profile().displayName()).isEqualTo("subject");
        OidcUser invalid = mock(OidcUser.class);
        when(invalid.getIssuer()).thenReturn(java.net.URI.create("https://hearth.test").toURL());
        assertThatThrownBy(() -> mapper.map(invalid)).isInstanceOf(IllegalArgumentException.class);
        when(invalid.getClaimAsString("sub")).thenReturn(" ");
        assertThatThrownBy(() -> mapper.map(invalid)).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void oidcSuccessStoresMappedIdentityAndRejectsNonOidc() throws Exception {
        var handler = new OidcLoginSuccessHandler(directory, new OidcIdentityMapper());
        var request = new MockHttpServletRequest();
        var response = new MockHttpServletResponse();
        when(directory.findOrCreate(any(), any())).thenReturn(new IdentityAccount(id,
                new IdentitySubject("https://hearth.test", "subject"), "Admin", null));
        handler.onAuthenticationSuccess(request, response, UsernamePasswordAuthenticationToken.authenticated(oidc(Map.of()), null, List.of()));
        assertThat(request.getSession().getAttribute("HEARTH_IDENTITY_ID")).isEqualTo(id.toString());
        assertThat(response.getRedirectedUrl()).isEqualTo("/");
        assertThatThrownBy(() -> handler.onAuthenticationSuccess(request, response,
                UsernamePasswordAuthenticationToken.authenticated("anonymous", null, List.of()))).isInstanceOf(IllegalStateException.class);
    }

    @Test
    void unavailableRememberedIdentityCannotAuthenticate() {
        when(credentials.findByLogin("admin")).thenReturn(Optional.of(new PasswordCredential(id, "admin", "hash", true, 0, null)));
        assertThatThrownBy(() -> new HearthRememberMeUserDetailsService(credentials, directory, Clock.systemUTC()).loadUserByUsername("admin"))
                .isInstanceOf(UsernameNotFoundException.class);
        var config = new PasswordLoginConfiguration();
        var encoder = config.passwordEncoder();
        assertThat(encoder.matches("secret", encoder.encode("secret"))).isTrue();
        assertThatThrownBy(() -> config.passwordLoginService(credentials, encoder, Clock.systemUTC(), 5, Duration.ofMinutes(1))
                .authenticate("missing", "secret")).isInstanceOf(PasswordLoginService.InvalidCredentialsException.class);
    }

    @Test
    void migrationPreservesUnrelatedAndAlreadyFactoredAuthentication() throws Exception {
        var filter = new LegacyHearthPrincipalMigrationFilter(Clock.systemUTC());
        try {
            for (Object principal : List.of("anonymous", User.withUsername("admin").password("")
                    .authorities(HearthAuthenticationFactors.password(Clock.systemUTC())).build())) {
                var authorities = principal instanceof User user ? user.getAuthorities() : List.<org.springframework.security.core.GrantedAuthority>of();
                var auth = UsernamePasswordAuthenticationToken.authenticated(principal, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(auth);
                filter.doFilter(new MockHttpServletRequest(), new MockHttpServletResponse(), new MockFilterChain());
                assertThat(SecurityContextHolder.getContext().getAuthentication()).isSameAs(auth);
            }
        } finally { SecurityContextHolder.clearContext(); }
    }

    @Test
    void legacyPrincipalRejectsBlankFieldsAndHasNoPassword() {
        for (String blank : new String[]{null, " "}) {
            assertThatThrownBy(() -> new HearthPrincipal(id, blank, "Admin", null)).isInstanceOf(IllegalArgumentException.class);
            assertThatThrownBy(() -> new HearthPrincipal(id, "admin", blank, null)).isInstanceOf(IllegalArgumentException.class);
        }
        assertThatThrownBy(() -> new HearthPrincipal(id, "admin", "Admin", " ")).isInstanceOf(IllegalArgumentException.class);
        var principal = new HearthPrincipal(id, "admin", "Admin", "admin@example.test");
        assertThat(principal.getPassword()).isNull();
        assertThat(principal.getAuthorities()).isEmpty();
        assertThat(principal.isAccountNonExpired()).isTrue();
        assertThat(principal.isAccountNonLocked()).isTrue();
        assertThat(principal.isCredentialsNonExpired()).isTrue();
        assertThat(principal.isEnabled()).isTrue();
    }

    private OidcUser oidc(Map<String, Object> profile) {
        var claims = new HashMap<String, Object>(profile);
        claims.put("iss", "https://hearth.test");
        claims.put("sub", "subject");
        return new DefaultOidcUser(List.of(), new OidcIdToken("token", Instant.now(), Instant.now().plusSeconds(60), claims));
    }
}
