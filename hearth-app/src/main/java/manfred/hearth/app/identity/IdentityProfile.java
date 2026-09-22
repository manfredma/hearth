package manfred.hearth.app.identity;

public record IdentityProfile(String displayName, String email) {

    public IdentityProfile {
        if (displayName == null || displayName.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }
        if (email != null && email.isBlank()) {
            throw new IllegalArgumentException("email must not be blank when present");
        }
    }
}
