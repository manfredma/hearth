package manfred.hearth.adapter.web.login;

import java.util.Set;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.ClientAuthenticationMethod;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClient;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClientRepository;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ConsentClientMetadataControllerTest {
    private final RegisteredClientRepository clients = mock(RegisteredClientRepository.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new ConsentClientMetadataController(clients)).build();

    @Test
    void returnsRegisteredNameAndAllCallbackOriginsWithoutSecret() throws Exception {
        when(clients.findByClientId("career-staging")).thenReturn(client("Career Workspace", Set.of(
                "https://career.example.test/login/oauth2/code/hearth",
                "https://career.example.test/other-callback")));

        String body = mvc.perform(get("/api/consent-client").queryParam("client_id", "career-staging"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat(body).contains("\"clientName\":\"Career Workspace\"")
                .contains("\"callbackOrigins\":[\"https://career.example.test\"]")
                .doesNotContain("never-expose", "clientSecret");
    }

    @Test
    void unknownOrMissingClientFailsClosed() throws Exception {
        mvc.perform(get("/api/consent-client").queryParam("client_id", "unknown"))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/consent-client"))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/consent-client").queryParam("client_id", " "))
                .andExpect(status().isNotFound());
    }

    @Test
    void incompleteOrUnsafeRegisteredMetadataFailsClosed() throws Exception {
        RegisteredClient missingUri = mock(RegisteredClient.class);
        RegisteredClient missingName = mock(RegisteredClient.class);
        when(missingName.getClientName()).thenReturn(" ");
        when(missingName.getRedirectUris()).thenReturn(Set.of("https://career.example.test/callback"));
        when(missingUri.getClientName()).thenReturn("Career");
        when(missingUri.getRedirectUris()).thenReturn(Set.of());
        when(clients.findByClientId("missing-name")).thenReturn(missingName);
        when(clients.findByClientId("null-name")).thenReturn(mock(RegisteredClient.class));
        when(clients.findByClientId("missing-uri")).thenReturn(missingUri);
        when(clients.findByClientId("unsafe-uri")).thenReturn(client("Career", Set.of("http://career.example.test/callback")));
        when(clients.findByClientId("missing-host")).thenReturn(client("Career", Set.of("https:///callback")));
        when(clients.findByClientId("userinfo-uri")).thenReturn(client("Career", Set.of("https://user@career.example.test/callback")));
        for (String clientId : Set.of("missing-name", "null-name", "missing-uri", "unsafe-uri",
                "missing-host", "userinfo-uri")) {
            mvc.perform(get("/api/consent-client").queryParam("client_id", clientId))
                    .andExpect(status().isNotFound());
        }
    }

    @Test
    void retainsRegisteredHttpsCallbackPort() throws Exception {
        when(clients.findByClientId("local")).thenReturn(client("Local Career", Set.of("https://career.example.test:8443/callback")));

        String body = mvc.perform(get("/api/consent-client").queryParam("client_id", "local"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertThat(body).contains("https://career.example.test:8443");
    }

    @Test
    void refusesFrameworkFallbackNameWhenNoClientNameWasRegistered() throws Exception {
        when(clients.findByClientId("unnamed")).thenReturn(client(" ", Set.of("https://career.example.test/callback")));

        mvc.perform(get("/api/consent-client").queryParam("client_id", "unnamed"))
                .andExpect(status().isNotFound());
    }

    private RegisteredClient client(String name, Set<String> redirectUris) {
        return RegisteredClient.withId("id").clientId("career-staging").clientName(name)
                .clientSecret("never-expose")
                .clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
                .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
                .redirectUris(uris -> uris.addAll(redirectUris))
                .scope("openid").build();
    }
}
