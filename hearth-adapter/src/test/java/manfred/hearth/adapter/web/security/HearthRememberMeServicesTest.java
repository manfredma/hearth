package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.http.Cookie;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.Authentication;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

class HearthRememberMeServicesTest {

    @Test
    void createsThirtyDayHttpOnlyLaxCookie() {
        HearthRememberMeServices services = new HearthRememberMeServices(
                "test-key", username -> User.withUsername(username).password("password-hash").authorities(List.of()).build(), true);
        MockHttpServletResponse response = new MockHttpServletResponse();

        services.onLoginSuccess(new MockHttpServletRequest(), response,
                new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(
                        User.withUsername("admin").password("password-hash").authorities(List.of()).build(), null));

        Cookie cookie = response.getCookie("hearth-remember-me");
        assertThat(cookie).isNotNull();
        assertThat(cookie.getMaxAge()).isEqualTo(30 * 24 * 60 * 60);
        assertThat(cookie.isHttpOnly()).isTrue();
        assertThat(cookie.getSecure()).isTrue();
        assertThat(cookie.getAttribute("SameSite")).isEqualTo("Lax");
    }

    @Test
    void restoresAStandardSpringSecurityUserAfterShortSessionExpires() {
        org.springframework.security.core.userdetails.UserDetails remembered =
                User.withUsername("admin").password("password-hash").authorities(List.of()).build();
        HearthRememberMeServices services = new HearthRememberMeServices("test-key", username -> remembered, false);
        MockHttpServletRequest loginRequest = new MockHttpServletRequest();
        MockHttpServletResponse loginResponse = new MockHttpServletResponse();
        services.onLoginSuccess(loginRequest, loginResponse,
                UsernamePasswordAuthenticationToken.authenticated(
                        remembered,
                        null, java.util.List.of()));

        MockHttpServletRequest restoredRequest = new MockHttpServletRequest();
        restoredRequest.setCookies(loginResponse.getCookie("hearth-remember-me"));
        Authentication restored = services.autoLogin(restoredRequest, new MockHttpServletResponse());

        assertThat(restored).isNotNull();
        assertThat(restored.getPrincipal()).isInstanceOf(User.class);
        assertThat(((User) restored.getPrincipal()).getUsername()).isEqualTo("admin");
    }
}
