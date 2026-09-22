package manfred.hearth.app.access;

import java.util.Objects;

import manfred.hearth.domain.access.ApplicationAccess;

public final class GrantApplicationAccessCmdExe {

    private final ApplicationAccessPort accessPort;

    public GrantApplicationAccessCmdExe(ApplicationAccessPort accessPort) {
        this.accessPort = Objects.requireNonNull(accessPort, "accessPort");
    }

    public ApplicationAccess execute(GrantApplicationAccessCmd command) {
        Objects.requireNonNull(command, "command");
        return accessPort.grant(command.userId(), command.application(), command.roleKey());
    }
}
