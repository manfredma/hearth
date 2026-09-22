package manfred.hearth.adapter.web.security;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.domain.identity.IdentityAccount;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.security.web.authentication.SavedRequestAwareAuthenticationSuccessHandler;
import org.springframework.stereotype.Component;

@Component
public class OidcLoginSuccessHandler implements AuthenticationSuccessHandler {

    private final IdentityDirectoryPort identityDirectory;
    private final OidcIdentityMapper identityMapper;
    private final SavedRequestAwareAuthenticationSuccessHandler delegate = new SavedRequestAwareAuthenticationSuccessHandler();

    public OidcLoginSuccessHandler(IdentityDirectoryPort identityDirectory, OidcIdentityMapper identityMapper) {
        this.identityDirectory = identityDirectory;
        this.identityMapper = identityMapper;
    }

    @Override
    public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                        Authentication authentication) throws IOException, ServletException {
        if (!(authentication.getPrincipal() instanceof OidcUser oidcUser)) {
            throw new IllegalStateException("OIDC login requires an OIDC user principal");
        }
        OidcIdentityMapper.MappedIdentity mapped = identityMapper.map(oidcUser);
        IdentityAccount account = identityDirectory.findOrCreate(mapped.subject(), mapped.profile());
        request.getSession().setAttribute("HEARTH_IDENTITY_ID", account.id().toString());
        delegate.onAuthenticationSuccess(request, response, authentication);
    }
}
