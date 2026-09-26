package manfred.hearth.domain.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;

import org.junit.jupiter.api.Test;

class IdentityAccountTest {

    private final IdentitySubject subject = new IdentitySubject("https://id.example.com", "sub-1");
    private final UUID id = UUID.randomUUID();

    @Test
    void acceptsOptionalEmail() {
        assertThat(new IdentityAccount(id, subject, "冯华杰", null).displayName()).isEqualTo("冯华杰");
        assertThat(new IdentityAccount(id, subject, "冯华杰", "feng@example.com").email())
                .isEqualTo("feng@example.com");
    }

    @Test
    void rejectsMissingIdentityFields() {
        assertThatThrownBy(() -> new IdentityAccount(null, subject, "name", null))
                .isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> new IdentityAccount(id, null, "name", null))
                .isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> new IdentityAccount(id, subject, " ", null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new IdentityAccount(id, subject, "name", " "))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
