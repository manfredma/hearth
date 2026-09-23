package manfred.hearth.adapter.web.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.UUID;

import org.junit.jupiter.api.Test;

class HearthPrincipalTest {

    @Test
    void roundTripsThroughJavaSerializationForRedisHttpSession() throws Exception {
        HearthPrincipal principal = new HearthPrincipal(
                UUID.randomUUID(), "admin", "管理员", "admin@example.com");

        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ObjectOutputStream output = new ObjectOutputStream(bytes)) {
            output.writeObject(principal);
        }

        HearthPrincipal restored;
        try (ObjectInputStream input = new ObjectInputStream(new ByteArrayInputStream(bytes.toByteArray()))) {
            restored = (HearthPrincipal) input.readObject();
        }

        assertThat(restored).isEqualTo(principal);
    }
}
