package manfred.hearth.app.application;

import java.util.List;
import java.util.Optional;

import manfred.hearth.domain.application.ApplicationKey;
import manfred.hearth.domain.application.ApplicationRegistration;

public interface ApplicationRegistrationRepository {

    Optional<ApplicationRegistration> findByKey(ApplicationKey key);

    List<ApplicationRegistration> listAll();
}
