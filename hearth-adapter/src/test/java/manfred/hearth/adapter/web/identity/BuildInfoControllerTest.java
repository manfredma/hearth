package manfred.hearth.adapter.web.identity;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class BuildInfoControllerTest {

    @Test
    void returnsInjectedVersionCommitAndBuildTime() {
        BuildInfoController controller = new BuildInfoController("0.1.0", "a".repeat(40), "2026-09-26T00:00:00Z");

        assertThat(controller.version()).containsEntry("version", "0.1.0")
                .containsEntry("commitId", "a".repeat(40))
                .containsEntry("builtAt", "2026-09-26T00:00:00Z");
    }
}
