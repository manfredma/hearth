package manfred.hearth.adapter.oauth;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.oauth2.server.authorization.OAuth2AuthorizationServerConfigurer;
import org.springframework.security.oauth2.server.authorization.OAuth2AuthorizationConsentService;
import org.springframework.security.oauth2.server.authorization.OAuth2AuthorizationService;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClientRepository;
import org.springframework.security.oauth2.server.authorization.settings.AuthorizationServerSettings;
import org.springframework.security.config.annotation.web.configurers.CsrfConfigurer;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.savedrequest.HttpSessionRequestCache;
import org.springframework.security.web.savedrequest.RequestCache;
import org.springframework.security.web.util.matcher.RequestMatcher;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import manfred.hearth.adapter.web.security.LegacyHearthPrincipalMigrationFilter;

@Configuration(proxyBeanMethods = false)
public class AuthorizationServerSecurityConfig {

    @Bean
    RequestCache hearthRequestCache() {
        return new HttpSessionRequestCache();
    }

    @Bean
    @Order(1)
    SecurityFilterChain authorizationServerSecurityFilterChain(
            HttpSecurity http,
            RegisteredClientRepository registeredClientRepository,
            OAuth2AuthorizationService authorizationService,
            OAuth2AuthorizationConsentService authorizationConsentService,
            AuthorizationServerSettings authorizationServerSettings,
            RequestCache requestCache,
            HearthRememberMeServices rememberMeServices,
            LegacyHearthPrincipalMigrationFilter legacyPrincipalMigrationFilter) throws Exception {
        OAuth2AuthorizationServerConfigurer authorizationServer = new OAuth2AuthorizationServerConfigurer();
        http
                .securityMatcher(authorizationServer.getEndpointsMatcher())
                .with(authorizationServer, server -> server
                        .registeredClientRepository(registeredClientRepository)
                        .authorizationService(authorizationService)
                        .authorizationConsentService(authorizationConsentService)
                        .authorizationServerSettings(authorizationServerSettings)
                        .authorizationEndpoint(endpoint -> endpoint.consentPage("/oauth2/consent"))
                        .oidc(Customizer.withDefaults()))
                .authorizeHttpRequests(authorize -> authorize.anyRequest().authenticated())
                // OAuth's one-time state parameter protects the browser consent
                // POST. Exclude the dedicated Authorization Server endpoints
                // from the generic web CSRF filter as the framework requires.
                .csrf(csrf -> configureCsrf(csrf, authorizationServer.getEndpointsMatcher()))
                .rememberMe(rememberMe -> rememberMe.rememberMeServices(rememberMeServices))
                .requestCache(cache -> cache.requestCache(requestCache))
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(new HearthLoginAuthenticationEntryPoint()));
        // Migrate old Redis sessions before OAuth serializes Authentication
        // into the JDBC authorization record.
        http.addFilterAfter(legacyPrincipalMigrationFilter,
                org.springframework.security.web.authentication.rememberme.RememberMeAuthenticationFilter.class);
        return http.build();
    }

    /**
     * OAuth Authorization Server carries the consent CSRF protection in its
     * one-time {@code state} parameter. Applying the generic web repository as
     * well would make the custom consent form satisfy two token contracts.
     */
    static void configureCsrf(CsrfConfigurer<HttpSecurity> csrf, RequestMatcher endpointsMatcher) {
        csrf.ignoringRequestMatchers(endpointsMatcher);
    }
}
