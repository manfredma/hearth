package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Optional;
import java.util.UUID;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;
import manfred.hearth.domain.identity.PasswordCredential;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

class HearthRememberMeUserDetailsServiceTest {

    private static final UUID USER_ID = UUID.randomUUID();
    private final FakeCredentials credentials = new FakeCredentials();
    private final HearthRememberMeUserDetailsService service = new HearthRememberMeUserDetailsService(
            credentials, new FakeDirectory(), Clock.fixed(Instant.parse("2026-09-23T04:00:00Z"), ZoneOffset.UTC));

    @Test
    void loadsPrincipalWithPasswordHashForSignedRememberMeToken() {
        credentials.credential = new PasswordCredential(USER_ID, "admin", "password-hash", true, 0, null);

        UserDetails details = service.loadUserByUsername("admin");

        assertThat(details).isInstanceOf(User.class);
        assertThat(details.getUsername()).isEqualTo("admin");
        assertThat(details.getPassword()).isEqualTo("password-hash");
        assertThat(details.getAuthorities()).isEmpty();
    }

    @Test
    void rejectsUnknownOrDisabledCredential() {
        assertThatThrownBy(() -> service.loadUserByUsername("missing"))
                .isInstanceOf(UsernameNotFoundException.class);

        credentials.credential = new PasswordCredential(USER_ID, "admin", "password-hash", false, 0, null);
        assertThatThrownBy(() -> service.loadUserByUsername("admin"))
                .isInstanceOf(UsernameNotFoundException.class);
    }

    private static final class FakeCredentials implements IdentityCredentialPort {
        private PasswordCredential credential;

        @Override
        public Optional<PasswordCredential> findByLogin(String login) {
            return credential != null && credential.login().equals(login) ? Optional.of(credential) : Optional.empty();
        }

        @Override
        public void recordFailure(UUID userId, java.time.Instant lockedUntil) {
        }

        @Override
        public void resetFailures(UUID userId) {
        }
    }

    private static final class FakeDirectory implements IdentityDirectoryPort {
        @Override
        public IdentityAccount findOrCreate(IdentitySubject subject, manfred.hearth.app.identity.IdentityProfile profile) {
            return new IdentityAccount(USER_ID, subject, profile.displayName(), profile.email());
        }

        @Override
        public Optional<IdentityAccount> findById(UUID id) {
            return id.equals(USER_ID)
                    ? Optional.of(new IdentityAccount(USER_ID,
                    new IdentitySubject("https://hearth.example.com", "admin"), "管理员", "admin@example.com"))
                    : Optional.empty();
        }
    }
}
