package manfred.hearth.adapter.web.application;

import java.sql.ResultSet;
import java.time.*;
import java.util.*;
import manfred.hearth.adapter.oauth.HearthAuthorizationServerProperties;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.*;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.oauth2.server.authorization.client.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class OAuthClientBoundaryTest {
    private final RegisteredClientRepository clients = repository();
    private RegisteredClientRepository repository() {
        return new InMemoryRegisteredClientRepository(RegisteredClient.withId("seed").clientId("seed")
                .authorizationGrantType(org.springframework.security.oauth2.core.AuthorizationGrantType.CLIENT_CREDENTIALS)
                .clientAuthenticationMethod(org.springframework.security.oauth2.core.ClientAuthenticationMethod.CLIENT_SECRET_BASIC).build());
    }
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private OAuthClientController controller(RegisteredClientRepository repository) {
        return new OAuthClientController(repository, jdbc, new BCryptPasswordEncoder(4),
                new HearthAuthorizationServerProperties("https://hearth.test", "key", Duration.ofMinutes(5), Duration.ofDays(30)), Clock.systemUTC());
    }
    private OAuthClientController.CreateClientRequest request(Set<String> logout, Set<String> scopes) {
        return new OAuthClientController.CreateClientRequest("career", "Career", Set.of("https://career.test/callback"), logout, scopes);
    }

    @Test
    void requiredFieldsAndScopeAllowlistAreEnforced() {
        var controller = controller(clients);
        var good = request(null, Set.of("openid"));
        for (var invalid : Arrays.asList(null,
                new OAuthClientController.CreateClientRequest(null, good.displayName(), good.redirectUris(), null, good.scopes()),
                new OAuthClientController.CreateClientRequest("career", null, good.redirectUris(), null, good.scopes()),
                new OAuthClientController.CreateClientRequest("career", "Career", null, null, good.scopes()),
                request(null, null), request(null, Set.of()), request(null, Set.of("profile")), request(null, Set.of("openid", "admin")))) {
            assertThatThrownBy(() -> controller.create(invalid)).isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Test
    void legacyLogoutFallbackAndDuplicateResponsesKeepSecretsOutOfErrors() {
        for (Set<String> logout : Arrays.<Set<String>>asList(null, Set.of())) {
            var repository = repository();
            var controller = controller(repository);
            var created = controller.create(request(logout, Set.of("openid"))).getBody();
            assertThat(created.clientName()).isEqualTo("Career");
            assertThat(repository.findByClientId("career").getPostLogoutRedirectUris()).containsExactly("https://career.test/callback");
            assertThatThrownBy(() -> controller.create(request(logout, Set.of("openid"))))
                    .isInstanceOfSatisfying(OAuthClientController.DuplicateClientException.class, error -> {
                        var response = controller.duplicateClient(error);
                        assertThat(response.getStatusCode().value()).isEqualTo(409);
                        assertThat(response.getBody().message()).doesNotContain(created.clientSecret());
                    });
        }
        var racing = mock(RegisteredClientRepository.class);
        doThrow(new DataIntegrityViolationException("unique client")).when(racing).save(any());
        assertThatThrownBy(() -> controller(racing).create(request(null, Set.of("openid"))))
                .isInstanceOf(OAuthClientController.DuplicateClientException.class).hasCauseInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void listsCallbackAndScopeValuesAndRevokesOnlyTheResolvedClient() throws Exception {
        var controller = controller(clients);
        ResultSet row = mock(ResultSet.class);
        when(row.getString("client_id")).thenReturn("career");
        when(row.getString("client_name")).thenReturn("Career");
        when(row.getString("redirect_uris")).thenReturn("https://career.test/callback");
        when(row.getString("scopes")).thenReturn("openid,profile");
        when(jdbc.query(anyString(), org.mockito.ArgumentMatchers.<RowMapper<Object>>any()))
                .thenAnswer(call -> List.of(call.<RowMapper<?>>getArgument(1).mapRow(row, 0)));
        assertThat(controller.list()).singleElement().satisfies(client -> {
            assertThat(client.clientId()).isEqualTo("career");
            assertThat(client.scopes()).containsExactly("openid", "profile");
        });
        when(row.getString("redirect_uris")).thenReturn(null);
        when(row.getString("scopes")).thenReturn(" ");
        assertThat(controller.list().getFirst().redirectUris()).isEmpty();
        assertThat(controller.list().getFirst().scopes()).isEmpty();
        assertThatThrownBy(() -> controller.revoke("missing")).isInstanceOf(OAuthClientController.ClientNotFoundException.class);
        when(row.getString("id")).thenReturn("registered-id");
        when(jdbc.query(anyString(), org.mockito.ArgumentMatchers.<RowMapper<Object>>any(), eq("career")))
                .thenAnswer(call -> List.of(call.<RowMapper<?>>getArgument(1).mapRow(row, 0)));
        controller.revoke("career");
        var order = inOrder(jdbc);
        order.verify(jdbc).update("DELETE FROM oauth2_authorization_consent WHERE registered_client_id = ?", "registered-id");
        order.verify(jdbc).update("DELETE FROM oauth2_authorization WHERE registered_client_id = ?", "registered-id");
        order.verify(jdbc).update("DELETE FROM oauth2_registered_client WHERE id = ?", "registered-id");
    }
}
