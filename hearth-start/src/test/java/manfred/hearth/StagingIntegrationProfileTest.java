package manfred.hearth;

import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

class StagingIntegrationProfileTest {

    @Test
    void stagingIntegrationProfileUnbindsPmdFromMemoryBoundedRunner() throws Exception {
        Path root = Path.of(System.getProperty("user.dir")).toAbsolutePath();
        while (root != null && !(Files.exists(root.resolve(".mvn/wrapper/maven-wrapper.properties"))
                && Files.exists(root.resolve("hearth-start/pom.xml")))) {
            root = root.getParent();
        }
        assertTrue(root != null, "the Maven reactor root must be discoverable from hearth-start tests");
        String pom = Files.readString(root.resolve("pom.xml"));
        int profileStart = pom.indexOf("<id>staging-integration</id>");
        int profileEnd = pom.indexOf("</profile>", profileStart);
        assertTrue(profileStart >= 0 && profileEnd > profileStart,
                "the staging-integration Maven profile must exist");

        String profile = pom.substring(profileStart, profileEnd);
        int pmdStart = profile.indexOf("<artifactId>maven-pmd-plugin</artifactId>");
        int pmdEnd = profile.indexOf("</plugin>", pmdStart);
        assertTrue(pmdStart >= 0 && pmdEnd > pmdStart,
                "staging integration must define its PMD resource policy");
        String pmdPlugin = profile.substring(pmdStart, pmdEnd);
        assertTrue(pmdPlugin.contains("<id>pmd-check</id>"),
                "the inherited PMD lifecycle execution must be explicitly disabled for staging integration");
        assertTrue(pmdPlugin.contains("<phase>none</phase>"),
                "staging integration has a 512 MiB cgroup; unbind PMD instead of loading it and merely skipping the goal");
    }
}
