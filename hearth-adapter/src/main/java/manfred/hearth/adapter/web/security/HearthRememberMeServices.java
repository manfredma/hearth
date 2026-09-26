package manfred.hearth.adapter.web.security;

import java.time.Clock;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.rememberme.TokenBasedRememberMeServices;

/** Stateless, signed 30-day browser login for Hearth. */
public class HearthRememberMeServices extends TokenBasedRememberMeServices {

    static final int VALIDITY_SECONDS = 30 * 24 * 60 * 60;
    static final String COOKIE_NAME = "hearth-remember-me";
    private final Clock clock;

    public HearthRememberMeServices(String key, UserDetailsService userDetailsService, Clock clock,
                                    boolean secureCookie) {
        super(key, userDetailsService);
        this.clock = clock;
        setParameter("remember-me");
        setCookieName(COOKIE_NAME);
        setTokenValiditySeconds(VALIDITY_SECONDS);
        setUseSecureCookie(secureCookie);
        setCookieCustomizer(cookie -> cookie.setAttribute("SameSite", "Lax"));
        afterPropertiesSet();
    }

    public void onInteractiveLogin(HttpServletRequest request, HttpServletResponse response,
                                   Authentication authentication, boolean rememberMe) {
        if (rememberMe) {
            onLoginSuccess(request, response, authentication);
        } else {
            loginFail(request, response);
        }
    }

    @Override
    protected Authentication createSuccessfulAuthentication(HttpServletRequest request, UserDetails userDetails) {
        // TokenBasedRememberMeServices verifies the signed cookie using the
        // stored password hash. The new request must receive a fresh standard
        // User with an authentication factor timestamp so OIDC can emit auth_time.
        UserDetails principal = User.withUsername(userDetails.getUsername())
                .password("")
                .authorities(HearthAuthenticationFactors.password(clock))
                .build();
        return UsernamePasswordAuthenticationToken.authenticated(
                principal, null, principal.getAuthorities());
    }
}
