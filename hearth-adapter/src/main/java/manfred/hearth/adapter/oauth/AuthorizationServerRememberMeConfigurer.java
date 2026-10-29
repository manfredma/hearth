package manfred.hearth.adapter.oauth;

import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.RememberMeAuthenticationProvider;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.configurers.LogoutConfigurer;
import org.springframework.security.web.authentication.RememberMeServices;
import org.springframework.security.web.authentication.logout.LogoutFilter;
import org.springframework.security.web.authentication.rememberme.RememberMeAuthenticationFilter;
import org.springframework.security.web.authentication.session.SessionAuthenticationStrategy;
import org.springframework.security.web.context.SecurityContextRepository;

/** Restores the identity before Spring's authorization request pre-validation caches it. */
final class AuthorizationServerRememberMeConfigurer extends AbstractHttpConfigurer<AuthorizationServerRememberMeConfigurer, HttpSecurity> {
    private final HearthRememberMeServices services;

    AuthorizationServerRememberMeConfigurer(HearthRememberMeServices services) {
        this.services = services;
    }

    @Override
    public void init(HttpSecurity http) {
        http.setSharedObject(RememberMeServices.class, services);
        http.authenticationProvider(postProcess(new RememberMeAuthenticationProvider(services.getKey())));
        http.getConfigurer(LogoutConfigurer.class).addLogoutHandler(services);
    }

    @Override
    public void configure(HttpSecurity http) {
        // Preserve the standard RememberMeConfigurer authentication and session contracts.
        // Reuse the same context repository and fixation protection as the default filter.
        var filter = new RememberMeAuthenticationFilter(http.getSharedObject(AuthenticationManager.class), services);
        filter.setSecurityContextHolderStrategy(getSecurityContextHolderStrategy());
        filter.setSecurityContextRepository(http.getSharedObject(SecurityContextRepository.class));
        filter.setSessionAuthenticationStrategy(http.getSharedObject(SessionAuthenticationStrategy.class));
        // The validating filter is before AbstractPreAuthenticatedProcessingFilter;
        // LogoutFilter is an earlier public ordering anchor, after context loading and CSRF.
        http.addFilterAfter(postProcess(filter), LogoutFilter.class);
    }
}
