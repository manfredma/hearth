package manfred.hearth.adapter.web.security;

import java.time.Clock;

import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.domain.identity.PasswordCredential;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

/** Loads the local password hash required to verify a signed Remember-Me cookie. */
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
        var account = identityDirectory.findById(credential.userId())
                .orElseThrow(() -> new UsernameNotFoundException("Hearth account not found"));
        return new PasswordBackedHearthPrincipal(
                account.id(), credential.login(), account.displayName(), account.email(), credential.passwordHash());
    }

    record PasswordBackedHearthPrincipal(
            java.util.UUID userId,
            String username,
            String displayName,
            String email,
            String password
    ) implements UserDetails {

        @Override
        public java.util.Collection<? extends org.springframework.security.core.GrantedAuthority> getAuthorities() {
            return java.util.List.of();
        }

        @Override
        public String getPassword() {
            return password;
        }

        @Override
        public String getUsername() {
            return username;
        }

        @Override
        public boolean isAccountNonExpired() {
            return true;
        }

        @Override
        public boolean isAccountNonLocked() {
            return true;
        }

        @Override
        public boolean isCredentialsNonExpired() {
            return true;
        }

        @Override
        public boolean isEnabled() {
            return true;
        }

        HearthPrincipal principal() {
            return new HearthPrincipal(userId, username, displayName, email);
        }
    }
}
