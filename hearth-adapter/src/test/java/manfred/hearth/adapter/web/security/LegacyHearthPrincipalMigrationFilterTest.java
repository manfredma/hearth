package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import java.util.List;
import java.util.UUID;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;

class LegacyHearthPrincipalMigrationFilterTest {

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void convertsLegacyPrincipalBeforeTheOAuthAuthorizationEndpointReadsIt() throws Exception {
        HearthPrincipal legacy = new HearthPrincipal(UUID.randomUUID(), "admin", "管理员", "admin@example.com");
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(legacy, null, List.of()));
        SecurityContextHolder.setContext(context);
        FilterChain chain = mock(FilterChain.class);

        new LegacyHearthPrincipalMigrationFilter(Clock.fixed(Instant.parse("2026-09-24T12:00:00Z"), ZoneOffset.UTC)).doFilter(
                new MockHttpServletRequest(), new MockHttpServletResponse(), chain);

        assertThat(SecurityContextHolder.getContext().getAuthentication().getPrincipal())
                .isInstanceOf(User.class);
        assertThat(SecurityContextHolder.getContext().getAuthentication().getAuthorities())
                .anyMatch(org.springframework.security.core.authority.FactorGrantedAuthority.class::isInstance);
        verify(chain).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void addsAnAuthenticationFactorToFrameworkUsersRestoredFromAnOlderSession() throws Exception {
        UserDetailsWithoutFactors restored = new UserDetailsWithoutFactors("admin");
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(restored, null, List.of()));
        SecurityContextHolder.setContext(context);

        new LegacyHearthPrincipalMigrationFilter(Clock.fixed(Instant.parse("2026-09-24T12:00:00Z"), ZoneOffset.UTC)).doFilter(
                new MockHttpServletRequest(), new MockHttpServletResponse(), mock(FilterChain.class));

        assertThat(SecurityContextHolder.getContext().getAuthentication().getAuthorities())
                .anyMatch(org.springframework.security.core.authority.FactorGrantedAuthority.class::isInstance);
    }

    private static final class UserDetailsWithoutFactors extends User {
        private UserDetailsWithoutFactors(String username) {
            super(username, "", List.of());
        }
    }
}
