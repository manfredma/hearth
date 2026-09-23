package manfred.hearth.adapter.web.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.rememberme.TokenBasedRememberMeServices;

/** Stateless, signed 30-day browser login for Hearth. */
public class HearthRememberMeServices extends TokenBasedRememberMeServices {

    static final int VALIDITY_SECONDS = 30 * 24 * 60 * 60;
    static final String COOKIE_NAME = "hearth-remember-me";

    public HearthRememberMeServices(String key, UserDetailsService userDetailsService, boolean secureCookie) {
        super(key, userDetailsService);
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
        if (userDetails instanceof HearthRememberMeUserDetailsService.PasswordBackedHearthPrincipal principal) {
            return UsernamePasswordAuthenticationToken.authenticated(
                    principal.principal(), null, principal.getAuthorities());
        }
        return super.createSuccessfulAuthentication(request, userDetails);
    }
}
