package manfred.hearth.adapter.oauth;

import java.security.*;
import java.time.Duration;
import java.util.Base64;
import com.nimbusds.jose.jwk.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class ProviderBoundaryTest {
    @Test
    void validatesEveryIssuerAndLifetimeBoundary() {
        String[] issuers = {"", "not a uri", "/relative", "http://hearth.test"};
        for (String issuer : issuers) {
            assertThatThrownBy(() -> properties(issuer, "key", Duration.ofSeconds(1), Duration.ofSeconds(1)).validate("production"))
                    .isInstanceOf(IllegalArgumentException.class);
        }
        assertThatThrownBy(() -> properties("https://hearth.test", "", Duration.ofSeconds(1), Duration.ofSeconds(1)).validate("production"))
                .isInstanceOf(IllegalArgumentException.class);
        for (Duration invalid : new Duration[]{Duration.ZERO, Duration.ofSeconds(-1)}) {
            assertThatThrownBy(() -> properties("https://hearth.test", "key", invalid, Duration.ofSeconds(1)).validate("production"))
                    .isInstanceOf(IllegalArgumentException.class);
            assertThatThrownBy(() -> properties("https://hearth.test", "key", Duration.ofSeconds(1), invalid).validate("production"))
                    .isInstanceOf(IllegalArgumentException.class);
        }
        properties("http://localhost", "key", Duration.ofSeconds(1), Duration.ofSeconds(1)).validate("test");
        properties("https://hearth.test", "key", Duration.ofSeconds(1), Duration.ofSeconds(1)).validate("production");
    }

    private HearthAuthorizationServerProperties properties(String issuer, String key, Duration access, Duration refresh) {
        return new HearthAuthorizationServerProperties(issuer, key, access, refresh);
    }

    @Test
    void onlyLocalAndTestMayGenerateEphemeralKeysAndConfiguredKeyIdIsStable() throws Exception {
        var config = new SigningKeyConfiguration();
        var selector = new JWKSelector(new JWKMatcher.Builder().keyType(KeyType.RSA).build());
        for (String environment : new String[]{"local", "test"}) {
            assertThat(config.jwkSource("", environment).get(selector, null)).hasSize(1);
        }
        assertThatThrownBy(() -> config.jwkSource("", "production")).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> config.jwkSource("bad key", "production")).isInstanceOf(IllegalStateException.class);
        var generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        String encoded = Base64.getEncoder().encodeToString(generator.generateKeyPair().getPrivate().getEncoded());
        var first = config.jwkSource(encoded, "production").get(selector, null).getFirst();
        var second = config.jwkSource(encoded, "production").get(selector, null).getFirst();
        assertThat(first.getKeyID()).isEqualTo(second.getKeyID());
        assertThat(first.isPrivate()).isTrue();
    }

    @Test
    void cryptoProviderFailuresFailClosed() throws Exception {
        var config = new SigningKeyConfiguration();
        try (var generators = mockStatic(KeyPairGenerator.class)) {
            generators.when(() -> KeyPairGenerator.getInstance("RSA")).thenThrow(new NoSuchAlgorithmException());
            assertThatThrownBy(() -> config.jwkSource("", "local")).hasMessageContaining("unable to create");
        }
        try (var factories = mockStatic(KeyFactory.class)) {
            var factory = mock(KeyFactory.class);
            factories.when(() -> KeyFactory.getInstance("RSA")).thenReturn(factory);
            when(factory.generatePrivate(any())).thenReturn(mock(PrivateKey.class));
            assertThatThrownBy(() -> config.jwkSource("AA==", "production")).hasMessageContaining("PKCS#8");
        }
        try (var digests = mockStatic(MessageDigest.class)) {
            digests.when(() -> MessageDigest.getInstance("SHA-256")).thenThrow(new NoSuchAlgorithmException());
            assertThatThrownBy(() -> config.jwkSource("", "test"))
                    .hasRootCauseMessage(null).isInstanceOf(IllegalStateException.class);
        }
    }

    @Test
    void persistenceConfigurationCreatesJdbcBackedProtocolStores() {
        var config = new OAuthPersistenceConfiguration();
        var jdbc = mock(JdbcTemplate.class);
        var clients = config.registeredClientRepository(jdbc);
        assertThat(clients).isInstanceOf(org.springframework.security.oauth2.server.authorization.client.JdbcRegisteredClientRepository.class);
        assertThat(config.authorizationService(jdbc, clients)).isInstanceOf(org.springframework.security.oauth2.server.authorization.JdbcOAuth2AuthorizationService.class);
        assertThat(config.authorizationConsentService(jdbc, clients)).isInstanceOf(org.springframework.security.oauth2.server.authorization.JdbcOAuth2AuthorizationConsentService.class);
    }

    @Test
    void loginEntryPointHandlesAbsentAndBlankQuery() throws Exception {
        for (String query : new String[]{null, " "}) {
            var request = new MockHttpServletRequest("GET", "/oauth2/authorize");
            request.setQueryString(query);
            var response = new MockHttpServletResponse();
            new HearthLoginAuthenticationEntryPoint().commence(request, response, null);
            assertThat(response.getRedirectedUrl()).isEqualTo("/login?continue=%2Foauth2%2Fauthorize");
        }
    }
}
