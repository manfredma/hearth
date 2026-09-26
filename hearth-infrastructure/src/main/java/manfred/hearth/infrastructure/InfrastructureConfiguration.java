package manfred.hearth.infrastructure;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class InfrastructureConfiguration {

    @Bean
    Clock systemClock() {
        return Clock.systemUTC();
    }
}
