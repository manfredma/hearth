package manfred.hearth.domain.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;

import java.util.Set;

import org.junit.jupiter.api.Test;

class ApplicationRegistrationTest {

    @Test
    void copiesAndValidatesRegistration() {
        ApplicationRegistration registration = new ApplicationRegistration(
                new ApplicationKey("daylilt"),
                "Daylilt",
                Set.of("https://daylilt.example.com/login/oauth2/code/hearth"));

        assertThat(registration.key().value()).isEqualTo("daylilt");
        assertThat(registration.redirectUris()).containsExactly("https://daylilt.example.com/login/oauth2/code/hearth");
    }

    @Test
    void allowsLocalDevelopmentRedirectUri() {
        ApplicationRegistration registration = new ApplicationRegistration(
                new ApplicationKey("toolbox"), "Toolbox", Set.of("http://localhost:3000/callback"));

        assertThat(registration.redirectUris()).contains("http://localhost:3000/callback");
    }

    @Test
    void rejectsInvalidApplicationKey() {
        assertThatIllegalArgumentException().isThrownBy(() -> new ApplicationKey("Day Lilt"));
    }

    @Test
    void rejectsBlankDisplayName() {
        assertThatIllegalArgumentException().isThrownBy(() -> new ApplicationRegistration(
                new ApplicationKey("daylilt"), " ", Set.of("https://daylilt.example.com/callback")));
    }

    @Test
    void rejectsInsecureNonLocalRedirectUri() {
        assertThatIllegalArgumentException().isThrownBy(() -> new ApplicationRegistration(
                new ApplicationKey("daylilt"), "Daylilt", Set.of("http://daylilt.example.com/callback")));
    }

    @Test
    void rejectsRedirectUriFragment() {
        assertThatIllegalArgumentException().isThrownBy(() -> new ApplicationRegistration(
                new ApplicationKey("daylilt"), "Daylilt", Set.of("https://daylilt.example.com/callback#fragment")));
    }
}
