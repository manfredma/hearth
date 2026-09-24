package manfred.hearth.adapter.web.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import java.time.Clock;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.CsrfConfigurer;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.logout.HttpStatusReturningLogoutSuccessHandler;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;
import org.springframework.security.web.csrf.CsrfTokenRequestAttributeHandler;
import org.springframework.security.core.userdetails.UserDetailsService;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    HearthRememberMeServices rememberMeServices(
            UserDetailsService userDetailsService,
            Clock clock,
            @Value("${hearth.authentication.remember-me-key}") String rememberMeKey,
            @Value("${hearth.authentication.remember-me-cookie-secure:false}") boolean secureCookie) {
        return new HearthRememberMeServices(rememberMeKey, userDetailsService, clock, secureCookie);
    }

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, HearthRememberMeServices rememberMeServices,
                                    LegacyHearthPrincipalMigrationFilter legacyPrincipalMigrationFilter) throws Exception {
        http
                .csrf(SecurityConfig::configureCsrf)
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(publicRequestMatchers())
                        .permitAll()
                        .requestMatchers("/oauth2/**", "/login/**", "/userinfo", "/connect/logout")
                        .permitAll()
                        .requestMatchers("/api/session/**")
                        .authenticated()
                        .anyRequest()
                        .authenticated())
                .logout(logout -> logout
                        .logoutUrl("/api/session/logout")
                        .logoutSuccessHandler(new HttpStatusReturningLogoutSuccessHandler(HttpStatus.NO_CONTENT)));
        http.rememberMe(rememberMe -> rememberMe.rememberMeServices(rememberMeServices));
        // The same migration is needed on ordinary requests so a legacy
        // session cannot be persisted again before reaching an OAuth route.
        http.addFilterAfter(legacyPrincipalMigrationFilter,
                org.springframework.security.web.authentication.rememberme.RememberMeAuthenticationFilter.class);
        return http.build();
    }

    static String[] publicRequestMatchers() {
        return new String[]{
                "/", "/index.html", "/assets/**", "/favicon.ico", "/favicon.svg", "/api/health",
                "/api/login", "/api/csrf", "/login", "/consent-preview", "/.well-known/openid-configuration", "/oauth2/jwks"
        };
    }

    /**
     * Applies the same cookie-backed CSRF contract to every Hearth filter
     * chain. The OAuth authorization endpoints use a separate higher-priority
     * chain, so keeping this configuration reusable prevents its consent POST
     * from silently falling back to a different session-backed token.
     */
    public static void configureCsrf(CsrfConfigurer<HttpSecurity> csrf) {
        csrf.ignoringRequestMatchers("/api/health");
        CookieCsrfTokenRepository repository = CookieCsrfTokenRepository.withHttpOnlyFalse();
        repository.setHeaderName("X-CSRF-TOKEN");
        csrf.csrfTokenRepository(repository);
        csrf.csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler());
    }
}
