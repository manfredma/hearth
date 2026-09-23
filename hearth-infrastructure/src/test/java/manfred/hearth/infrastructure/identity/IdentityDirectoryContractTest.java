package manfred.hearth.infrastructure.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.sql.ResultSet;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

import manfred.hearth.app.identity.IdentityProfile;
import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;

class IdentityDirectoryContractTest {

    @Test
    void upsertsAndReadsIdentityByIssuerAndSubject() throws Exception {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        UUID id = UUID.randomUUID();
        ResultSet resultSet = mock(ResultSet.class);
        when(resultSet.getString("id")).thenReturn(id.toString());
        when(resultSet.getString("issuer")).thenReturn("https://auth.example");
        when(resultSet.getString("subject")).thenReturn("subject-1");
        when(resultSet.getString("display_name")).thenReturn("Feng");
        when(resultSet.getString("email")).thenReturn("feng@example.com");
        when(jdbcTemplate.queryForObject(any(String.class),
                org.mockito.ArgumentMatchers.<org.springframework.jdbc.core.RowMapper<IdentityAccount>>any(),
                eq("https://auth.example"), eq("subject-1")))
                .thenAnswer(invocation -> invocation.<org.springframework.jdbc.core.RowMapper<IdentityAccount>>getArgument(1)
                        .mapRow(resultSet, 0));

        MySqlIdentityDirectory directory = new MySqlIdentityDirectory(
                jdbcTemplate, Clock.fixed(Instant.parse("2026-09-23T00:00:00Z"), ZoneOffset.UTC));
        IdentityAccount account = directory.findOrCreate(
                new IdentitySubject("https://auth.example", "subject-1"),
                new IdentityProfile("Feng", "feng@example.com"));

        assertThat(account.id()).isEqualTo(id);
        assertThat(account.subject().subject()).isEqualTo("subject-1");
        verify(jdbcTemplate).update(any(String.class), any(), eq("https://auth.example"), eq("subject-1"),
                eq("Feng"), eq("feng@example.com"), any(), any());
    }
}
