package manfred.hearth.domain.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;
import static org.assertj.core.api.Assertions.assertThatNullPointerException;

import org.junit.jupiter.api.Test;

class IdentitySubjectTest {

    @Test
    void preservesIssuerAndSubject() {
        IdentitySubject subject = new IdentitySubject("https://auth.example", "user-123");

        assertThat(subject.issuer()).isEqualTo("https://auth.example");
        assertThat(subject.subject()).isEqualTo("user-123");
    }

    @Test
    void rejectsNullIssuer() {
        assertThatNullPointerException().isThrownBy(() -> new IdentitySubject(null, "user-123"));
    }

    @Test
    void rejectsBlankIssuer() {
        assertThatIllegalArgumentException().isThrownBy(() -> new IdentitySubject(" ", "user-123"));
    }

    @Test
    void rejectsBlankSubject() {
        assertThatIllegalArgumentException().isThrownBy(() -> new IdentitySubject("https://auth.example", " "));
    }
}
