package manfred.hearth.adapter.web.login;

import manfred.hearth.adapter.web.identity.HealthController;
import org.junit.jupiter.api.Test;
import org.springframework.security.web.csrf.DefaultCsrfToken;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class PublicEndpointTest {
    @Test
    void servesHealthAndSpaAndTheSuppliedCsrfToken() throws Exception {
        var mvc = MockMvcBuilders.standaloneSetup(new LoginPageController(), new HealthController()).build();
        mvc.perform(get("/login")).andExpect(forwardedUrl("/index.html"));
        var response = mvc.perform(get("/api/health")).andExpect(status().isOk()).andReturn().getResponse();
        assertThat(response.getContentAsString()).contains("\"service\":\"hearth\"", "\"status\":\"ok\"");
        assertThat(new CsrfController().token(new DefaultCsrfToken("X-CSRF-TOKEN", "_csrf", "token")).token()).isEqualTo("token");
    }
}
