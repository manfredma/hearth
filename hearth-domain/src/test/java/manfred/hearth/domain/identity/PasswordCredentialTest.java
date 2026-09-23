package manfred.hearth.domain.identity;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PasswordCredentialTest {

    private static final UUID USER_ID = UUID.randomUUID();
    private static final Instant NOW = Instant.parse("2026-09-23T04:00:00Z");

    @Test
    void rejectsBlankLoginAndHash() {
        assertThatThrownBy(() -> credential(" ", "hash", true, 0, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("login");
        assertThatThrownBy(() -> credential("admin", " ", true, 0, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("passwordHash");
    }

    @Test
    void rejectsNegativeFailureCount() {
        assertThatThrownBy(() -> credential("admin", "hash", true, -1, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("failedAttempts");
    }

    @Test
    void reportsDisabledAndCurrentlyLockedCredentials() {
        assertThat(credential("admin", "hash", false, 0, null).canAuthenticate(NOW)).isFalse();
        assertThat(credential("admin", "hash", true, 3, NOW.plusSeconds(30)).isLocked(NOW)).isTrue();
        assertThat(credential("admin", "hash", true, 3, NOW).isLocked(NOW)).isFalse();
        assertThat(credential("admin", "hash", true, 3, NOW.plusSeconds(30)).canAuthenticate(NOW)).isFalse();
    }

    @Test
    void allowsEnabledCredentialAfterLockExpires() {
        PasswordCredential credential = credential("admin", "hash", true, 3, NOW.minusSeconds(1));

        assertThat(credential.canAuthenticate(NOW)).isTrue();
    }

    private PasswordCredential credential(String login, String hash, boolean enabled, int failures, Instant lockedUntil) {
        return new PasswordCredential(USER_ID, login, hash, enabled, failures, lockedUntil);
    }
}
