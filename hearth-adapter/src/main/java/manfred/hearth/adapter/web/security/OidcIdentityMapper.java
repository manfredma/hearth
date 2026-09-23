package manfred.hearth.adapter.web.security;

import java.util.Objects;

import manfred.hearth.app.identity.IdentityProfile;
import manfred.hearth.domain.identity.IdentitySubject;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Component;

@Component
public class OidcIdentityMapper {

    public MappedIdentity map(OidcUser user) {
        Objects.requireNonNull(user, "user");
        String issuer = Objects.requireNonNull(user.getIssuer(), "OIDC issuer is required").toString();
        String subject = requiredClaim(user, "sub");
        String displayName = firstNonBlank(user.getClaimAsString("name"),
                user.getClaimAsString("preferred_username"), user.getEmail(), subject);
        return new MappedIdentity(new IdentitySubject(issuer, subject),
                new IdentityProfile(displayName, user.getEmail()));
    }

    private String requiredClaim(OidcUser user, String claim) {
        String value = user.getClaimAsString(claim);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("OIDC claim must not be blank: " + claim);
        }
        return value;
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        throw new IllegalArgumentException("OIDC profile has no display name");
    }

    public record MappedIdentity(IdentitySubject subject, IdentityProfile profile) {
    }
}
