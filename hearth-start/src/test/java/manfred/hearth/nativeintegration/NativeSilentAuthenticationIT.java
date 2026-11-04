package manfred.hearth.nativeintegration;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.sql.DriverManager;
import java.time.Clock;
import java.time.Duration;
import java.util.List;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.userdetails.User;
import org.springframework.web.util.UriComponentsBuilder;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Real HTTP against the isolated staging slot; never selected by local unit tests. */
class NativeSilentAuthenticationIT {
    @Test
    void signedExpiredCookieReturnsLoginRequiredThroughRegisteredRelyingPartyFlow() throws Exception {
        String hash;
        try (var connection = DriverManager.getConnection(required("HEARTH_DATASOURCE_URL"),
                required("HEARTH_DATASOURCE_USERNAME"), required("HEARTH_DATASOURCE_PASSWORD"));
             var query = connection.prepareStatement("SELECT password_hash FROM identity_credential WHERE login = 'admin' AND enabled = TRUE");
             var rows = query.executeQuery()) {
            assertTrue(rows.next(), "isolated administrator exists");
            hash = rows.getString(1);
        }
        var client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10))
                .followRedirects(HttpClient.Redirect.NEVER).build();
        var entry = client.send(HttpRequest.newBuilder(URI.create(
                "https://staging-bytedepth.bytedepth.cn/oauth2/authorization/hearth"))
                .timeout(Duration.ofSeconds(20)).GET().build(), HttpResponse.BodyHandlers.discarding());
        assertTrue(entry.statusCode() == 302, "normal relying-party authorization entry redirects");
        var request = URI.create(entry.headers().firstValue("Location").orElseThrow());
        assertTrue("staging-hearth.bytedepth.cn".equals(request.getHost())
                && "/oauth2/authorize".equals(request.getPath()), "registered staging issuer only");
        var original = UriComponentsBuilder.fromUri(request).build().getQueryParams();
        String expired = new SignedExpiredCookie(required("HEARTH_REMEMBER_ME_KEY")).cookie(hash);
        var silent = URI.create(request.toASCIIString() + "&prompt=none");
        var response = client.send(HttpRequest.newBuilder(silent).timeout(Duration.ofSeconds(20))
                .header("Cookie", "hearth-remember-me=" + expired).GET().build(), HttpResponse.BodyHandlers.discarding());
        assertTrue(response.statusCode() == 302, "expired credential produces a protocol response");
        var callback = UriComponentsBuilder.fromUriString(response.headers().firstValue("Location").orElseThrow()).build();
        var query = callback.getQueryParams();
        String expected = java.net.URLDecoder.decode(original.getFirst("redirect_uri"), StandardCharsets.UTF_8);
        String actual = callback.getScheme() + "://" + callback.getHost() + callback.getPath();
        assertTrue(expected.equals(actual), "callback matches the registered request");
        assertTrue("login_required".equals(query.getFirst("error")), "expired cookie cannot restore authentication");
        assertTrue(original.getFirst("state").equals(query.getFirst("state")), "state is preserved");
        assertTrue(!query.containsKey("code"), "no authorization code on failure");
    }

    private static String required(String key) {
        String value = System.getenv(key);
        if (value == null || value.isBlank()) throw new IllegalStateException("Missing staging fixture input: " + key);
        return value;
    }

    private static class SignedExpiredCookie extends HearthRememberMeServices {
        SignedExpiredCookie(String key) {
            super(key, name -> User.withUsername(name).password("").authorities(List.of()).build(), Clock.systemUTC(), true);
        }
        String cookie(String hash) {
            long expiry = System.currentTimeMillis() - 60_000;
            String signature = makeTokenSignature(expiry, "admin", hash, RememberMeTokenAlgorithm.SHA256);
            return encodeCookie(new String[]{"admin", Long.toString(expiry), "SHA256", signature});
        }
    }
}
