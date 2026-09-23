package manfred.hearth;

import org.springframework.context.annotation.Configuration;
import org.springframework.session.data.redis.config.annotation.web.http.EnableRedisHttpSession;

@Configuration(proxyBeanMethods = false)
@EnableRedisHttpSession(
        redisNamespace = "${HEARTH_SESSION_REDIS_NAMESPACE:hearth:session:v1}",
        maxInactiveIntervalInSeconds = 3600)
public class HearthSessionConfiguration {
}
