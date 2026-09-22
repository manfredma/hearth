package manfred.hearth.domain.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class ApplicationKeyTest {

    @Test
    void acceptsLowercaseKebabCase() {
        assertThat(new ApplicationKey("daylilt-editor").value()).isEqualTo("daylilt-editor");
    }

    @Test
    void rejectsNullAndInvalidValues() {
        assertThatThrownBy(() -> new ApplicationKey(null)).isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> new ApplicationKey("Daylilt")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new ApplicationKey("daylilt_")).isInstanceOf(IllegalArgumentException.class);
    }
}
