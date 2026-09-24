package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.servlet.http.HttpServletRequest;
import manfred.hearth.app.identity.CurrentIdentity;
import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.app.identity.IdentityProfile;
import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;
import manfred.hearth.domain.identity.PasswordCredential;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.User;
import org.springframework.web.context.request.ServletWebRequest;

class CurrentIdentityArgumentResolverTest {

    private static final UUID USER_ID = UUID.randomUUID();

    @Test
    void resolvesStandardSpringSecurityUserFromTheHearthDirectory() throws Exception {
        IdentityCredentialPort credentials = mock(IdentityCredentialPort.class);
        IdentityDirectoryPort directory = mock(IdentityDirectoryPort.class);
        OidcIdentityMapper identityMapper = mock(OidcIdentityMapper.class);
        when(credentials.findByLogin("admin")).thenReturn(Optional.of(
                new PasswordCredential(USER_ID, "admin", "hash", true, 0, null)));
        when(directory.findById(USER_ID)).thenReturn(Optional.of(account()));
        CurrentIdentityArgumentResolver resolver =
                new CurrentIdentityArgumentResolver(directory, credentials, identityMapper);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setUserPrincipal(UsernamePasswordAuthenticationToken.authenticated(
                User.withUsername("admin").password("").authorities(List.of()).build(), null, List.of()));
        MethodParameter parameter = new MethodParameter(
                CurrentIdentityArgumentResolverTest.class.getDeclaredMethod("endpoint", CurrentIdentity.class), 0);

        CurrentIdentity identity = (CurrentIdentity) resolver.resolveArgument(
                parameter, null, new ServletWebRequest(request), null);

        assertThat(identity.userId()).isEqualTo(USER_ID);
        assertThat(identity.username()).isEqualTo("admin");
        assertThat(identity.displayName()).isEqualTo("管理员");
    }

    private static void endpoint(CurrentIdentity ignored) {
    }

    private IdentityAccount account() {
        return new IdentityAccount(USER_ID, new IdentitySubject("https://hearth.example.com", "admin"),
                "管理员", "admin@example.com");
    }
}
