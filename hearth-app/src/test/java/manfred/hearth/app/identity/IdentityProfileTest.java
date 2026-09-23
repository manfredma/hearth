package manfred.hearth.app.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class IdentityProfileTest {

    @Test
    void acceptsDisplayNameWithOptionalEmail() {
        assertThat(new IdentityProfile("冯华杰", null).displayName()).isEqualTo("冯华杰");
        assertThat(new IdentityProfile("冯华杰", "feng@example.com").email()).isEqualTo("feng@example.com");
    }

    @Test
    void rejectsMissingOrBlankProfileFields() {
        assertThatThrownBy(() -> new IdentityProfile(null, null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new IdentityProfile(" ", null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new IdentityProfile("name", " ")).isInstanceOf(IllegalArgumentException.class);
    }
}
