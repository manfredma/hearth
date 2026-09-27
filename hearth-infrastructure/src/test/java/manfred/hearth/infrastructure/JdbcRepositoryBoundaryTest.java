package manfred.hearth.infrastructure;

import java.sql.*;
import java.time.*;
import java.util.*;
import manfred.hearth.infrastructure.access.MySqlApplicationAccessRepository;
import manfred.hearth.infrastructure.application.MySqlApplicationRegistrationRepository;
import manfred.hearth.infrastructure.identity.*;
import manfred.hearth.domain.application.ApplicationKey;
import manfred.hearth.app.identity.IdentityProfile;
import manfred.hearth.domain.identity.IdentitySubject;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class JdbcRepositoryBoundaryTest {
    private final UUID id = UUID.fromString("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    private final ResultSet row = mock(ResultSet.class);
    private int rowNumber;
    private boolean empty;
    private final List<String> statements = new ArrayList<>();
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class, invocation -> {
        if (invocation.getArguments().length > 0 && invocation.getArgument(0) instanceof String sql) statements.add(sql);
        if (invocation.getMethod().getName().equals("query")) {
            RowMapper<?> mapper = invocation.getArgument(1);
            return empty ? List.of() : List.of(mapper.mapRow(row, rowNumber));
        }
        return org.mockito.Answers.RETURNS_DEFAULTS.answer(invocation);
    });

    @Test
    void grantsOnlyRegisteredApplicationsAndHandlesAbsentAccess() {
        var repository = new MySqlApplicationAccessRepository(jdbc);
        var key = new ApplicationKey("career");
        assertThatThrownBy(() -> repository.grant(id, key, "career:reader")).isInstanceOf(IllegalArgumentException.class);
        when(jdbc.queryForObject(anyString(), eq(String.class), eq("career"))).thenReturn("application-id");
        var access = repository.grant(id, key, "career:reader");
        assertThat(access.roleKey()).isEqualTo("career:reader");
        verify(jdbc).update(contains("INSERT INTO application_access"), eq(id.toString()), eq("application-id"), eq("career:reader"));
        when(jdbc.queryForObject(anyString(), eq(Integer.class), eq(id.toString()), eq("career")))
                .thenReturn(null, 0, 1);
        assertThat(repository.hasAccess(id, key)).isFalse();
        assertThat(repository.hasAccess(id, key)).isFalse();
        assertThat(repository.hasAccess(id, key)).isTrue();
    }

    @Test
    void mapsApplicationAndRedirectsAndReturnsEmptyForMissingApplication() throws Exception {
        when(row.getString("id")).thenReturn(id.toString());
        when(row.getString("application_key")).thenReturn("career");
        when(row.getString("display_name")).thenReturn("Career");
        when(jdbc.queryForList(anyString(), eq(String.class), eq(id))).thenReturn(List.of("https://career.test/callback"));
        var repository = new MySqlApplicationRegistrationRepository(jdbc);
        assertThat(repository.findByKey(new ApplicationKey("career")).orElseThrow().redirectUris())
                .containsExactly("https://career.test/callback");
        assertThat(repository.listAll()).singleElement().satisfies(app -> assertThat(app.displayName()).isEqualTo("Career"));
        empty = true;
        assertThat(repository.findByKey(new ApplicationKey("missing"))).isEmpty();
    }

    @Test
    void mapsCredentialLockStateAndWritesFailureAndReset() throws Exception {
        when(row.getString("user_id")).thenReturn(id.toString());
        when(row.getString("login")).thenReturn("admin");
        when(row.getString("password_hash")).thenReturn("hash");
        when(row.getBoolean("enabled")).thenReturn(true);
        when(row.getInt("failed_attempts")).thenReturn(2);
        var repository = new MySqlIdentityCredentialRepository(jdbc);
        assertThat(repository.findByLogin("admin").orElseThrow().lockedUntil()).isNull();
        Instant lock = Instant.parse("2026-09-01T00:00:00Z");
        when(row.getTimestamp("locked_until")).thenReturn(Timestamp.from(lock));
        assertThat(repository.findByLogin("admin").orElseThrow().lockedUntil()).isEqualTo(lock);
        repository.recordFailure(id, lock);
        repository.resetFailures(id);
        verify(jdbc).update(contains("failed_attempts = failed_attempts + 1"), eq(lock), eq(id.toString()));
        verify(jdbc).update(contains("failed_attempts = 0"), eq(id.toString()));
        rowNumber = 1;
        assertThatThrownBy(() -> repository.findByLogin("admin")).hasMessageContaining("unexpected row index");
        empty = true;
        assertThat(repository.findByLogin("missing")).isEmpty();
    }

    @Test
    void identityQueriesSupplyEveryMappedColumnAndRejectDuplicateRows() throws Exception {
        when(row.getString("id")).thenReturn(id.toString());
        when(row.getString("issuer")).thenReturn("https://hearth.test");
        when(row.getString("subject")).thenReturn("subject");
        when(row.getString("display_name")).thenReturn("Admin");
        var repository = new MySqlIdentityDirectory(jdbc, Clock.systemUTC());
        assertThat(repository.findById(id).orElseThrow().id()).isEqualTo(id);
        rowNumber = 1;
        assertThatThrownBy(() -> repository.findById(id)).hasMessageContaining("unexpected row index");
        rowNumber = 0;
        when(jdbc.queryForObject(anyString(), org.mockito.ArgumentMatchers.<RowMapper<Object>>any(), any(), any()))
                .thenAnswer(call -> {
                    String sql = call.getArgument(0);
                    assertThat(sql.substring(0, sql.indexOf("FROM"))).contains("issuer", "subject");
                    return call.<RowMapper<?>>getArgument(1).mapRow(row, 0);
                });
        assertThat(repository.findOrCreate(new IdentitySubject("https://hearth.test", "subject"), new IdentityProfile("Admin", null)).id())
                .isEqualTo(id);
    }

    @Test
    void infrastructureClockUsesUtc() {
        assertThat(new InfrastructureConfiguration().systemClock().getZone()).isEqualTo(ZoneOffset.UTC);
    }
}
