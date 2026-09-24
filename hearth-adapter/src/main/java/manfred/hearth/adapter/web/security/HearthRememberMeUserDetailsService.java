package manfred.hearth.adapter.web.security;

import java.time.Clock;

import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.domain.identity.PasswordCredential;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

/**
 * Loads the local password hash required to verify a signed Remember-Me cookie.
 *
 * <p>The returned object is deliberately Spring Security's {@link User}, not
 * a Hearth-specific principal. Remember-Me authentication can become the
 * current principal on any request and may later be persisted by the OAuth
 * authorization service, so it must obey the same serialization contract as
 * interactive login.</p>
 */
@Service
public class HearthRememberMeUserDetailsService implements UserDetailsService {

    private final IdentityCredentialPort credentials;
    private final IdentityDirectoryPort identityDirectory;
    private final Clock clock;

    public HearthRememberMeUserDetailsService(IdentityCredentialPort credentials,
                                              IdentityDirectoryPort identityDirectory,
                                              Clock clock) {
        this.credentials = credentials;
        this.identityDirectory = identityDirectory;
        this.clock = clock;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        PasswordCredential credential = credentials.findByLogin(username)
                .filter(value -> value.canAuthenticate(clock.instant()))
                .orElseThrow(() -> new UsernameNotFoundException("Hearth account not found or unavailable"));
        identityDirectory.findById(credential.userId())
                .orElseThrow(() -> new UsernameNotFoundException("Hearth account not found"));
        return User.withUsername(credential.login())
                .password(credential.passwordHash())
                .authorities(java.util.List.of())
                .build();
    }
}
