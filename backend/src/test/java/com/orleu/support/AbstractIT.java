package com.orleu.support;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.containers.PostgreSQLContainer;

import java.time.*;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/**
 * Integration tests run against a REAL PostgreSQL (exclusion constraints and triggers cannot be tested on H2).
 * Set ORLEU_TEST_DB_URL / _USER / _PASSWORD to use an existing database; otherwise a Testcontainers
 * postgres:16 instance is started (requires Docker, as in CI).
 */
@SpringBootTest
@AutoConfigureMockMvc
public abstract class AbstractIT {
    private static final String ENV_URL = System.getenv("ORLEU_TEST_DB_URL");
    private static PostgreSQLContainer<?> container;
    private static final AtomicInteger SEQ = new AtomicInteger();
    protected static final ZoneId ALMATY = ZoneId.of("Asia/Almaty");

    @DynamicPropertySource
    static void db(DynamicPropertyRegistry r) {
        if (ENV_URL != null) {
            r.add("spring.datasource.url", () -> ENV_URL);
            r.add("spring.datasource.username", () -> System.getenv().getOrDefault("ORLEU_TEST_DB_USER", "orleu"));
            r.add("spring.datasource.password", () -> System.getenv().getOrDefault("ORLEU_TEST_DB_PASSWORD", "orleu"));
        } else {
            synchronized (AbstractIT.class) {
                if (container == null) {
                    container = new PostgreSQLContainer<>("postgres:16-alpine");
                    container.start();
                }
            }
            r.add("spring.datasource.url", container::getJdbcUrl);
            r.add("spring.datasource.username", container::getUsername);
            r.add("spring.datasource.password", container::getPassword);
        }
        r.add("orleu.security.jwt-secret", () -> "test-secret-test-secret-test-secret-0123456789");
        r.add("orleu.rate-limit.per-minute", () -> "1000000");
        r.add("orleu.jobs.expiry-interval", () -> "PT24H"); // tests call the expiry service directly
        r.add("orleu.messaging.provider", () -> "fake"); // test mode sender; the dispatcher is called directly
        r.add("orleu.jobs.message-interval", () -> "PT24H");
        r.add("orleu.jobs.outbox-interval", () -> "PT24H"); // tests call the outbox processor directly
    }

    @Autowired protected MockMvc mvc;
    @Autowired protected ObjectMapper json;
    @Autowired protected JdbcTemplate jdbc;

    protected String unique(String prefix) { return prefix + System.nanoTime() + SEQ.incrementAndGet(); }

    public record Res(int status, JsonNode body) {
        public String text(String field) { return body.path(field).asText(); }
        public UUID id() { return UUID.fromString(body.path("id").asText()); }
    }

    protected Res call(MockHttpServletRequestBuilder b, String token, Object body, String... headers) {
        try {
            if (token != null) b.header("Authorization", "Bearer " + token);
            for (int i = 0; i + 1 < headers.length; i += 2) b.header(headers[i], headers[i + 1]);
            if (body != null) b.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
            MvcResult r = mvc.perform(b).andReturn();
            String s = r.getResponse().getContentAsString();
            return new Res(r.getResponse().getStatus(), s.isBlank() ? json.nullNode() : json.readTree(s));
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    protected Res get(String token, String path, Object... args) { return call(MockMvcRequestBuilders.get(String.format(path, args)), token, null); }
    protected Res post(String token, String path, Object body, Object... args) { return call(MockMvcRequestBuilders.post(String.format(path, args)), token, body); }
    protected Res put(String token, String path, Object body, Object... args) { return call(MockMvcRequestBuilders.put(String.format(path, args)), token, body); }
    protected Res patch(String token, String path, Object body, Object... args) { return call(MockMvcRequestBuilders.patch(String.format(path, args)), token, body); }

    /** Registers a fresh user and returns the access token. */
    protected String newUser(String emailPrefix) {
        Res r = post(null, "/api/v1/auth/register", java.util.Map.of(
                "email", unique(emailPrefix) + "@example.com", "password", "correct-horse-battery", "fullName", "Test User"));
        if (r.status() != 201) throw new IllegalStateException("register failed: " + r.body());
        return r.text("accessToken");
    }

    protected LocalDate bookingDate() { return LocalDate.now(ALMATY).plusDays(3); }

    protected Instant at(LocalDate d, int hour, int minute) { return ZonedDateTime.of(d, LocalTime.of(hour, minute), ALMATY).toInstant(); }
}
