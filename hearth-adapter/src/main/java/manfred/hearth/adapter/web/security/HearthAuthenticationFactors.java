package manfred.hearth.adapter.web.security;

import java.time.Clock;
import java.util.List;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.FactorGrantedAuthority;

/** Creates the authentication factors required by Spring Security's OIDC token generator. */
public final class HearthAuthenticationFactors {

    private HearthAuthenticationFactors() {
    }

    /**
     * Marks a local password or Remember-Me authentication with its issuance
     * instant. Spring Security uses this timestamp for the OIDC {@code auth_time}
     * claim when it creates an ID token.
     */
    public static List<GrantedAuthority> password(Clock clock) {
        return List.of(FactorGrantedAuthority.withAuthority(FactorGrantedAuthority.PASSWORD_AUTHORITY)
                .issuedAt(clock.instant())
                .build());
    }
}
