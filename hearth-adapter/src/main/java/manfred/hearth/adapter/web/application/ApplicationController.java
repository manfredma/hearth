package manfred.hearth.adapter.web.application;

import java.util.List;

import manfred.hearth.app.application.ApplicationRegistrationRepository;
import manfred.hearth.domain.application.ApplicationRegistration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@RestController
@RequestMapping("/api/applications")
public final class ApplicationController {

    private final ApplicationRegistrationRepository registrations;

    public ApplicationController(ApplicationRegistrationRepository registrations) {
        this.registrations = registrations;
    }

    @GetMapping
    public List<ApplicationResponse> list() {
        return registrations.listAll().stream().map(ApplicationResponse::from).toList();
    }

    @GetMapping("/{applicationKey}")
    public ApplicationResponse find(@PathVariable String applicationKey) {
        return registrations.findByKey(new manfred.hearth.domain.application.ApplicationKey(applicationKey))
                .map(ApplicationResponse::from)
                .orElseThrow(() -> new ApplicationNotFoundException(applicationKey));
    }

    public record ApplicationResponse(String applicationKey, String displayName, List<String> redirectUris) {

        private static ApplicationResponse from(ApplicationRegistration registration) {
            return new ApplicationResponse(registration.key().value(), registration.displayName(),
                    registration.redirectUris().stream().sorted().toList());
        }
    }

    @ResponseStatus(HttpStatus.NOT_FOUND)
    public static final class ApplicationNotFoundException extends RuntimeException {

        public ApplicationNotFoundException(String applicationKey) {
            super("application is not registered: " + applicationKey);
        }
    }
}
