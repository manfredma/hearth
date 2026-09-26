package manfred.hearth.nativeintegration;

import io.lettuce.core.RedisClient;
import io.lettuce.core.RedisURI;
import io.lettuce.core.api.StatefulRedisConnection;
import org.junit.jupiter.api.Test;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class NativeInfrastructureIT {

    @Test
    void isolatedStagingSlotUsesMigratedMysqlAndRedis() throws Exception {
        String jdbcUrl = requiredEnvironment("HEARTH_DATASOURCE_URL");
        String databaseUser = requiredEnvironment("HEARTH_DATASOURCE_USERNAME");
        String databasePassword = requiredEnvironment("HEARTH_DATASOURCE_PASSWORD");

        try (Connection database = DriverManager.getConnection(jdbcUrl, databaseUser, databasePassword);
             Statement statement = database.createStatement()) {
            try (ResultSet migration = statement.executeQuery(
                    "SELECT COUNT(*) FROM flyway_schema_history WHERE success = TRUE")) {
                assertTrue(migration.next() && migration.getInt(1) > 0,
                        "the isolated MySQL snapshot must contain successful Flyway migrations");
            }
            try (ResultSet admin = statement.executeQuery(
                    "SELECT COUNT(*) FROM identity_credential WHERE login = 'admin' AND enabled = TRUE")) {
                assertTrue(admin.next() && admin.getInt(1) == 1,
                        "the isolated database must retain the existing staging administrator");
            }
            statement.execute("CREATE TEMPORARY TABLE hearth_it_probe (probe_value INT NOT NULL)");
            statement.execute("INSERT INTO hearth_it_probe (probe_value) VALUES (42)");
            try (ResultSet probe = statement.executeQuery("SELECT probe_value FROM hearth_it_probe")) {
                assertTrue(probe.next());
                assertEquals(42, probe.getInt(1));
            }
        }

        String host = requiredEnvironment("HEARTH_REDIS_HOST");
        int port = Integer.parseInt(requiredEnvironment("HEARTH_REDIS_PORT"));
        int database = Integer.parseInt(requiredEnvironment("HEARTH_REDIS_DATABASE"));
        String namespace = requiredEnvironment("HEARTH_SESSION_REDIS_NAMESPACE");
        String password = requiredProperty("hearth.it.redis.password");
        String key = namespace + "integration-probe:" + UUID.randomUUID();
        RedisURI redisUri = RedisURI.Builder.redis(host, port)
                .withPassword(password.toCharArray())
                .withDatabase(database)
                .build();
        RedisClient client = RedisClient.create(redisUri);
        try {
            try (StatefulRedisConnection<String, String> connection = client.connect()) {
                try {
                    assertEquals("OK", connection.sync().set(key, "reachable"));
                    assertEquals("reachable", connection.sync().get(key));
                } finally {
                    connection.sync().del(key);
                }
            }
        } finally {
            client.shutdown();
        }
    }

    private static String requiredEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Required integration environment variable is missing: " + name);
        }
        return value;
    }

    private static String requiredProperty(String name) {
        String value = System.getProperty(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Required integration system property is missing: " + name);
        }
        return value;
    }
}
