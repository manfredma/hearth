package manfred.hearth;

import org.junit.jupiter.api.Test;
import org.springframework.session.data.redis.config.annotation.web.http.EnableRedisHttpSession;

import static org.assertj.core.api.Assertions.assertThat;

class HearthSessionConfigurationTest {

    @Test
    void enablesRedisBackedServerSessionsWithAnIsolatedNamespace() {
        EnableRedisHttpSession session = HearthSessionConfiguration.class
                .getAnnotation(EnableRedisHttpSession.class);

        assertThat(session).isNotNull();
        assertThat(session.redisNamespace()).isEqualTo("${HEARTH_SESSION_REDIS_NAMESPACE:hearth:session:v1}");
        assertThat(session.maxInactiveIntervalInSeconds()).isEqualTo(3600);
    }
}
