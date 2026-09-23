package manfred.hearth.infrastructure.application;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import manfred.hearth.app.application.ApplicationRegistrationRepository;
import manfred.hearth.domain.application.ApplicationKey;
import manfred.hearth.domain.application.ApplicationRegistration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MySqlApplicationRegistrationRepository implements ApplicationRegistrationRepository {

    private final JdbcTemplate jdbcTemplate;

    public MySqlApplicationRegistrationRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = Objects.requireNonNull(jdbcTemplate, "jdbcTemplate");
    }

    @Override
    public Optional<ApplicationRegistration> findByKey(ApplicationKey key) {
        List<ApplicationRow> rows = jdbcTemplate.query("""
                SELECT id, application_key, display_name
                FROM application
                WHERE application_key = ?
                """, (resultSet, rowNumber) -> new ApplicationRow(
                UUID.fromString(resultSet.getString("id")),
                new ApplicationKey(resultSet.getString("application_key")),
                resultSet.getString("display_name")), key.value());
        return rows.stream().findFirst().map(this::toRegistration);
    }

    @Override
    public List<ApplicationRegistration> listAll() {
        return jdbcTemplate.query("""
                SELECT id, application_key, display_name
                FROM application
                ORDER BY application_key
                """, (resultSet, rowNumber) -> new ApplicationRow(
                UUID.fromString(resultSet.getString("id")),
                new ApplicationKey(resultSet.getString("application_key")),
                resultSet.getString("display_name"))).stream().map(this::toRegistration).toList();
    }

    private ApplicationRegistration toRegistration(ApplicationRow row) {
        List<String> redirectUris = jdbcTemplate.queryForList("""
                SELECT redirect_uri
                FROM application_redirect_uri
                WHERE application_id = ?
                ORDER BY redirect_uri
                """, String.class, row.id());
        return new ApplicationRegistration(row.key(), row.displayName(), new LinkedHashSet<>(redirectUris));
    }

    private record ApplicationRow(UUID id, ApplicationKey key, String displayName) {
    }
}
