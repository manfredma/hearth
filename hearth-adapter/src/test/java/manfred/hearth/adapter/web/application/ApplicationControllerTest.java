package manfred.hearth.adapter.web.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import manfred.hearth.app.application.ApplicationRegistrationRepository;
import manfred.hearth.domain.application.ApplicationKey;
import manfred.hearth.domain.application.ApplicationRegistration;
import org.junit.jupiter.api.Test;

class ApplicationControllerTest {

    @Test
    void listsOnlyPublicApplicationMetadata() {
        ApplicationRegistrationRepository repository = mock(ApplicationRegistrationRepository.class);
        ApplicationRegistration registration = new ApplicationRegistration(new ApplicationKey("daylilt"), "Daylilt",
                Set.of("https://daylilt.example.com/login/oauth2/code/hearth"));
        when(repository.listAll()).thenReturn(List.of(registration));

        List<ApplicationController.ApplicationResponse> response = new ApplicationController(repository).list();

        assertThat(response).singleElement().satisfies(item -> {
            assertThat(item.applicationKey()).isEqualTo("daylilt");
            assertThat(item.displayName()).isEqualTo("Daylilt");
            assertThat(item.redirectUris()).containsExactly("https://daylilt.example.com/login/oauth2/code/hearth");
        });
    }

    @Test
    void reportsMissingApplication() {
        ApplicationRegistrationRepository repository = mock(ApplicationRegistrationRepository.class);
        when(repository.findByKey(new ApplicationKey("daylilt"))).thenReturn(Optional.empty());

        assertThatThrownBy(() -> new ApplicationController(repository).find("daylilt"))
                .isInstanceOf(ApplicationController.ApplicationNotFoundException.class);
    }
}
