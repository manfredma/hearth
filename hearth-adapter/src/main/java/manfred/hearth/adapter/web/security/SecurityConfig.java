package manfred.hearth.adapter.web.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
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
            @Value("${hearth.authentication.remember-me-key}") String rememberMeKey,
            @Value("${hearth.authentication.remember-me-cookie-secure:false}") boolean secureCookie) {
        return new HearthRememberMeServices(rememberMeKey, userDetailsService, secureCookie);
    }

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, HearthRememberMeServices rememberMeServices) throws Exception {
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
        return http.build();
    }

    static String[] publicRequestMatchers() {
        return new String[]{
                "/", "/index.html", "/assets/**", "/favicon.ico", "/favicon.svg", "/api/health",
                "/api/login", "/api/csrf", "/login", "/.well-known/openid-configuration", "/oauth2/jwks"
        };
    }

    static void configureCsrf(CsrfConfigurer<HttpSecurity> csrf) {
        csrf.ignoringRequestMatchers("/api/health");
        CookieCsrfTokenRepository repository = CookieCsrfTokenRepository.withHttpOnlyFalse();
        repository.setHeaderName("X-CSRF-TOKEN");
        csrf.csrfTokenRepository(repository);
        csrf.csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler());
    }
}
