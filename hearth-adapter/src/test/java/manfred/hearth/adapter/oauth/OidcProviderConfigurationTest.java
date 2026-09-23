package manfred.hearth.adapter.oauth;

import org.junit.jupiter.api.Test;

import java.time.Duration;

import org.springframework.security.oauth2.server.authorization.settings.AuthorizationServerSettings;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OidcProviderConfigurationTest {

    @Test
    void rejectsNonHttpsIssuerOutsideTestProfile() {
        HearthAuthorizationServerProperties properties = properties("http://localhost:8080", "env:HEARTH_SIGNING_KEY");

        assertThatThrownBy(() -> properties.validate("staging"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("HTTPS");
    }

    @Test
    void rejectsMissingSigningKeySource() {
        HearthAuthorizationServerProperties properties = properties("https://hearth.example.com", " ");

        assertThatThrownBy(() -> properties.validate("production"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("signing key");
    }

    @Test
    void exposesExplicitShortLivedAccessTokenConfiguration() {
        HearthAuthorizationServerProperties properties = properties("https://hearth.example.com", "env:HEARTH_SIGNING_KEY");

        properties.validate("production");

        assertThat(properties.accessTokenTtl()).isEqualTo(Duration.ofMinutes(5));
        assertThat(properties.refreshTokenTtl()).isEqualTo(Duration.ofDays(30));
        assertThat(properties.issuer()).isEqualTo("https://hearth.example.com");
    }

    @Test
    void publishesTheStandardProviderEndpointLayout() {
        HearthAuthorizationServerProperties properties = properties("https://hearth.example.com", "env:HEARTH_SIGNING_KEY");

        AuthorizationServerSettings settings = new OidcProviderConfiguration()
                .authorizationServerSettings(properties, "production");

        assertThat(settings.getIssuer()).isEqualTo("https://hearth.example.com");
        assertThat(settings.getAuthorizationEndpoint()).isEqualTo("/oauth2/authorize");
        assertThat(settings.getTokenEndpoint()).isEqualTo("/oauth2/token");
        assertThat(settings.getJwkSetEndpoint()).isEqualTo("/oauth2/jwks");
        assertThat(settings.getOidcUserInfoEndpoint()).isEqualTo("/userinfo");
        assertThat(settings.getOidcLogoutEndpoint()).isEqualTo("/connect/logout");
    }

    private HearthAuthorizationServerProperties properties(String issuer, String signingKeyLocation) {
        return new HearthAuthorizationServerProperties(
                issuer,
                signingKeyLocation,
                Duration.ofMinutes(5),
                Duration.ofDays(30)
        );
    }
}
