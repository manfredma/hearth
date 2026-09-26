package manfred.hearth.infrastructure.identity;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.app.identity.IdentityProfile;
import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;

@Repository
public class MySqlIdentityDirectory implements IdentityDirectoryPort {

    private static final String UPSERT_SQL = """
            INSERT INTO user_identity (id, issuer, subject, display_name, email, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), email = VALUES(email), updated_at = VALUES(updated_at)
            """;
    private static final String FIND_SQL = """
            SELECT id, display_name, email
            FROM user_identity
            WHERE issuer = ? AND subject = ?
            """;
    private static final String FIND_BY_ID_SQL = """
            SELECT id, issuer, subject, display_name, email
            FROM user_identity
            WHERE id = ?
            """;

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    public MySqlIdentityDirectory(JdbcTemplate jdbcTemplate, Clock clock) {
        this.jdbcTemplate = Objects.requireNonNull(jdbcTemplate, "jdbcTemplate");
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    @Override
    public IdentityAccount findOrCreate(IdentitySubject subject, IdentityProfile profile) {
        Objects.requireNonNull(subject, "subject");
        Objects.requireNonNull(profile, "profile");
        UUID id = UUID.randomUUID();
        Instant now = clock.instant();
        jdbcTemplate.update(UPSERT_SQL, id.toString(), subject.issuer(), subject.subject(), profile.displayName(),
                profile.email(), now, now);
        return jdbcTemplate.queryForObject(FIND_SQL, this::mapAccount, subject.issuer(), subject.subject());
    }

    @Override
    public Optional<IdentityAccount> findById(UUID id) {
        Objects.requireNonNull(id, "id");
        return jdbcTemplate.query(FIND_BY_ID_SQL, this::mapAccount, id.toString()).stream().findFirst();
    }

    private IdentityAccount mapAccount(ResultSet resultSet, int rowNumber) throws SQLException {
        if (rowNumber != 0) {
            throw new SQLException("identity lookup returned an unexpected row index: " + rowNumber);
        }
        return new IdentityAccount(
                UUID.fromString(resultSet.getString("id")),
                new IdentitySubject(resultSet.getString("issuer"), resultSet.getString("subject")),
                resultSet.getString("display_name"),
                resultSet.getString("email"));
    }
}
