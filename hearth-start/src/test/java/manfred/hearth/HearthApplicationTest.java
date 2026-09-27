package manfred.hearth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.SpringBootApplication;

class HearthApplicationTest {

    @Test
    void bootstrapUsesTheHearthConfigurationAndOriginalArguments() {
        try (var application = org.mockito.Mockito.mockStatic(org.springframework.boot.SpringApplication.class)) {
            String[] arguments = {"--spring.profiles.active=test"};
            HearthApplication.main(arguments);
            application.verify(() -> org.springframework.boot.SpringApplication.run(HearthApplication.class, arguments));
            assertThat(new HearthApplication()).isNotNull();
            assertThat(new HearthSessionConfiguration()).isNotNull();
        }
    }

    @Test
    void isSpringBootApplication() {
        assertThat(HearthApplication.class.isAnnotationPresent(SpringBootApplication.class)).isTrue();
    }
}
