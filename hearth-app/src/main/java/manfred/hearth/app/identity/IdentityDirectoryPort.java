package manfred.hearth.app.identity;

import java.util.Optional;
import java.util.UUID;

import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;

public interface IdentityDirectoryPort {

    IdentityAccount findOrCreate(IdentitySubject subject, IdentityProfile profile);

    Optional<IdentityAccount> findById(UUID id);
}
