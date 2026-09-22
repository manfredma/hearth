package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SecurityRoutingTest {

    @Test
    void oidcLoginRouteIsProviderNeutral() {
        assertThat("/oauth2/authorization/hearth").startsWith("/oauth2/authorization/");
        assertThat("/api/session/logout").isEqualTo("/api/session/logout");
    }
}
