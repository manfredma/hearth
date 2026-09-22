package manfred.hearth.adapter.web.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.logout.HttpStatusReturningLogoutSuccessHandler;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http,
                                    @Value("${hearth.oidc.enabled:false}") boolean oidcEnabled,
                                    OidcLoginSuccessHandler loginSuccessHandler) throws Exception {
        http
                .csrf(csrf -> csrf.ignoringRequestMatchers("/api/health"))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/", "/index.html", "/assets/**", "/favicon.ico", "/api/health")
                        .permitAll()
                        .requestMatchers("/oauth2/**", "/login/**")
                        .permitAll()
                        .requestMatchers("/api/session/**")
                        .authenticated()
                        .anyRequest()
                        .authenticated())
                .logout(logout -> logout
                        .logoutUrl("/api/session/logout")
                        .logoutSuccessHandler(new HttpStatusReturningLogoutSuccessHandler(HttpStatus.NO_CONTENT)));

        if (oidcEnabled) {
            http.oauth2Login(oauth2 -> oauth2
                    .loginPage("/oauth2/authorization/hearth")
                    .successHandler(loginSuccessHandler));
        }
        return http.build();
    }
}
