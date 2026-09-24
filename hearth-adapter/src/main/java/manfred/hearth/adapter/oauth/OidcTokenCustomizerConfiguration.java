package manfred.hearth.adapter.oauth;

import manfred.hearth.adapter.web.security.HearthPrincipal;
import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.server.authorization.token.JwtEncodingContext;
import org.springframework.security.oauth2.server.authorization.token.OAuth2TokenCustomizer;

@Configuration(proxyBeanMethods = false)
public class OidcTokenCustomizerConfiguration {

    @Bean
    OAuth2TokenCustomizer<JwtEncodingContext> hearthJwtTokenCustomizer(
            IdentityCredentialPort identityCredentials, IdentityDirectoryPort identityDirectory) {
        return context -> {
            Object principalObject = context.getPrincipal().getPrincipal();
            String username;
            String displayName;
            String email;
            java.util.UUID userId;
            if (principalObject instanceof HearthPrincipal principal) {
                userId = principal.userId();
                username = principal.username();
                displayName = principal.displayName();
                email = principal.email();
            } else if (principalObject instanceof UserDetails userDetails) {
                // Local password users expose only their login in the security
                // principal. Claims must still use the stable Hearth user id,
                // so resolve the credential-to-account relation at issuance.
                var account = identityCredentials.findByLogin(userDetails.getUsername())
                        .flatMap(credential -> identityDirectory.findById(credential.userId()))
                        .orElse(null);
                if (account == null) {
                    return;
                }
                userId = account.id();
                username = userDetails.getUsername();
                displayName = account.displayName();
                email = account.email();
            } else {
                return;
            }
            context.getClaims()
                    .subject(userId.toString())
                    .claim("preferred_username", username)
                    .claim("name", displayName);
            if (email != null && context.getAuthorizedScopes().contains("email")) {
                context.getClaims().claim("email", email).claim("email_verified", true);
            }
        };
    }
}
