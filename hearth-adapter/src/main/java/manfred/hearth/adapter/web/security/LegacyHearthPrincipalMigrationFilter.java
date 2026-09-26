package manfred.hearth.adapter.web.security;

import java.io.IOException;
import java.time.Clock;
import java.util.ArrayList;
import java.util.Collection;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.FactorGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextHolderStrategy;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
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
    private final Clock clock;

    public LegacyHearthPrincipalMigrationFilter(Clock clock) {
        this.clock = clock;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        SecurityContext context = securityContextHolderStrategy.getContext();
        Authentication authentication = context.getAuthentication();
        if (authentication != null && requiresAuthenticationFactor(authentication)) {
            UserDetails principal = normalizedPrincipal(authentication);
            Authentication migrated = UsernamePasswordAuthenticationToken.authenticated(
                    principal, null, principal.getAuthorities());
            context.setAuthentication(migrated);
            securityContextRepository.saveContext(context, request, response);
            securityContextHolderStrategy.setContext(context);
        }
        filterChain.doFilter(request, response);
    }

    /**
     * Spring Authorization Server requires an authentication factor timestamp
     * to emit the OIDC {@code auth_time} claim. Older sessions can contain
     * either the old Hearth principal or a framework UserDetails with no
     * factor authority, so both representations need normalization.
     */
    private boolean requiresAuthenticationFactor(Authentication authentication) {
        return authentication.getPrincipal() instanceof HearthPrincipal
                || authentication.getPrincipal() instanceof UserDetails
                && authentication.getAuthorities().stream()
                .noneMatch(FactorGrantedAuthority.class::isInstance);
    }

    /**
     * Keeps ordinary authorities, drops the legacy profile object, and adds
     * the current request's authentication timestamp to the new principal.
     */
    private UserDetails normalizedPrincipal(Authentication authentication) {
        String username = ((UserDetails) authentication.getPrincipal()).getUsername();
        Collection<GrantedAuthority> authorities = new ArrayList<>(authentication.getAuthorities());
        authorities.addAll(HearthAuthenticationFactors.password(clock));
        return User.withUsername(username).password("").authorities(authorities).build();
    }
}
