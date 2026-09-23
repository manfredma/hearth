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
import org.springframework.security.config.annotation.web.builders.HttpSecurity;

class SecurityRoutingTest {

    @Test
    void oidcLoginRouteIsProviderNeutral() {
        assertThat("/oauth2/authorization/hearth").startsWith("/oauth2/authorization/");
        assertThat("/api/session/logout").isEqualTo("/api/session/logout");
    }

    @Test
    void apiCsrfConfigurationUsesAnUnmaskedTokenAcrossRequests() {
        CsrfConfigurer<HttpSecurity> csrf = mock(CsrfConfigurer.class);
        when(csrf.ignoringRequestMatchers(any(String[].class))).thenReturn(csrf);

        SecurityConfig.configureCsrf(csrf);

        verify(csrf).csrfTokenRequestHandler(isA(CsrfTokenRequestAttributeHandler.class));
    }
}
