package manfred.hearth.adapter.web.security;

import manfred.hearth.app.identity.CurrentIdentity;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.domain.identity.IdentityAccount;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

@Component
public class CurrentIdentityArgumentResolver implements HandlerMethodArgumentResolver {

    private final IdentityDirectoryPort identityDirectory;
    private final OidcIdentityMapper identityMapper;

    public CurrentIdentityArgumentResolver(IdentityDirectoryPort identityDirectory, OidcIdentityMapper identityMapper) {
        this.identityDirectory = identityDirectory;
        this.identityMapper = identityMapper;
    }

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return CurrentIdentity.class.equals(parameter.getParameterType());
    }

    @Override
    public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer,
                                  NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
        Authentication authentication = (Authentication) webRequest.getUserPrincipal();
        if (authentication == null || !(authentication.getPrincipal() instanceof OidcUser oidcUser)) {
            throw new IllegalStateException("Current identity requires an OIDC-authenticated principal");
        }
        OidcIdentityMapper.MappedIdentity mapped = identityMapper.map(oidcUser);
        IdentityAccount account = identityDirectory.findOrCreate(mapped.subject(), mapped.profile());
        return new CurrentIdentity(account.id(), account.displayName());
    }
}
