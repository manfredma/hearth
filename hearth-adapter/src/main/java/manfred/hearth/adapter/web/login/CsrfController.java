package manfred.hearth.adapter.web.login;

import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CsrfController {

    @GetMapping("/api/csrf")
    public CsrfResponse token(CsrfToken token) {
        return new CsrfResponse(token.getToken());
    }

    public record CsrfResponse(String token) {
    }
}
