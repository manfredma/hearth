package manfred.hearth.infrastructure.identity;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.domain.identity.PasswordCredential;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MySqlIdentityCredentialRepository implements IdentityCredentialPort {

    private static final String FIND_BY_LOGIN_SQL = """
            SELECT user_id, login, password_hash, enabled, failed_attempts, locked_until
            FROM identity_credential
            WHERE login = ?
            """;

    private final JdbcTemplate jdbcTemplate;

    public MySqlIdentityCredentialRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = Objects.requireNonNull(jdbcTemplate, "jdbcTemplate");
    }

    @Override
    public Optional<PasswordCredential> findByLogin(String login) {
        return jdbcTemplate.query(FIND_BY_LOGIN_SQL, this::mapCredential, login).stream().findFirst();
    }

    @Override
    public void recordFailure(UUID userId, Instant lockedUntil) {
        jdbcTemplate.update("""
                UPDATE identity_credential
                SET failed_attempts = failed_attempts + 1,
                    locked_until = ?,
                    updated_at = UTC_TIMESTAMP(6)
                WHERE user_id = ?
                """, lockedUntil, userId.toString());
    }

    @Override
    public void resetFailures(UUID userId) {
        jdbcTemplate.update("""
                UPDATE identity_credential
                SET failed_attempts = 0,
                    locked_until = NULL,
                    updated_at = UTC_TIMESTAMP(6)
                WHERE user_id = ?
                """, userId.toString());
    }

    private PasswordCredential mapCredential(ResultSet resultSet, int rowNumber) throws SQLException {
        if (rowNumber != 0) {
            throw new SQLException("credential lookup returned an unexpected row index: " + rowNumber);
        }
        return new PasswordCredential(
                UUID.fromString(resultSet.getString("user_id")),
                resultSet.getString("login"),
                resultSet.getString("password_hash"),
                resultSet.getBoolean("enabled"),
                resultSet.getInt("failed_attempts"),
                resultSet.getTimestamp("locked_until") == null
                        ? null
                        : resultSet.getTimestamp("locked_until").toInstant());
    }
}
