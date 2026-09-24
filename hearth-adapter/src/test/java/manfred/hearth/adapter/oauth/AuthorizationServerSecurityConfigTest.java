package manfred.hearth.adapter.oauth;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.springframework.security.config.annotation.web.configurers.CsrfConfigurer;

import static org.assertj.core.api.Assertions.assertThat;

class AuthorizationServerSecurityConfigTest {

    @Test
    void exposesTheSharedCsrfConfigurationForTheAuthorizationServerChain() throws Exception {
        Method csrfConfiguration = AuthorizationServerSecurityConfig.class
                .getDeclaredMethod("configureCsrf", CsrfConfigurer.class);

        assertThat(csrfConfiguration.getParameterTypes())
                .containsExactly(CsrfConfigurer.class);
        assertThat(csrfConfiguration.getReturnType()).isEqualTo(void.class);
    }
}
