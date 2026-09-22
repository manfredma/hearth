package manfred.hearth.domain.application;

import java.util.Objects;
import java.util.regex.Pattern;

public record ApplicationKey(String value) {

    private static final Pattern FORMAT = Pattern.compile("[a-z0-9]+(?:-[a-z0-9]+)*");

    public ApplicationKey {
        Objects.requireNonNull(value, "value");
        if (!FORMAT.matcher(value).matches()) {
            throw new IllegalArgumentException("application key must use lowercase kebab-case");
        }
    }
}
