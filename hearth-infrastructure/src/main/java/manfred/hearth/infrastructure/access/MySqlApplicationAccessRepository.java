package manfred.hearth.infrastructure.access;

import java.util.Objects;
import java.util.UUID;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import manfred.hearth.app.access.ApplicationAccessPort;
import manfred.hearth.domain.access.ApplicationAccess;
import manfred.hearth.domain.application.ApplicationKey;

@Repository
public final class MySqlApplicationAccessRepository implements ApplicationAccessPort {

    private final JdbcTemplate jdbcTemplate;

    public MySqlApplicationAccessRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = Objects.requireNonNull(jdbcTemplate, "jdbcTemplate");
    }

    @Override
    public ApplicationAccess grant(UUID userId, ApplicationKey application, String roleKey) {
        ApplicationAccess access = new ApplicationAccess(userId, application, roleKey);
        String applicationId = jdbcTemplate.queryForObject(
                "SELECT id FROM application WHERE application_key = ?", String.class, application.value());
        if (applicationId == null) {
            throw new IllegalArgumentException("application is not registered: " + application.value());
        }
        jdbcTemplate.update("""
                INSERT INTO application_access (user_id, application_id, role_key, created_at)
                VALUES (?, ?, ?, UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE role_key = VALUES(role_key)
                """, userId.toString(), applicationId, roleKey);
        return access;
    }

    @Override
    public boolean hasAccess(UUID userId, ApplicationKey application) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM application_access aa
                JOIN application a ON a.id = aa.application_id
                WHERE aa.user_id = ? AND a.application_key = ?
                """, Integer.class, userId.toString(), application.value());
        return count != null && count > 0;
    }
}
