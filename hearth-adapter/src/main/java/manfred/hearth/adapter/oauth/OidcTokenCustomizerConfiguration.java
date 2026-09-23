package manfred.hearth.adapter.oauth;

import manfred.hearth.adapter.web.security.HearthPrincipal;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.server.authorization.token.JwtEncodingContext;
import org.springframework.security.oauth2.server.authorization.token.OAuth2TokenCustomizer;

@Configuration(proxyBeanMethods = false)
public class OidcTokenCustomizerConfiguration {

    @Bean
    OAuth2TokenCustomizer<JwtEncodingContext> hearthJwtTokenCustomizer() {
        return context -> {
            if (!(context.getPrincipal().getPrincipal() instanceof HearthPrincipal principal)) {
                return;
            }
            context.getClaims()
                    .subject(principal.userId().toString())
                    .claim("preferred_username", principal.username())
                    .claim("name", principal.displayName());
            if (principal.email() != null && context.getAuthorizedScopes().contains("email")) {
                context.getClaims().claim("email", principal.email()).claim("email_verified", true);
            }
        };
    }
}
