package manfred.hearth.adapter.web.login;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.forwardedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ConsentPreviewPageControllerTest {

    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new ConsentPreviewPageController()).build();

    @Test
    void forwardsTheConsentPreviewRouteToTheSpaShell() throws Exception {
        mvc.perform(get("/consent-preview"))
                .andExpect(status().isOk())
                .andExpect(forwardedUrl("/index.html"));
    }

    @Test
    void forwardsTheRealOAuthConsentRouteToTheSpaShell() throws Exception {
        mvc.perform(get("/oauth2/consent").queryParam("client_id", "career-staging"))
                .andExpect(status().isOk())
                .andExpect(forwardedUrl("/index.html"));
    }
}
