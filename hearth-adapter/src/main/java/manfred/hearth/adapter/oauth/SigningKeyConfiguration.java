package manfred.hearth.adapter.oauth;

import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.interfaces.RSAPrivateCrtKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.RSAPublicKeySpec;
import java.util.Base64;

import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.proc.SecurityContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class SigningKeyConfiguration {

    @Bean
    JWKSource<SecurityContext> jwkSource(
            @Value("${HEARTH_SIGNING_KEY:}") String encodedPrivateKey,
            @Value("${hearth.environment:local}") String environment) {
        RSAKey signingKey = encodedPrivateKey.isBlank()
                ? localDevelopmentKey(environment)
                : parsePrivateKey(encodedPrivateKey);
        JWKSet keySet = new JWKSet(signingKey);
        return (selector, context) -> selector.select(keySet);
    }

    private RSAKey localDevelopmentKey(String environment) {
        if (!"local".equalsIgnoreCase(environment) && !"test".equalsIgnoreCase(environment)) {
            throw new IllegalStateException("HEARTH_SIGNING_KEY is required outside local/test environments");
        }
        try {
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(2048);
            return rsaKey(generator.generateKeyPair());
        } catch (Exception exception) {
            throw new IllegalStateException("unable to create local development signing key", exception);
        }
    }

    private RSAKey parsePrivateKey(String encodedPrivateKey) {
        try {
            byte[] der = Base64.getDecoder().decode(encodedPrivateKey.replaceAll("\\s", ""));
            PrivateKey privateKey = KeyFactory.getInstance("RSA")
                    .generatePrivate(new PKCS8EncodedKeySpec(der));
            if (!(privateKey instanceof RSAPrivateCrtKey rsaPrivateKey)) {
                throw new IllegalArgumentException("HEARTH_SIGNING_KEY must contain an RSA private key");
            }
            RSAPublicKey publicKey = (RSAPublicKey) KeyFactory.getInstance("RSA")
                    .generatePublic(new RSAPublicKeySpec(rsaPrivateKey.getModulus(), rsaPrivateKey.getPublicExponent()));
            return rsaKey(publicKey, privateKey);
        } catch (Exception exception) {
            throw new IllegalStateException("HEARTH_SIGNING_KEY must be base64 PKCS#8 RSA private-key DER", exception);
        }
    }

    private RSAKey rsaKey(KeyPair keyPair) {
        return rsaKey((RSAPublicKey) keyPair.getPublic(), keyPair.getPrivate());
    }

    private RSAKey rsaKey(RSAPublicKey publicKey, PrivateKey privateKey) {
        return new RSAKey.Builder(publicKey)
                .privateKey(privateKey)
                .keyID(keyId(publicKey))
                .build();
    }

    private String keyId(RSAPublicKey publicKey) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(publicKey.getEncoded());
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (Exception exception) {
            throw new IllegalStateException("unable to derive signing key id", exception);
        }
    }
}
