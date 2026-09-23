package manfred.hearth.app.identity;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import manfred.hearth.domain.identity.PasswordCredential;
import org.springframework.security.crypto.password.PasswordEncoder;

public final class PasswordLoginService {

    private final IdentityCredentialPort credentials;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;
    private final int failureThreshold;
    private final Duration lockDuration;

    public PasswordLoginService(IdentityCredentialPort credentials, PasswordEncoder passwordEncoder, Clock clock,
                                int failureThreshold, Duration lockDuration) {
        this.credentials = Objects.requireNonNull(credentials, "credentials");
        this.passwordEncoder = Objects.requireNonNull(passwordEncoder, "passwordEncoder");
        this.clock = Objects.requireNonNull(clock, "clock");
        if (failureThreshold < 1) {
            throw new IllegalArgumentException("failureThreshold must be positive");
        }
        this.failureThreshold = failureThreshold;
        this.lockDuration = Objects.requireNonNull(lockDuration, "lockDuration");
        if (lockDuration.isNegative() || lockDuration.isZero()) {
            throw new IllegalArgumentException("lockDuration must be positive");
        }
    }

    public AuthenticatedIdentity authenticate(String login, CharSequence rawPassword) {
        if (login == null || login.isBlank() || rawPassword == null || rawPassword.isEmpty()) {
            throw new InvalidCredentialsException();
        }
        Instant now = clock.instant();
        PasswordCredential credential = credentials.findByLogin(login.trim())
                .orElseThrow(InvalidCredentialsException::new);
        if (!credential.canAuthenticate(now)) {
            throw new InvalidCredentialsException();
        }
        if (!passwordEncoder.matches(rawPassword, credential.passwordHash())) {
            int nextFailures = credential.failedAttempts() + 1;
            Instant lockedUntil = nextFailures >= failureThreshold ? now.plus(lockDuration) : null;
            credentials.recordFailure(credential.userId(), lockedUntil);
            throw new InvalidCredentialsException();
        }
        credentials.resetFailures(credential.userId());
        return new AuthenticatedIdentity(credential.userId(), credential.login());
    }

    public record AuthenticatedIdentity(UUID userId, String login) {

        public AuthenticatedIdentity {
            Objects.requireNonNull(userId, "userId");
            if (login == null || login.isBlank()) {
                throw new IllegalArgumentException("login must not be blank");
            }
        }
    }

    public static final class InvalidCredentialsException extends RuntimeException {

        public InvalidCredentialsException() {
            super("login failed");
        }
    }
}
