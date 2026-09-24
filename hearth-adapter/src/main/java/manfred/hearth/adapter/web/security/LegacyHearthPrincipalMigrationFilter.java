package manfred.hearth.adapter.web.security;

import java.io.IOException;
import java.util.List;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextHolderStrategy;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Converts sessions created before the OAuth principal persistence fix.
 *
 * <p>Older Redis sessions may still contain {@link HearthPrincipal}. Converting
 * it before the authorization endpoint runs prevents those sessions from
 * writing another rejected principal into {@code oauth2_authorization}; the
 * next request then carries the same login as a framework-supported User.</p>
 */
@Component
public class LegacyHearthPrincipalMigrationFilter extends OncePerRequestFilter {

    private final SecurityContextRepository securityContextRepository = new HttpSessionSecurityContextRepository();
    private final SecurityContextHolderStrategy securityContextHolderStrategy =
            SecurityContextHolder.getContextHolderStrategy();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        SecurityContext context = securityContextHolderStrategy.getContext();
        Authentication authentication = context.getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof HearthPrincipal legacy) {
            // Keep authorities from the existing authentication, but discard
            // the legacy profile fields. CurrentIdentityArgumentResolver will
            // read the authoritative profile from the identity directory.
            Authentication migrated = UsernamePasswordAuthenticationToken.authenticated(
                    User.withUsername(legacy.username()).password("").authorities(List.of()).build(),
                    null, authentication.getAuthorities());
            context.setAuthentication(migrated);
            securityContextRepository.saveContext(context, request, response);
            securityContextHolderStrategy.setContext(context);
        }
        filterChain.doFilter(request, response);
    }
}
