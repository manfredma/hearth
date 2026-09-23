package manfred.hearth.adapter.oauth;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;

/**
 * Sends unauthenticated OIDC authorization requests to the login page while
 * preserving the exact relative authorization target for the post-login hop.
 */
final class HearthLoginAuthenticationEntryPoint implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authenticationException) throws IOException, ServletException {
        String target = request.getRequestURI();
        String query = request.getQueryString();
        if (query != null && !query.isBlank()) {
            target += "?" + query;
        }
        response.sendRedirect("/login?continue=" + URLEncoder.encode(target, StandardCharsets.UTF_8));
    }
}
