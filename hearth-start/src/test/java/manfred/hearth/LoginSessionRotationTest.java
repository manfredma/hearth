package manfred.hearth;

import java.time.Clock;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import jakarta.servlet.http.Cookie;
import manfred.hearth.adapter.web.login.LoginController;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.app.identity.PasswordLoginService;
import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.web.savedrequest.HttpSessionRequestCache;
import org.springframework.session.MapSessionRepository;
import org.springframework.session.web.http.SessionRepositoryFilter;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class LoginSessionRotationTest {
    @Test
    void oldAnonymousSessionIdCannotLoadAuthenticatedSessionAfterLogin() throws Exception {
        var sessions = new MapSessionRepository(new ConcurrentHashMap<>());
        var anonymous = sessions.createSession();
        anonymous.setAttribute("saved", "authorization-request");
        sessions.save(anonymous);
        String oldId = anonymous.getId();
        var serializer = new org.springframework.session.web.http.DefaultCookieSerializer();
        serializer.setUseBase64Encoding(false);
        var resolver = new org.springframework.session.web.http.CookieHttpSessionIdResolver();
        resolver.setCookieSerializer(serializer);
        var filter = new SessionRepositoryFilter<>(sessions);
        filter.setHttpSessionIdResolver(resolver);
        var login = mock(PasswordLoginService.class);
        var directory = mock(IdentityDirectoryPort.class);
        UUID id = UUID.randomUUID();
        when(login.authenticate("admin", "secret")).thenReturn(new PasswordLoginService.AuthenticatedIdentity(id, "admin"));
        when(directory.findById(id)).thenReturn(Optional.of(new IdentityAccount(id,
                new IdentitySubject("https://hearth.test", "admin"), "Admin", null)));
        var remember = new HearthRememberMeServices("key", name -> User.withUsername(name)
                .password("hash").authorities(List.of()).build(), Clock.systemUTC(), false);
        var mvc = MockMvcBuilders.standaloneSetup(new LoginController(login, directory,
                new HttpSessionRequestCache(), remember, Clock.systemUTC())).addFilters(filter).build();
        var response = mvc.perform(post("/api/login").cookie(new Cookie("SESSION", oldId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"login\":\"admin\",\"password\":\"secret\"}"))
                .andExpect(status().isOk()).andReturn().getResponse();
        assertThat(response.getCookie("SESSION")).isNotNull();
        String newId = response.getCookie("SESSION").getValue();
        assertThat(newId).isNotEqualTo(oldId);
        assertThat(sessions.findById(oldId)).isNull();
        var authenticated = sessions.findById(newId);
        assertThat((String) authenticated.getAttribute("saved")).isEqualTo("authorization-request");
        SecurityContext context = authenticated.getAttribute("SPRING_SECURITY_CONTEXT");
        assertThat(context.getAuthentication().getName()).isEqualTo("admin");
        var replay = new org.springframework.mock.web.MockHttpServletRequest();
        replay.setCookies(new Cookie("SESSION", oldId));
        filter.doFilter(replay, new org.springframework.mock.web.MockHttpServletResponse(), (req, res) ->
                assertThat(((jakarta.servlet.http.HttpServletRequest) req).getSession(false)).isNull());
    }
}
