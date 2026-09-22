package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.net.MalformedURLException;
import java.net.URL;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;

class OidcIdentityMapperTest {

    private final OidcIdentityMapper mapper = new OidcIdentityMapper();

    @Test
    void mapsStableIssuerAndSubjectSeparatelyFromDisplayName() {
        OidcUser user = mock(OidcUser.class);
        when(user.getIssuer()).thenReturn(url("https://identity.example.com"));
        when(user.getClaimAsString("sub")).thenReturn("subject-123");
        when(user.getClaimAsString("name")).thenReturn("冯华杰");
        when(user.getEmail()).thenReturn("feng@example.com");

        OidcIdentityMapper.MappedIdentity mapped = mapper.map(user);

        assertThat(mapped.subject().issuer()).isEqualTo("https://identity.example.com");
        assertThat(mapped.subject().subject()).isEqualTo("subject-123");
        assertThat(mapped.profile().displayName()).isEqualTo("冯华杰");
        assertThat(mapped.profile().email()).isEqualTo("feng@example.com");
    }

    @Test
    void fallsBackToSubjectWhenProviderHasNoDisplayName() {
        OidcUser user = mock(OidcUser.class);
        when(user.getIssuer()).thenReturn(url("https://identity.example.com"));
        when(user.getClaimAsString("sub")).thenReturn("subject-123");
        when(user.getClaimAsString("name")).thenReturn(null);
        when(user.getClaimAsString("preferred_username")).thenReturn(null);
        when(user.getEmail()).thenReturn(null);

        assertThat(mapper.map(user).profile().displayName()).isEqualTo("subject-123");
    }

    private URL url(String value) {
        try {
            return new URL(value);
        } catch (MalformedURLException exception) {
            throw new IllegalArgumentException(exception);
        }
    }
}
