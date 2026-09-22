package manfred.hearth.app.access;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import manfred.hearth.domain.access.ApplicationAccess;
import manfred.hearth.domain.application.ApplicationKey;

class GrantApplicationAccessCmdExeTest {

    @Test
    void grantsNamespacedApplicationRole() {
        InMemoryApplicationAccessPort port = new InMemoryApplicationAccessPort();
        UUID userId = UUID.randomUUID();
        GrantApplicationAccessCmdExe executor = new GrantApplicationAccessCmdExe(port);

        ApplicationAccess access = executor.execute(new GrantApplicationAccessCmd(
                userId, new ApplicationKey("release"), "release:operator"));

        assertThat(access.userId()).isEqualTo(userId);
        assertThat(port.hasAccess(userId, new ApplicationKey("release"))).isTrue();
    }

    @Test
    void rejectsUnnamespacedRole() {
        InMemoryApplicationAccessPort port = new InMemoryApplicationAccessPort();
        GrantApplicationAccessCmdExe executor = new GrantApplicationAccessCmdExe(port);

        assertThatIllegalArgumentException().isThrownBy(() -> executor.execute(new GrantApplicationAccessCmd(
                UUID.randomUUID(), new ApplicationKey("release"), "operator")));
    }

    @Test
    void duplicateGrantIsIdempotent() {
        InMemoryApplicationAccessPort port = new InMemoryApplicationAccessPort();
        UUID userId = UUID.randomUUID();
        GrantApplicationAccessCmd command = new GrantApplicationAccessCmd(
                userId, new ApplicationKey("toolbox"), "toolbox:user");
        GrantApplicationAccessCmdExe executor = new GrantApplicationAccessCmdExe(port);

        ApplicationAccess first = executor.execute(command);
        ApplicationAccess second = executor.execute(command);

        assertThat(second).isEqualTo(first);
        assertThat(port.grants).hasSize(1);
    }

    private static final class InMemoryApplicationAccessPort implements ApplicationAccessPort {

        private final Set<ApplicationAccess> grants = new HashSet<>();

        @Override
        public ApplicationAccess grant(UUID userId, ApplicationKey application, String roleKey) {
            ApplicationAccess access = new ApplicationAccess(userId, application, roleKey);
            grants.add(access);
            return access;
        }

        @Override
        public boolean hasAccess(UUID userId, ApplicationKey application) {
            return grants.stream().anyMatch(access -> access.userId().equals(userId)
                    && access.application().equals(application));
        }
    }
}
