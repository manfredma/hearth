package manfred.hearth.adapter.web.identity;

import manfred.hearth.app.identity.CurrentIdentity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SessionController {

    @GetMapping("/api/session")
    public SessionResponse current(CurrentIdentity identity) {
        return new SessionResponse(true, identity.userId(), identity.displayName());
    }

    public record SessionResponse(boolean authenticated, java.util.UUID userId, String displayName) {
    }
}
