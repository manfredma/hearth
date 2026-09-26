package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.FactorGrantedAuthority;

class HearthAuthenticationFactorsTest {

    @Test
    void recordsThePasswordAuthenticationTimeForOidcAuthTimeClaims() {
        Instant issuedAt = Instant.parse("2026-09-24T12:00:00Z");

        FactorGrantedAuthority factor = (FactorGrantedAuthority) HearthAuthenticationFactors
                .password(Clock.fixed(issuedAt, ZoneOffset.UTC)).getFirst();

        assertThat(factor.getAuthority()).isEqualTo(FactorGrantedAuthority.PASSWORD_AUTHORITY);
        assertThat(factor.getIssuedAt()).isEqualTo(issuedAt);
    }
}
