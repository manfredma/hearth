package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.http.Cookie;
import java.util.List;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.authority.FactorGrantedAuthority;
import org.springframework.security.core.Authentication;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

class HearthRememberMeServicesTest {

    @Test
    void restoresAuthenticationThroughTheFilterAndProvider() throws Exception {
        var user = User.withUsername("admin").password("password-hash").authorities(List.of()).build();
        var services = new HearthRememberMeServices("test-key", username -> user, Clock.systemUTC(), false);
        var issued = new MockHttpServletResponse();
        services.onInteractiveLogin(new MockHttpServletRequest(), issued,
                UsernamePasswordAuthenticationToken.authenticated(user, null, user.getAuthorities()), true);
        var request = new MockHttpServletRequest();
        request.setCookies(issued.getCookie("hearth-remember-me"));
        var manager = new org.springframework.security.authentication.ProviderManager(
                new org.springframework.security.authentication.RememberMeAuthenticationProvider("test-key"));
        var filter = new org.springframework.security.web.authentication.rememberme.RememberMeAuthenticationFilter(
                manager, services);
        try {
            filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> {
                var authentication = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
                assertThat(authentication).isInstanceOf(org.springframework.security.authentication.RememberMeAuthenticationToken.class);
                assertThat(authentication.isAuthenticated()).isTrue();
                assertThat(authentication.getName()).isEqualTo("admin");
                assertThat(authentication.getAuthorities()).anyMatch(FactorGrantedAuthority.class::isInstance);
            });
        } finally {
            org.springframework.security.core.context.SecurityContextHolder.clearContext();
        }
    }

    @Test
    void createsThirtyDayHttpOnlyLaxCookie() {
        HearthRememberMeServices services = new HearthRememberMeServices(
                "test-key", username -> User.withUsername(username).password("password-hash").authorities(List.of()).build(),
                Clock.fixed(Instant.parse("2026-09-24T12:00:00Z"), ZoneOffset.UTC), true);
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
        HearthRememberMeServices services = new HearthRememberMeServices("test-key", username -> remembered,
                Clock.fixed(Instant.parse("2026-09-24T12:00:00Z"), ZoneOffset.UTC), false);
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
        assertThat(restored.getAuthorities()).anyMatch(FactorGrantedAuthority.class::isInstance);
    }
}
