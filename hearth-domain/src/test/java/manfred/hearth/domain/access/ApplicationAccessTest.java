package manfred.hearth.domain.access;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;

import manfred.hearth.domain.application.ApplicationKey;
import org.junit.jupiter.api.Test;

class ApplicationAccessTest {

    @Test
    void acceptsNamespacedRoleKey() {
        ApplicationAccess access = new ApplicationAccess(UUID.randomUUID(), new ApplicationKey("daylilt"),
                "daylilt:editor");
        assertThat(access.roleKey()).isEqualTo("daylilt:editor");
    }

    @Test
    void rejectsMissingOrUnnamespacedFields() {
        ApplicationKey application = new ApplicationKey("daylilt");
        assertThatThrownBy(() -> new ApplicationAccess(null, application, "daylilt:editor"))
                .isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> new ApplicationAccess(UUID.randomUUID(), null, "daylilt:editor"))
                .isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> new ApplicationAccess(UUID.randomUUID(), application, null))
                .isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> new ApplicationAccess(UUID.randomUUID(), application, "editor"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new ApplicationAccess(UUID.randomUUID(), application, "daylilt:"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
