package manfred.hearth.app.identity;

import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;

public interface IdentityDirectoryPort {

    IdentityAccount findOrCreate(IdentitySubject subject, IdentityProfile profile);
}
