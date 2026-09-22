package manfred.hearth.app.identity;

import java.util.UUID;

public record CurrentIdentity(UUID userId, String displayName) {
}
