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
            assertThat(sql).contains("issuer_identity_hash BINARY(32)");
            assertThat(sql).contains("subject_identity_hash BINARY(32)");
            assertThat(sql).contains("redirect_uri_hash BINARY(32)");
            assertThat(sql).doesNotContain("password_hash");
        }
    }

    @Test
    void legacyOAuthAuthorizationMigrationRemovesOnlyRowsWithTheRejectedPrincipalType() throws IOException {
        try (InputStream input = getClass().getResourceAsStream(
                "/db/migration/V4__remove_legacy_oauth_authorizations.sql")) {
            assertThat(input).as("legacy OAuth authorization migration").isNotNull();
            String sql = new String(input.readAllBytes(), StandardCharsets.UTF_8);
            assertThat(sql).contains("DELETE FROM oauth2_authorization");
            assertThat(sql).contains("CONVERT(attributes USING utf8mb4)");
            assertThat(sql).contains("HearthPrincipal");
            assertThat(sql).doesNotContain("oauth2_authorization_consent");
        }
    }
}
