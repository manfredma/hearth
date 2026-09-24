package manfred.hearth.adapter.web.security;

import manfred.hearth.app.identity.CurrentIdentity;
import manfred.hearth.app.identity.IdentityCredentialPort;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.domain.identity.IdentityAccount;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

@Component
public class CurrentIdentityArgumentResolver implements HandlerMethodArgumentResolver {

    private final IdentityDirectoryPort identityDirectory;
    private final IdentityCredentialPort identityCredentials;
    private final OidcIdentityMapper identityMapper;

    public CurrentIdentityArgumentResolver(IdentityDirectoryPort identityDirectory,
                                           IdentityCredentialPort identityCredentials,
                                           OidcIdentityMapper identityMapper) {
        this.identityDirectory = identityDirectory;
        this.identityCredentials = identityCredentials;
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
        if (authentication == null) {
            throw new IllegalStateException("Current identity requires an OIDC-authenticated principal");
        }
        if (authentication.getPrincipal() instanceof HearthPrincipal hearthPrincipal) {
            return new CurrentIdentity(hearthPrincipal.userId(), hearthPrincipal.username(), hearthPrincipal.displayName());
        }
        if (authentication.getPrincipal() instanceof UserDetails userDetails) {
            // The persisted Spring User intentionally contains only the login.
            // Never put display names or email addresses into the serialized
            // security principal; resolve the current profile from MySQL so
            // profile changes take effect without re-issuing a session.
            var account = identityCredentials.findByLogin(userDetails.getUsername())
                    .flatMap(credential -> identityDirectory.findById(credential.userId()))
                    .orElseThrow(() -> new IllegalStateException("Current identity account was not found"));
            return new CurrentIdentity(account.id(), userDetails.getUsername(), account.displayName());
        }
        if (!(authentication.getPrincipal() instanceof OidcUser oidcUser)) {
            throw new IllegalStateException("Current identity requires an authenticated Hearth principal");
        }
        OidcIdentityMapper.MappedIdentity mapped = identityMapper.map(oidcUser);
        IdentityAccount account = identityDirectory.findOrCreate(mapped.subject(), mapped.profile());
        return new CurrentIdentity(account.id(), account.subject().subject(), account.displayName());
    }
}
