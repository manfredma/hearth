package manfred.hearth.app.identity;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import manfred.hearth.domain.identity.PasswordCredential;

public interface IdentityCredentialPort {

    Optional<PasswordCredential> findByLogin(String login);

    void recordFailure(UUID userId, Instant lockedUntil);

    void resetFailures(UUID userId);
}
