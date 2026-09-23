package manfred.hearth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.SpringBootApplication;

class HearthApplicationTest {

    @Test
    void isSpringBootApplication() {
        assertThat(HearthApplication.class.isAnnotationPresent(SpringBootApplication.class)).isTrue();
    }
}
