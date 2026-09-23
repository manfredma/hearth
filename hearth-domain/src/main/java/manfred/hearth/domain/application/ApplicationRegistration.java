package manfred.hearth.domain.application;

import java.net.URI;
import java.util.LinkedHashSet;
import java.util.Objects;
import java.util.Set;

public record ApplicationRegistration(ApplicationKey key, String displayName, Set<String> redirectUris) {

    public ApplicationRegistration {
        Objects.requireNonNull(key, "key");
        displayName = requireDisplayName(displayName);
        redirectUris = copyAndValidateRedirectUris(redirectUris);
    }

    private static String requireDisplayName(String value) {
        Objects.requireNonNull(value, "displayName");
        if (value.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }
        return value;
    }

    private static Set<String> copyAndValidateRedirectUris(Set<String> values) {
        Objects.requireNonNull(values, "redirectUris");
        if (values.isEmpty()) {
            throw new IllegalArgumentException("redirectUris must not be empty");
        }
        Set<String> copy = new LinkedHashSet<>();
        for (String value : values) {
            validateRedirectUri(value);
            copy.add(value);
        }
        return Set.copyOf(copy);
    }

    private static void validateRedirectUri(String value) {
        Objects.requireNonNull(value, "redirectUri");
        URI uri;
        try {
            uri = URI.create(value);
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException("redirect URI must be valid", exception);
        }
        boolean localDevelopment = "http".equalsIgnoreCase(uri.getScheme())
                && "localhost".equalsIgnoreCase(uri.getHost());
        boolean secure = "https".equalsIgnoreCase(uri.getScheme());
        if (!secure && !localDevelopment) {
            throw new IllegalArgumentException("redirect URI must use HTTPS outside localhost");
        }
        if (uri.getFragment() != null) {
            throw new IllegalArgumentException("redirect URI must not contain a fragment");
        }
    }
}
