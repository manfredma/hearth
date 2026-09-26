package manfred.hearth;

import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

class StagingIntegrationProfileTest {

    @Test
    void stagingIntegrationProfileUnbindsPmdFromMemoryBoundedRunner() throws Exception {
        String profile = stagingIntegrationProfile();
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

    @Test
    void stagingIntegrationProfileForksCompilerToReleaseMavenMemory() throws Exception {
        String profile = stagingIntegrationProfile();
        int compilerStart = profile.indexOf("<artifactId>maven-compiler-plugin</artifactId>");
        int compilerEnd = profile.indexOf("</plugin>", compilerStart);
        assertTrue(compilerStart >= 0 && compilerEnd > compilerStart,
                "staging integration must define its compiler memory policy");
        String compilerPlugin = profile.substring(compilerStart, compilerEnd);
        assertTrue(compilerPlugin.contains("<fork>true</fork>")
                        && compilerPlugin.contains("<maxmem>128m</maxmem>"),
                "in-process javac memory remains resident in Maven when Failsafe starts; fork javac with a bounded heap");
        assertTrue(compilerPlugin.contains("<executable>javac</executable>"),
                "resolve javac explicitly from the controlled Java 25 PATH instead of emitting compiler autodetection warnings");
    }

    private String stagingIntegrationProfile() throws Exception {
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
        return pom.substring(profileStart, profileEnd);
    }
}
