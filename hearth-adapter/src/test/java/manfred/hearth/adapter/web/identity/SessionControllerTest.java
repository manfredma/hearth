package manfred.hearth.adapter.web.identity;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;

import manfred.hearth.app.identity.CurrentIdentity;
import org.junit.jupiter.api.Test;

class SessionControllerTest {

    @Test
    void exposesOnlyTheCurrentIdentitySummary() {
        UUID userId = UUID.randomUUID();
        SessionController.SessionResponse response = new SessionController()
                .current(new CurrentIdentity(userId, "admin", "冯华杰"));

        assertThat(response.authenticated()).isTrue();
        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.username()).isEqualTo("admin");
        assertThat(response.displayName()).isEqualTo("冯华杰");
    }
}
