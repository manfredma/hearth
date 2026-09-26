package manfred.hearth.app.access;

import java.util.UUID;

import manfred.hearth.domain.application.ApplicationKey;

public record GrantApplicationAccessCmd(UUID userId, ApplicationKey application, String roleKey) {
}
