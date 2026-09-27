package manfred.hearth.adapter.oauth;

import java.util.*;
import manfred.hearth.adapter.web.security.HearthPrincipal;
import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.domain.identity.*;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.server.authorization.token.JwtEncodingContext;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class OidcClaimsScopeTest {
    private static final UUID ID = UUID.fromString("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    private final IdentityCredentialPort credentials = mock(IdentityCredentialPort.class);
    private final IdentityDirectoryPort directory = mock(IdentityDirectoryPort.class);

    @Test
    void scopesControlResultingClaimsForCurrentAndLegacyPrincipals() {
        var user = User.withUsername("admin").password("").authorities(List.of()).build();
        when(credentials.findByLogin("admin")).thenReturn(Optional.of(new PasswordCredential(ID, "admin", "hash", true, 0, null)));
        when(directory.findById(ID)).thenReturn(Optional.of(new IdentityAccount(ID,
                new IdentitySubject("https://hearth.test", "subject"), "Admin", "admin@example.test")));
        for (Object principal : List.of(user, new HearthPrincipal(ID, "admin", "Admin", "admin@example.test"))) {
            assertThat(claims(principal, Set.of("openid"))).containsExactlyInAnyOrderEntriesOf(Map.of("sub", ID.toString()));
            assertThat(claims(principal, Set.of("profile"))).containsExactlyInAnyOrderEntriesOf(Map.of(
                    "sub", ID.toString(), "name", "Admin", "preferred_username", "admin"));
            assertThat(claims(principal, Set.of("email"))).containsExactlyInAnyOrderEntriesOf(Map.of(
                    "sub", ID.toString(), "email", "admin@example.test"));
            assertThat(claims(principal, Set.of("profile", "email"))).containsExactlyInAnyOrderEntriesOf(Map.of(
                    "sub", ID.toString(), "name", "Admin", "preferred_username", "admin", "email", "admin@example.test"));
        }
    }

    @Test
    void missingEmailAndUnknownIdentitiesDoNotEmitPersonalClaims() {
        assertThat(claims(new HearthPrincipal(ID, "admin", "Admin", null), Set.of("email")))
                .containsExactlyInAnyOrderEntriesOf(Map.of("sub", ID.toString()));
        assertThat(claims("anonymous", Set.of("profile", "email"))).isEmpty();
        var user = User.withUsername("missing").password("").authorities(List.of()).build();
        assertThat(claims(user, Set.of("profile", "email"))).isEmpty();
        when(credentials.findByLogin("missing")).thenReturn(Optional.of(new PasswordCredential(ID, "missing", "hash", true, 0, null)));
        assertThat(claims(user, Set.of("profile", "email"))).isEmpty();
    }

    private Map<String, Object> claims(Object principal, Set<String> scopes) {
        // JwtClaimsSet rejects an empty set; the seed is removed from the result.
        var claims = JwtClaimsSet.builder().issuer("https://hearth.test");
        var context = JwtEncodingContext.with(JwsHeader.with(SignatureAlgorithm.RS256), claims)
                .principal(UsernamePasswordAuthenticationToken.authenticated(principal, null, List.of()))
                .authorizedScopes(scopes).build();
        new OidcTokenCustomizerConfiguration().hearthJwtTokenCustomizer(credentials, directory).customize(context);
        var result = new HashMap<>(claims.build().getClaims());
        result.remove("iss");
        return result;
    }
}
