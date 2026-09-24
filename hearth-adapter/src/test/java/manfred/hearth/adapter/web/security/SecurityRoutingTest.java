package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.isA;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.springframework.security.config.annotation.web.configurers.CsrfConfigurer;
import org.springframework.security.web.csrf.CsrfTokenRequestAttributeHandler;
import org.springframework.security.web.csrf.CsrfTokenRepository;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;

class SecurityRoutingTest {

    @Test
    void oidcLoginRouteIsProviderNeutral() {
        assertThat("/oauth2/authorization/hearth").startsWith("/oauth2/authorization/");
        assertThat("/api/session/logout").isEqualTo("/api/session/logout");
    }

    @Test
    void brandFaviconIsPublicSoItCannotReplaceAnOidcSavedRequest() {
        assertThat(SecurityConfig.publicRequestMatchers()).contains("/favicon.svg");
        assertThat(SecurityConfig.publicRequestMatchers()).contains("/consent-preview");
    }

    @Test
    void apiCsrfConfigurationUsesAnUnmaskedTokenAcrossRequests() {
        CsrfConfigurer<HttpSecurity> csrf = mock(CsrfConfigurer.class);
        when(csrf.ignoringRequestMatchers(any(String[].class))).thenReturn(csrf);
        when(csrf.csrfTokenRepository(any(CsrfTokenRepository.class))).thenReturn(csrf);

        SecurityConfig.configureCsrf(csrf);

        verify(csrf).csrfTokenRequestHandler(isA(CsrfTokenRequestAttributeHandler.class));
        verify(csrf).csrfTokenRepository(isA(CookieCsrfTokenRepository.class));
    }
}
