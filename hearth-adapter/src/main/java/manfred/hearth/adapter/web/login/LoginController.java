package manfred.hearth.adapter.web.login;

import java.util.List;
import java.net.URI;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import manfred.hearth.adapter.web.security.HearthPrincipal;
import manfred.hearth.adapter.web.security.HearthRememberMeServices;
import manfred.hearth.app.identity.IdentityDirectoryPort;
import manfred.hearth.app.identity.PasswordLoginService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.security.web.savedrequest.RequestCache;
import org.springframework.security.web.savedrequest.SavedRequest;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LoginController {

    private final PasswordLoginService passwordLoginService;
    private final IdentityDirectoryPort identityDirectory;
    private final RequestCache requestCache;
    private final HearthRememberMeServices rememberMeServices;
    private final SecurityContextRepository securityContextRepository = new HttpSessionSecurityContextRepository();

    public LoginController(PasswordLoginService passwordLoginService, IdentityDirectoryPort identityDirectory,
                           RequestCache requestCache, HearthRememberMeServices rememberMeServices) {
        this.passwordLoginService = passwordLoginService;
        this.identityDirectory = identityDirectory;
        this.requestCache = requestCache;
        this.rememberMeServices = rememberMeServices;
    }

    @PostMapping("/api/login")
    public LoginResponse login(@RequestBody LoginRequest request,
                               HttpServletRequest httpRequest, HttpServletResponse httpResponse) {
        PasswordLoginService.AuthenticatedIdentity authenticated = passwordLoginService.authenticate(
                request.login(), request.password());
        var account = identityDirectory.findById(authenticated.userId())
                .orElseThrow(PasswordLoginService.InvalidCredentialsException::new);
        HearthPrincipal principal = new HearthPrincipal(
                account.id(), authenticated.login(), account.displayName(), account.email());
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(principal, null, List.of()));
        securityContextRepository.saveContext(context, httpRequest, httpResponse);
        rememberMeServices.onInteractiveLogin(httpRequest, httpResponse, context.getAuthentication(),
                Boolean.TRUE.equals(request.rememberMe()));
        SavedRequest savedRequest = requestCache.getRequest(httpRequest, httpResponse);
        String redirectTo = savedRequest == null ? null : relativeRedirect(savedRequest.getRedirectUrl(), httpRequest);
        if (savedRequest != null) {
            requestCache.removeRequest(httpRequest, httpResponse);
        }
        return new LoginResponse(true, account.displayName(), redirectTo);
    }

    private String relativeRedirect(String redirectUrl, HttpServletRequest request) {
        URI uri = URI.create(redirectUrl);
        if (!uri.isAbsolute()) {
            return uri.getPath().startsWith("/") && !uri.getPath().startsWith("//")
                    ? uri.getRawPath() + query(uri)
                    : "/";
        }
        boolean sameOrigin = request.getScheme().equalsIgnoreCase(uri.getScheme())
                && request.getServerName().equalsIgnoreCase(uri.getHost())
                && effectivePort(request) == effectivePort(uri);
        return sameOrigin && uri.getRawPath() != null && uri.getRawPath().startsWith("/")
                ? uri.getRawPath() + query(uri)
                : "/";
    }

    private String query(URI uri) {
        return uri.getRawQuery() == null ? "" : "?" + uri.getRawQuery();
    }

    private int effectivePort(HttpServletRequest request) {
        return request.getServerPort() > 0 ? request.getServerPort() : request.getScheme().equalsIgnoreCase("https") ? 443 : 80;
    }

    private int effectivePort(URI uri) {
        return uri.getPort() > 0 ? uri.getPort() : uri.getScheme().equalsIgnoreCase("https") ? 443 : 80;
    }

    @ExceptionHandler(PasswordLoginService.InvalidCredentialsException.class)
    ResponseEntity<LoginErrorResponse> invalidCredentials() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new LoginErrorResponse(false, "登录失败，请检查账号或密码"));
    }

    public record LoginRequest(String login, String password, Boolean rememberMe) {
        public LoginRequest {
            rememberMe = Boolean.TRUE.equals(rememberMe);
        }
    }

    public record LoginResponse(boolean authenticated, String displayName, String redirectTo) {
    }

    public record LoginErrorResponse(boolean authenticated, String message) {
    }
}
