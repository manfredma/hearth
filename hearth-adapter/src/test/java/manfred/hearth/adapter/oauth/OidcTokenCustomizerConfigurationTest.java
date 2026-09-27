package manfred.hearth.adapter.oauth;

import java.util.Map;
import java.util.Set;
import java.util.UUID;
import manfred.hearth.adapter.web.security.HearthPrincipal;
import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.server.authorization.token.JwtEncodingContext;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class OidcTokenCustomizerConfigurationTest {
    @Test
    void emitsOnlyClaimsAuthorizedByEachScopeAndNeverInventsEmailVerification() {
        assertThat(claims(Set.of("openid"))).containsOnlyKeys("sub");
        assertThat(claims(Set.of("profile"))).containsOnlyKeys("sub", "name", "preferred_username");
        assertThat(claims(Set.of("email"))).containsOnlyKeys("sub", "email");
    }

    private Map<String, Object> claims(Set<String> scopes) {
        var principal = new HearthPrincipal(UUID.fromString("00000000-0000-0000-0000-000000000001"),
                "admin", "Administrator", "admin@example.test");
        var claims = JwtClaimsSet.builder();
        var context = JwtEncodingContext.with(JwsHeader.with(SignatureAlgorithm.RS256), claims)
                .principal(UsernamePasswordAuthenticationToken.authenticated(principal, null, Set.of()))
                .authorizedScopes(scopes).build();
        new OidcTokenCustomizerConfiguration().hearthJwtTokenCustomizer(
                mock(IdentityCredentialPort.class), mock(IdentityDirectoryPort.class)).customize(context);
        return claims.build().getClaims();
    }
}
