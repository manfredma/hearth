package manfred.hearth.domain.identity;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record PasswordCredential(
        UUID userId,
        String login,
        String passwordHash,
        boolean enabled,
        int failedAttempts,
        Instant lockedUntil
) {

    public PasswordCredential {
        Objects.requireNonNull(userId, "userId");
        login = requireText(login, "login");
        passwordHash = requireText(passwordHash, "passwordHash");
        if (failedAttempts < 0) {
            throw new IllegalArgumentException("failedAttempts must not be negative");
        }
    }

    public boolean isLocked(Instant now) {
        Objects.requireNonNull(now, "now");
        return lockedUntil != null && lockedUntil.isAfter(now);
    }

    public boolean canAuthenticate(Instant now) {
        return enabled && !isLocked(now);
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        if (value.isBlank()) {
            throw new IllegalArgumentException(field + " must not be blank");
        }
        return value;
    }
}
