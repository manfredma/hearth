package manfred.hearth.adapter.oauth;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.security.config.annotation.web.configurers.CsrfConfigurer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthorizationServerSecurityConfigTest {

    @Test
    void ignoresSpringCsrfForAuthorizationServerEndpointsBecauseOauthStateProtectsConsent() throws Exception {
        CsrfConfigurer<HttpSecurity> csrf = mock(CsrfConfigurer.class);
        RequestMatcher endpoints = mock(RequestMatcher.class);
        when(csrf.ignoringRequestMatchers(endpoints)).thenReturn(csrf);
        when(csrf.ignoringRequestMatchers("/connect/logout")).thenReturn(csrf);
        Method csrfConfiguration = AuthorizationServerSecurityConfig.class
                .getDeclaredMethod("configureCsrf", CsrfConfigurer.class, RequestMatcher.class);

        assertThat(csrfConfiguration.getParameterTypes())
                .containsExactly(CsrfConfigurer.class, RequestMatcher.class);
        assertThat(csrfConfiguration.getReturnType()).isEqualTo(void.class);
        csrfConfiguration.invoke(null, csrf, endpoints);
        verify(csrf).ignoringRequestMatchers(endpoints);
        verify(csrf).ignoringRequestMatchers("/connect/logout");
    }

    @Test
    void exposesOidcLogoutToUnauthenticatedRelyingPartiesForProtocolValidation() {
        assertThat(AuthorizationServerSecurityConfig.publicEndpoints())
                .containsExactly("/connect/logout");
    }
}
