package manfred.hearth.adapter.web.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Set;

import manfred.hearth.adapter.oauth.HearthAuthorizationServerProperties;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.ClientAuthenticationMethod;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClient;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClientRepository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class OAuthClientControllerTest {

    private final RegisteredClientRepository registeredClients = mock(RegisteredClientRepository.class);
    private final JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
    private final PasswordEncoder passwordEncoder = mock(PasswordEncoder.class);
    private final OAuthClientController controller = new OAuthClientController(
            registeredClients,
            jdbcTemplate,
            passwordEncoder,
            new HearthAuthorizationServerProperties(
                    "https://hearth.example.com", "env:HEARTH_SIGNING_KEY", Duration.ofMinutes(5), Duration.ofDays(30)),
            Clock.fixed(Instant.parse("2026-09-23T04:00:00Z"), ZoneOffset.UTC));

    @Test
    void createsConfidentialPkceClientAndReturnsSecretOnce() {
        when(registeredClients.findByClientId("daylilt")).thenReturn(null);
        when(passwordEncoder.encode(any(String.class))).thenReturn("encoded-secret");

        OAuthClientController.ClientCreatedResponse response = controller.create(
                new OAuthClientController.CreateClientRequest(
                        "daylilt", "Daylilt", Set.of("https://daylilt.example.com/login/oauth2/code/hearth"),
                        Set.of("openid", "profile", "email"))).getBody();

        assertThat(response.clientId()).isEqualTo("daylilt");
        assertThat(response.clientSecret()).isNotBlank();
        ArgumentCaptor<RegisteredClient> captor = ArgumentCaptor.forClass(RegisteredClient.class);
        verify(registeredClients).save(captor.capture());
        RegisteredClient client = captor.getValue();
        assertThat(client.getClientSecret()).isEqualTo("encoded-secret");
        assertThat(client.getClientSettings().isRequireProofKey()).isTrue();
        assertThat(client.getAuthorizationGrantTypes()).extracting(grantType -> grantType.getValue())
                .contains("authorization_code", "refresh_token");
    }

    @Test
    void rejectsDuplicateClientAndUnsafeRedirectUri() {
        when(registeredClients.findByClientId("daylilt")).thenReturn(RegisteredClient.withId("existing")
                .clientId("daylilt").clientName("Daylilt")
                .clientAuthenticationMethod(ClientAuthenticationMethod.NONE)
                .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
                .redirectUri("https://daylilt.example.com/callback")
                .scope("openid")
                .build());

        assertThatThrownBy(() -> controller.create(new OAuthClientController.CreateClientRequest(
                "daylilt", "Daylilt", Set.of("https://daylilt.example.com/callback"), Set.of("openid"))))
                .isInstanceOf(OAuthClientController.DuplicateClientException.class);
        verify(registeredClients, never()).save(any(RegisteredClient.class));

        when(registeredClients.findByClientId("unsafe")).thenReturn(null);
        assertThatThrownBy(() -> controller.create(new OAuthClientController.CreateClientRequest(
                "unsafe", "Unsafe", Set.of("http://unsafe.example.com/callback"), Set.of("openid"))))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("HTTPS");
    }
}
