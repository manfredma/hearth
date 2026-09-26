package manfred.hearth.adapter.oauth;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.server.authorization.settings.AuthorizationServerSettings;

/**
 * Adapter boundary for the self-hosted OAuth 2.0/OIDC provider.
 *
 * <p>Spring Security owns protocol parsing, token validation and endpoint
 * behavior. Hearth only supplies stable deployment settings and later the
 * application ports for users, clients and authorization persistence.</p>
 */
@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(HearthAuthorizationServerProperties.class)
public class OidcProviderConfiguration {

    @Bean
    AuthorizationServerSettings authorizationServerSettings(
            HearthAuthorizationServerProperties properties,
            @Value("${hearth.environment:local}") String environment) {
        properties.validate(environment);
        return AuthorizationServerSettings.builder()
                .issuer(properties.issuer())
                .authorizationEndpoint("/oauth2/authorize")
                .tokenEndpoint("/oauth2/token")
                .jwkSetEndpoint("/oauth2/jwks")
                .tokenRevocationEndpoint("/oauth2/revoke")
                .tokenIntrospectionEndpoint("/oauth2/introspect")
                .oidcUserInfoEndpoint("/userinfo")
                .oidcLogoutEndpoint("/connect/logout")
                .build();
    }
}
