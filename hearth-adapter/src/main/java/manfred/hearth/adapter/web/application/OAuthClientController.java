package manfred.hearth.adapter.web.application;

import java.security.SecureRandom;
import java.time.Clock;
import java.util.Base64;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import manfred.hearth.adapter.oauth.HearthAuthorizationServerProperties;
import manfred.hearth.domain.application.ApplicationKey;
import manfred.hearth.domain.application.ApplicationRegistration;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.ClientAuthenticationMethod;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClient;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClientRepository;
import org.springframework.security.oauth2.server.authorization.settings.ClientSettings;
import org.springframework.security.oauth2.server.authorization.settings.TokenSettings;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.ResponseStatus;

@RestController
@RequestMapping("/api/admin/oauth-clients")
public final class OAuthClientController {

    private static final Set<String> SUPPORTED_SCOPES = Set.of("openid", "profile", "email");

    private final RegisteredClientRepository registeredClients;
    private final JdbcTemplate jdbcTemplate;
    private final PasswordEncoder passwordEncoder;
    private final HearthAuthorizationServerProperties properties;
    private final Clock clock;
    private final SecureRandom secureRandom = new SecureRandom();

    public OAuthClientController(RegisteredClientRepository registeredClients, JdbcTemplate jdbcTemplate,
                                 PasswordEncoder passwordEncoder, HearthAuthorizationServerProperties properties,
                                 Clock clock) {
        this.registeredClients = registeredClients;
        this.jdbcTemplate = jdbcTemplate;
        this.passwordEncoder = passwordEncoder;
        this.properties = properties;
        this.clock = clock;
    }

    @PostMapping
    public ResponseEntity<ClientCreatedResponse> create(@RequestBody CreateClientRequest request) {
        ApplicationRegistration application = validate(request);
        if (registeredClients.findByClientId(application.key().value()) != null) {
            throw new DuplicateClientException(application.key().value());
        }
        String plainSecret = generateSecret();
        RegisteredClient client = RegisteredClient.withId(UUID.randomUUID().toString())
                .clientId(application.key().value())
                .clientIdIssuedAt(clock.instant())
                .clientSecret(passwordEncoder.encode(plainSecret))
                .clientName(application.displayName())
                .clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
                .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
                .authorizationGrantType(AuthorizationGrantType.REFRESH_TOKEN)
                .redirectUris(uris -> uris.addAll(application.redirectUris()))
                .postLogoutRedirectUris(uris -> uris.addAll(application.redirectUris()))
                .scopes(scopes -> scopes.addAll(request.scopes()))
                .clientSettings(ClientSettings.builder()
                        .requireProofKey(true)
                        .requireAuthorizationConsent(true)
                        .build())
                .tokenSettings(TokenSettings.builder()
                        .authorizationCodeTimeToLive(java.time.Duration.ofMinutes(5))
                        .accessTokenTimeToLive(properties.accessTokenTtl())
                        .refreshTokenTimeToLive(properties.refreshTokenTtl())
                        .reuseRefreshTokens(false)
                        .build())
                .build();
        try {
            registeredClients.save(client);
        } catch (DataIntegrityViolationException exception) {
            throw new DuplicateClientException(application.key().value(), exception);
        }
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ClientCreatedResponse(client.getClientId(), plainSecret, application.displayName()));
    }

    @GetMapping
    public List<ClientSummary> list() {
        return jdbcTemplate.query("""
                SELECT client_id, client_name, redirect_uris, scopes
                FROM oauth2_registered_client
                ORDER BY client_name, client_id
                """, (resultSet, rowNumber) -> new ClientSummary(
                resultSet.getString("client_id"),
                resultSet.getString("client_name"),
                split(resultSet.getString("redirect_uris")),
                split(resultSet.getString("scopes"))));
    }

    @DeleteMapping("/{clientId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@PathVariable String clientId) {
        String registeredClientId = jdbcTemplate.query("""
                SELECT id FROM oauth2_registered_client WHERE client_id = ?
                """, (resultSet, rowNumber) -> resultSet.getString("id"), clientId)
                .stream().findFirst().orElseThrow(() -> new ClientNotFoundException(clientId));
        jdbcTemplate.update("DELETE FROM oauth2_authorization_consent WHERE registered_client_id = ?", registeredClientId);
        jdbcTemplate.update("DELETE FROM oauth2_authorization WHERE registered_client_id = ?", registeredClientId);
        jdbcTemplate.update("DELETE FROM oauth2_registered_client WHERE id = ?", registeredClientId);
    }

    @ExceptionHandler(DuplicateClientException.class)
    ResponseEntity<ClientErrorResponse> duplicateClient(DuplicateClientException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new ClientErrorResponse(exception.getMessage()));
    }

    private ApplicationRegistration validate(CreateClientRequest request) {
        if (request == null || request.applicationKey() == null || request.displayName() == null
                || request.redirectUris() == null || request.scopes() == null) {
            throw new IllegalArgumentException("client registration fields are required");
        }
        if (!SUPPORTED_SCOPES.containsAll(request.scopes()) || request.scopes().isEmpty()
                || !request.scopes().contains("openid")) {
            throw new IllegalArgumentException("only openid, profile and email scopes are supported");
        }
        return new ApplicationRegistration(
                new ApplicationKey(request.applicationKey()), request.displayName(), Set.copyOf(request.redirectUris()));
    }

    private String generateSecret() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private List<String> split(String value) {
        return value == null || value.isBlank() ? List.of() : List.of(value.split(","));
    }

    public record CreateClientRequest(String applicationKey, String displayName,
                                      Set<String> redirectUris, Set<String> scopes) {
    }

    public record ClientCreatedResponse(String clientId, String clientSecret, String clientName) {
    }

    public record ClientSummary(String clientId, String clientName,
                                List<String> redirectUris, List<String> scopes) {
    }

    public record ClientErrorResponse(String message) {
    }

    @ResponseStatus(HttpStatus.NOT_FOUND)
    static final class ClientNotFoundException extends RuntimeException {
        ClientNotFoundException(String clientId) {
            super("OAuth client is not registered: " + clientId);
        }
    }

    static final class DuplicateClientException extends RuntimeException {
        DuplicateClientException(String clientId) {
            super("OAuth client already exists: " + clientId);
        }

        DuplicateClientException(String clientId, Throwable cause) {
            super("OAuth client already exists: " + clientId, cause);
        }
    }
}
