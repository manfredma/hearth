package manfred.hearth.app.identity;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

import manfred.hearth.domain.identity.PasswordCredential;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PasswordLoginServiceTest {

    private static final UUID USER_ID = UUID.randomUUID();
    private static final Instant NOW = Instant.parse("2026-09-23T04:00:00Z");

    private final PasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final FakeCredentialPort credentials = new FakeCredentialPort();
    private final PasswordLoginService service = new PasswordLoginService(
            credentials, encoder, Clock.fixed(NOW, ZoneOffset.UTC), 3, Duration.ofMinutes(15));

    @Test
    void rejectsMissingLoginOrPasswordWithGenericError() {
        assertThatThrownBy(() -> service.authenticate(" ", "secret"))
                .isInstanceOf(PasswordLoginService.InvalidCredentialsException.class)
                .hasMessage("login failed");
        assertThatThrownBy(() -> service.authenticate("admin", ""))
                .isInstanceOf(PasswordLoginService.InvalidCredentialsException.class)
                .hasMessage("login failed");
    }

    @Test
    void rejectsUnknownDisabledAndLockedCredentials() {
        assertThatThrownBy(() -> service.authenticate("unknown", "secret"))
                .isInstanceOf(PasswordLoginService.InvalidCredentialsException.class);

        credentials.credential = credential(false, 0, null);
        assertThatThrownBy(() -> service.authenticate("admin", "secret"))
                .isInstanceOf(PasswordLoginService.InvalidCredentialsException.class);

        credentials.credential = credential(true, 3, NOW.plusSeconds(60));
        assertThatThrownBy(() -> service.authenticate("admin", "secret"))
                .isInstanceOf(PasswordLoginService.InvalidCredentialsException.class);
    }

    @Test
    void rejectsWrongPasswordAndLocksAfterThreshold() {
        credentials.credential = credential(true, 2, null);

        assertThatThrownBy(() -> service.authenticate("admin", "wrong"))
                .isInstanceOf(PasswordLoginService.InvalidCredentialsException.class);

        assertThat(credentials.failureUserId).isEqualTo(USER_ID);
        assertThat(credentials.lockedUntil).isEqualTo(NOW.plus(Duration.ofMinutes(15)));
    }

    @Test
    void authenticatesAndResetsFailuresForCorrectPassword() {
        credentials.credential = credential(true, 2, null);

        PasswordLoginService.AuthenticatedIdentity identity = service.authenticate(" admin ", "secret");

        assertThat(identity.userId()).isEqualTo(USER_ID);
        assertThat(identity.login()).isEqualTo("admin");
        assertThat(credentials.resetUserId).isEqualTo(USER_ID);
    }

    private PasswordCredential credential(boolean enabled, int failedAttempts, Instant lockedUntil) {
        return new PasswordCredential(USER_ID, "admin", encoder.encode("secret"), enabled, failedAttempts, lockedUntil);
    }

    private static final class FakeCredentialPort implements IdentityCredentialPort {

        private PasswordCredential credential;
        private UUID failureUserId;
        private Instant lockedUntil;
        private UUID resetUserId;

        @Override
        public Optional<PasswordCredential> findByLogin(String login) {
            return credential == null || !credential.login().equals(login) ? Optional.empty() : Optional.of(credential);
        }

        @Override
        public void recordFailure(UUID userId, Instant lockedUntil) {
            this.failureUserId = userId;
            this.lockedUntil = lockedUntil;
        }

        @Override
        public void resetFailures(UUID userId) {
            this.resetUserId = userId;
        }
    }
}
