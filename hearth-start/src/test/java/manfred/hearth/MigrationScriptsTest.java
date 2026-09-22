package manfred.hearth;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

import org.junit.jupiter.api.Test;

class MigrationScriptsTest {

    @Test
    void initialMigrationCreatesOnlyHearthIdentityTables() throws IOException {
        try (InputStream input = getClass().getResourceAsStream("/db/migration/V1__create_hearth_identity_tables.sql")) {
            assertThat(input).as("initial Hearth migration").isNotNull();
            String sql = new String(input.readAllBytes(), StandardCharsets.UTF_8);
            assertThat(sql).contains("CREATE TABLE user_identity");
            assertThat(sql).contains("CREATE TABLE application");
            assertThat(sql).contains("CREATE TABLE application_access");
            assertThat(sql).contains("CREATE TABLE audit_event");
            assertThat(sql).doesNotContain("password_hash");
        }
    }
}
