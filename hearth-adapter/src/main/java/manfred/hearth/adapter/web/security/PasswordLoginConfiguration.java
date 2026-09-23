package manfred.hearth.adapter.web.security;

import java.time.Clock;
import java.time.Duration;

import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.PasswordLoginService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration(proxyBeanMethods = false)
public class PasswordLoginConfiguration {

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    PasswordLoginService passwordLoginService(
            IdentityCredentialPort credentials,
            PasswordEncoder passwordEncoder,
            Clock clock,
            @Value("${hearth.authentication.failure-threshold:5}") int failureThreshold,
            @Value("${hearth.authentication.lock-duration:15m}") Duration lockDuration) {
        return new PasswordLoginService(credentials, passwordEncoder, clock, failureThreshold, lockDuration);
    }
}
