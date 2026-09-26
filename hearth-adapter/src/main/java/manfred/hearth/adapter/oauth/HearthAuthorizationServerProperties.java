package manfred.hearth.adapter.oauth;

import java.net.URI;
import java.time.Duration;
import java.util.Objects;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Runtime configuration for Hearth's in-process OIDC provider.
 *
 * <p>This type deliberately lives in the adapter module: protocol and framework
 * configuration must not leak into the domain or application layers.</p>
 */
@ConfigurationProperties(prefix = "hearth.authorization-server")
public record HearthAuthorizationServerProperties(
        String issuer,
        String signingKeyLocation,
        Duration accessTokenTtl,
        Duration refreshTokenTtl
) {

    public HearthAuthorizationServerProperties {
        issuer = Objects.requireNonNull(issuer, "issuer");
        signingKeyLocation = Objects.requireNonNull(signingKeyLocation, "signingKeyLocation");
        accessTokenTtl = Objects.requireNonNull(accessTokenTtl, "accessTokenTtl");
        refreshTokenTtl = Objects.requireNonNull(refreshTokenTtl, "refreshTokenTtl");
    }

    public void validate(String environment) {
        if (issuer.isBlank()) {
            throw new IllegalArgumentException("OIDC issuer must not be blank");
        }
        URI issuerUri;
        try {
            issuerUri = URI.create(issuer);
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException("OIDC issuer must be an absolute URI", exception);
        }
        if (!issuerUri.isAbsolute()) {
            throw new IllegalArgumentException("OIDC issuer must be an absolute URI");
        }
        if (!"test".equalsIgnoreCase(environment) && !"https".equalsIgnoreCase(issuerUri.getScheme())) {
            throw new IllegalArgumentException("OIDC issuer must use HTTPS outside the test profile");
        }
        if (signingKeyLocation.isBlank()) {
            throw new IllegalArgumentException("OIDC signing key source must not be blank");
        }
        if (accessTokenTtl.isNegative() || accessTokenTtl.isZero()) {
            throw new IllegalArgumentException("OIDC access-token TTL must be positive");
        }
        if (refreshTokenTtl.isNegative() || refreshTokenTtl.isZero()) {
            throw new IllegalArgumentException("OIDC refresh-token TTL must be positive");
        }
    }
}
