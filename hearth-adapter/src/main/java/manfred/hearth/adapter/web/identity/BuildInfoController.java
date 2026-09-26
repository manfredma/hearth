package manfred.hearth.adapter.web.identity;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class BuildInfoController {

    private final String version;
    private final String commitId;
    private final String builtAt;

    public BuildInfoController(@Value("${hearth.build.version:unknown}") String version,
                               @Value("${hearth.build.commit-id:unknown}") String commitId,
                               @Value("${hearth.build.built-at:unknown}") String builtAt) {
        this.version = version;
        this.commitId = commitId;
        this.builtAt = builtAt;
    }

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of("version", version, "commitId", commitId, "builtAt", builtAt);
    }
}
