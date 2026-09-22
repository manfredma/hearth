package manfred.hearth.domain.identity;

import java.util.Objects;
import java.util.UUID;

public record IdentityAccount(UUID id, IdentitySubject subject, String displayName, String email) {

    public IdentityAccount {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(subject, "subject");
        if (displayName == null || displayName.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }
        if (email != null && email.isBlank()) {
            throw new IllegalArgumentException("email must not be blank when present");
        }
    }
}
