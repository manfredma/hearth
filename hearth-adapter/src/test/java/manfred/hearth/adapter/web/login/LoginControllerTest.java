package manfred.hearth.adapter.web.login;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.List;
import java.util.UUID;

import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.app.identity.IdentityProfile;
import manfred.hearth.app.identity.PasswordLoginService;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import manfred.hearth.domain.identity.IdentityAccount;
import manfred.hearth.domain.identity.IdentitySubject;
import manfred.hearth.domain.identity.PasswordCredential;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.web.savedrequest.HttpSessionRequestCache;
import org.springframework.security.web.savedrequest.SavedRequest;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.mock.web.MockHttpSession;
import jakarta.servlet.http.Cookie;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.assertj.core.api.Assertions.assertThat;

class LoginControllerTest {

    private static final UUID USER_ID = UUID.randomUUID();
    private static final Instant NOW = Instant.parse("2026-09-23T04:00:00Z");
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final FakeCredentials credentials = new FakeCredentials();
    private final HttpSessionRequestCache requestCache = new HttpSessionRequestCache();
    private final HearthRememberMeServices rememberMeServices = new HearthRememberMeServices(
            "test-key", username -> org.springframework.security.core.userdetails.User.withUsername(username)
                    .password(encoder.encode("secret")).authorities(List.of()).build(), false);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new LoginController(
            new PasswordLoginService(credentials, encoder, Clock.fixed(NOW, ZoneOffset.UTC), 3, Duration.ofMinutes(15)),
            new FakeDirectory(), requestCache, rememberMeServices)).build();

    @Test
    void returnsSessionIdentityAfterSuccessfulLogin() throws Exception {
        credentials.credential = new PasswordCredential(USER_ID, "admin", encoder.encode("secret"), true, 0, null);

        mvc.perform(post("/api/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"password\":\"secret\"}"))
                .andExpect(status().isOk())
                        .andExpect(result -> assertThat(result.getResponse().getContentAsString())
                        .contains("\"authenticated\":true", "\"displayName\":\"管理员\""));
    }

    @Test
    void storesAStandardSpringSecurityUserInTheSession() throws Exception {
        credentials.credential = new PasswordCredential(USER_ID, "admin", encoder.encode("secret"), true, 0, null);

        MvcResult result = mvc.perform(post("/api/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"password\":\"secret\"}"))
                .andExpect(status().isOk())
                .andReturn();

        SecurityContext context = (SecurityContext) result.getRequest().getSession()
                .getAttribute("SPRING_SECURITY_CONTEXT");
        assertThat(context.getAuthentication().getPrincipal()).isInstanceOf(User.class);
        assertThat(context.getAuthentication().getPrincipal()).isNotInstanceOf(
                manfred.hearth.adapter.web.security.HearthPrincipal.class);
    }

    @Test
    void returnsTheSavedAuthorizationRequestAfterSuccessfulLogin() throws Exception {
        credentials.credential = new PasswordCredential(USER_ID, "admin", encoder.encode("secret"), true, 0, null);
        MockHttpServletRequest authorizationRequest = new MockHttpServletRequest("GET", "/oauth2/authorize");
        authorizationRequest.setQueryString("client_id=daylilt&response_type=code");
        MockHttpSession session = (MockHttpSession) authorizationRequest.getSession(true);
        requestCache.saveRequest(authorizationRequest, new MockHttpServletResponse());

        mvc.perform(post("/api/login")
                        .session(session)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"password\":\"secret\"}"))
                .andExpect(status().isOk())
                .andExpect(result -> assertThat(result.getResponse().getContentAsString())
                        .contains("\"redirectTo\":\"/oauth2/authorize?client_id=daylilt&response_type=code"));
    }

    @Test
    void returnsGenericErrorForInvalidLogin() throws Exception {
        mvc.perform(post("/api/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"password\":\"wrong\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(result -> assertThat(result.getResponse().getContentAsString())
                        .contains("\"authenticated\":false", "登录失败，请检查账号或密码"));
    }

    @Test
    void selectedRememberMeLoginIssuesThirtyDayCookie() throws Exception {
        credentials.credential = new PasswordCredential(USER_ID, "admin", encoder.encode("secret"), true, 0, null);

        mvc.perform(post("/api/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"password\":\"secret\",\"rememberMe\":true}"))
                .andExpect(status().isOk())
                .andExpect(result -> assertThat(result.getResponse().getCookie("hearth-remember-me")).isNotNull());
    }

    @Test
    void unselectedLoginClearsAnExistingRememberMeCookie() throws Exception {
        credentials.credential = new PasswordCredential(USER_ID, "admin", encoder.encode("secret"), true, 0, null);
        MvcResult remembered = mvc.perform(post("/api/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"password\":\"secret\",\"rememberMe\":true}"))
                .andExpect(status().isOk())
                .andReturn();
        Cookie existing = remembered.getResponse().getCookie("hearth-remember-me");

        mvc.perform(post("/api/login")
                        .cookie(existing)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"password\":\"secret\",\"rememberMe\":false}"))
                .andExpect(status().isOk())
                .andExpect(result -> assertThat(result.getResponse().getCookie("hearth-remember-me").getMaxAge()).isZero());
    }

    private static final class FakeCredentials implements IdentityCredentialPort {

        private PasswordCredential credential;

        @Override
        public Optional<PasswordCredential> findByLogin(String login) {
            return credential == null || !credential.login().equals(login) ? Optional.empty() : Optional.of(credential);
        }

        @Override
        public void recordFailure(UUID userId, Instant lockedUntil) {
        }

        @Override
        public void resetFailures(UUID userId) {
        }
    }

    private static final class FakeDirectory implements IdentityDirectoryPort {

        @Override
        public IdentityAccount findOrCreate(IdentitySubject subject, IdentityProfile profile) {
            return new IdentityAccount(USER_ID, subject, profile.displayName(), profile.email());
        }

        @Override
        public Optional<IdentityAccount> findById(UUID id) {
            return id.equals(USER_ID)
                    ? Optional.of(new IdentityAccount(USER_ID, new IdentitySubject("https://hearth.example.com", "admin"), "管理员", "admin@example.com"))
                    : Optional.empty();
        }
    }
}
