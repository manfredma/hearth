package manfred.hearth.adapter.web.login;

import java.net.URI;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClient;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClientRepository;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ConsentClientMetadataController {
    private final RegisteredClientRepository registeredClients;

    public ConsentClientMetadataController(RegisteredClientRepository registeredClients) {
        this.registeredClients = registeredClients;
    }

    @GetMapping("/api/consent-client")
    public ResponseEntity<ClientMetadata> metadata(@RequestParam(name = "client_id", required = false) String clientId) {
        if (!StringUtils.hasText(clientId)) {
            return ResponseEntity.notFound().build();
        }
        RegisteredClient client = registeredClients.findByClientId(clientId);
        if (client == null || !StringUtils.hasText(client.getClientName())
                || client.getClientName().equals(client.getId())
                || client.getRedirectUris().isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        List<String> origins;
        try {
            origins = client.getRedirectUris().stream().map(ConsentClientMetadataController::origin)
                    .distinct().sorted().toList();
        } catch (IllegalArgumentException exception) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(new ClientMetadata(client.getClientName(), origins));
    }

    private static String origin(String redirectUri) {
        URI uri = URI.create(redirectUri);
        if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null || uri.getUserInfo() != null) {
            throw new IllegalArgumentException("Unsafe registered callback URI");
        }
        return "https://" + uri.getHost() + (uri.getPort() == -1 ? "" : ":" + uri.getPort());
    }

    public record ClientMetadata(String clientName, List<String> callbackOrigins) {
    }
}
