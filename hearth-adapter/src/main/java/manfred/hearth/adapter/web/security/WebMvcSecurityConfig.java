package manfred.hearth.adapter.web.security;

import java.util.List;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcSecurityConfig implements WebMvcConfigurer {

    private final CurrentIdentityArgumentResolver currentIdentityArgumentResolver;

    public WebMvcSecurityConfig(CurrentIdentityArgumentResolver currentIdentityArgumentResolver) {
        this.currentIdentityArgumentResolver = currentIdentityArgumentResolver;
    }

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(currentIdentityArgumentResolver);
    }
}
