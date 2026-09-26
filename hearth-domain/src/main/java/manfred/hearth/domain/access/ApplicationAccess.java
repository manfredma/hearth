package manfred.hearth.domain.access;

import java.util.Objects;
import java.util.UUID;
import java.util.regex.Pattern;

import manfred.hearth.domain.application.ApplicationKey;

public record ApplicationAccess(UUID userId, ApplicationKey application, String roleKey) {

    private static final Pattern ROLE_KEY = Pattern.compile("[a-z0-9][a-z0-9-]*(?::[a-z0-9][a-z0-9-]*)+");

    public ApplicationAccess {
        Objects.requireNonNull(userId, "userId");
        Objects.requireNonNull(application, "application");
        Objects.requireNonNull(roleKey, "roleKey");
        if (!ROLE_KEY.matcher(roleKey).matches()) {
            throw new IllegalArgumentException("roleKey must be namespaced, for example release:operator");
        }
    }
}
