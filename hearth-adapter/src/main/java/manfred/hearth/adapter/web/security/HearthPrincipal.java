package manfred.hearth.adapter.web.security;

import java.util.Objects;
import java.util.UUID;

public record HearthPrincipal(UUID userId, String username, String displayName, String email) {

    public HearthPrincipal {
        Objects.requireNonNull(userId, "userId");
        if (username == null || username.isBlank()) {
            throw new IllegalArgumentException("username must not be blank");
        }
        if (displayName == null || displayName.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }
        if (email != null && email.isBlank()) {
            throw new IllegalArgumentException("email must not be blank when present");
        }
    }
}
