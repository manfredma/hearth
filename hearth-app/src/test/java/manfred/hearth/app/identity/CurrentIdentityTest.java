package manfred.hearth.app.identity;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;

import org.junit.jupiter.api.Test;

class CurrentIdentityTest {

    @Test
    void exposesSessionIdentity() {
        UUID userId = UUID.randomUUID();
        CurrentIdentity identity = new CurrentIdentity(userId, "冯华杰");

        assertThat(identity.userId()).isEqualTo(userId);
        assertThat(identity.displayName()).isEqualTo("冯华杰");
    }
}
