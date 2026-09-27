package manfred.hearth.adapter.web.login;

import java.time.Clock;
import java.util.*;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import manfred.hearth.app.identity.*;
import manfred.hearth.domain.identity.*;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;
import org.springframework.security.web.savedrequest.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class LoginRedirectBoundaryTest {
    @Test
    void savedRedirectsStayOnTheRequestOriginAcrossSchemesPortsAndRelativePaths() {
        String[][] cases = {
                {"/oauth2/authorize?x=y", "http", "80", "/oauth2/authorize?x=y"},
                {"relative", "http", "80", "/"}, {"//evil.test/path", "http", "80", "/path"},
                {"http://localhost/path", "http", "80", "/path"},
                {"https://localhost/path", "http", "80", "/"},
                {"http://evil.test/path", "http", "80", "/"},
                {"http://localhost:81/path", "http", "80", "/"},
                {"http://localhost/path?x=y", "http", "0", "/path?x=y"},
                {"https://localhost/path", "https", "0", "/path"},
                {"https://localhost:443/path", "https", "443", "/path"},
                {"http://localhost", "http", "80", "/"},
                {"mailto:admin@example.test", "http", "80", "/"},
                {"////evil.test/path", "http", "80", "/"}
        };
        for (String[] fixture : cases) {
            var service = mock(PasswordLoginService.class);
            var directory = mock(IdentityDirectoryPort.class);
            var cache = mock(RequestCache.class);
            var remember = mock(HearthRememberMeServices.class);
            UUID id = UUID.randomUUID();
            when(service.authenticate("admin", "secret")).thenReturn(new PasswordLoginService.AuthenticatedIdentity(id, "admin"));
            when(directory.findById(id)).thenReturn(Optional.of(new IdentityAccount(id,
                    new IdentitySubject("https://hearth.test", "subject"), "Admin", null)));
            var saved = mock(SavedRequest.class);
            when(saved.getRedirectUrl()).thenReturn(fixture[0]);
            when(cache.getRequest(any(), any())).thenReturn(saved);
            var request = new MockHttpServletRequest();
            request.setScheme(fixture[1]);
            request.setServerPort(Integer.parseInt(fixture[2]));
            var result = new LoginController(service, directory, cache, remember, Clock.systemUTC()).login(
                    new LoginController.LoginRequest("admin", "secret", false), request, new MockHttpServletResponse());
            assertThat(result.redirectTo()).as(Arrays.toString(fixture)).isEqualTo(fixture[3]);
            verify(cache).removeRequest(any(), any());
        }
    }

    @Test
    void missingIdentityCannotCreateAuthenticatedSession() {
        var service = mock(PasswordLoginService.class);
        when(service.authenticate(any(), any())).thenReturn(new PasswordLoginService.AuthenticatedIdentity(UUID.randomUUID(), "admin"));
        var request = new MockHttpServletRequest();
        var controller = new LoginController(service, mock(IdentityDirectoryPort.class), mock(RequestCache.class),
                mock(HearthRememberMeServices.class), Clock.systemUTC());
        assertThatThrownBy(() -> controller.login(new LoginController.LoginRequest("admin", "secret", null),
                request, new MockHttpServletResponse())).isInstanceOf(PasswordLoginService.InvalidCredentialsException.class);
        assertThat(request.getSession(false)).isNull();
    }
}
