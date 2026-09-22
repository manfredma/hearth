package manfred.hearth.domain.identity;

import java.util.Objects;

public record IdentitySubject(String issuer, String subject) {

    public IdentitySubject {
        issuer = requireText(issuer, "issuer");
        subject = requireText(subject, "subject");
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        if (value.isBlank()) {
            throw new IllegalArgumentException(field + " must not be blank");
        }
        return value;
    }
}
