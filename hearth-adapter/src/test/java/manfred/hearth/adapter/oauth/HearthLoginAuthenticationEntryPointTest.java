package manfred.hearth.adapter.oauth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import jakarta.servlet.ServletException;
import java.io.IOException;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.AuthenticationException;

class HearthLoginAuthenticationEntryPointTest {

    @Test
    void preservesTheOriginalAuthorizationRequestAsTheLoginContinueTarget()
            throws IOException, ServletException {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/oauth2/authorize");
        request.setQueryString("response_type=code&client_id=career-staging&state=state-value");
        MockHttpServletResponse response = new MockHttpServletResponse();

        new HearthLoginAuthenticationEntryPoint().commence(
                request, response, mock(AuthenticationException.class));

        assertThat(response.getRedirectedUrl())
                .isEqualTo("/login?continue=%2Foauth2%2Fauthorize%3Fresponse_type%3Dcode%26client_id%3Dcareer-staging%26state%3Dstate-value");
    }
}
