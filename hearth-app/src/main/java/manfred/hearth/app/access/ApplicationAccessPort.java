package manfred.hearth.app.access;

import java.util.UUID;

import manfred.hearth.domain.access.ApplicationAccess;
import manfred.hearth.domain.application.ApplicationKey;

public interface ApplicationAccessPort {

    ApplicationAccess grant(UUID userId, ApplicationKey application, String roleKey);

    boolean hasAccess(UUID userId, ApplicationKey application);
}
