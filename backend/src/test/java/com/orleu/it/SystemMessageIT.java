package com.orleu.it;

import com.orleu.notifications.MessageDispatcher;
import com.orleu.auth.SystemMessageTemplates;
import com.orleu.support.AbstractIT;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;

class SystemMessageIT extends AbstractIT {
    @Autowired MessageDispatcher dispatcher;

    private static final String PW = "correct-horse-battery";

    private String register(String prefix) {
        String email = unique(prefix) + "@example.com";
        assertEquals(201, post(null, "/api/v1/auth/register", Map.of("email", email, "password", PW, "fullName", "Mail Me")).status());
        return email;
    }

    private Map<String, Object> message(String email) {
        return jdbc.queryForMap("select id, channel, subject, body, status, attempts, purpose from system_messages where recipient = ? order by created_at desc limit 1", email);
    }

    private static String tokenIn(String body) {
        Matcher m = Pattern.compile("([A-Za-z0-9_-]{40,})").matcher(body);
        assertTrue(m.find(), body);
        return m.group(1);
    }

    @Test void aResetRequestQueuesAnEmailThatCarriesAWorkingTokenAndTheBodyIsWipedWhenSent() {
        String email = register("sysm");
        assertEquals(202, post(null, "/api/v1/auth/password-reset/request", Map.of("email", email)).status());
        var m = message(email);
        assertEquals("EMAIL", m.get("channel"));
        assertEquals("PASSWORD_RESET", m.get("purpose"));
        assertEquals("NOT_SENT", m.get("status"));
        String body = (String) m.get("body");
        assertEquals("Сброс пароля ORLEU", m.get("subject"), "the default user language is Russian");
        String token = tokenIn(body);

        dispatcher.dispatchSystemDue(1000);
        var after = message(email);
        assertEquals("SENT", after.get("status"));
        assertNull(after.get("body"), "the secret is gone once delivered");
        assertEquals(1, after.get("attempts"));

        // the token that was in the message really resets the password
        assertEquals(204, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", token, "newPassword", "brand-new-secret-1")).status());
        assertEquals(200, post(null, "/api/v1/auth/login", Map.of("email", email, "password", "brand-new-secret-1")).status());
    }

    @Test void unknownAddressesQueueNothingAndTheAnswerIsTheSame() {
        String email = unique("ghost") + "@example.com";
        assertEquals(202, post(null, "/api/v1/auth/password-reset/request", Map.of("email", email)).status());
        assertEquals(0, jdbc.queryForObject("select count(*) from system_messages where recipient = ?", Integer.class, email));
    }

    @Test void anExpiredMessageIsNeverSentAndLosesItsBody() {
        String email = register("expd");
        post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        UUID id = (UUID) message(email).get("id");
        jdbc.update("update system_messages set expires_at = now() - interval '1 minute' where id = ?", id);
        dispatcher.dispatchSystemDue(1000);
        var m = message(email);
        assertEquals("FAILED", m.get("status"));
        assertNull(m.get("body"));
        assertEquals("expired", jdbc.queryForObject("select last_error from system_messages where id = ?", String.class, id));
        assertEquals(0, (int) m.get("attempts"), "no send was attempted");
    }

    @Test void aFailingAddressIsRetriedWithBackoffAndWipedWhenItGivesUp() {
        String rcpt = unique("flaky") + "@example.com0001"; // the fake sender fails transiently for recipients ending in 0001
        jdbc.update("insert into system_messages (channel, recipient, subject, body, purpose, expires_at) values ('EMAIL', ?, 's', 'secret', 'TEST', now() + interval '1 hour')", rcpt);
        UUID id = jdbc.queryForObject("select id from system_messages where recipient = ?", UUID.class, rcpt);
        for (int a = 1; a <= 3; a++) {
            dispatcher.dispatchSystemDue(1000);
            assertEquals("NOT_SENT", jdbc.queryForObject("select status from system_messages where id = ?", String.class, id));
            assertNotNull(jdbc.queryForObject("select body from system_messages where id = ?", String.class, id), "the body is kept while it may still be sent");
            jdbc.update("update system_messages set next_attempt_at = now() - interval '1 second' where id = ?", id);
        }
        dispatcher.dispatchSystemDue(1000);
        assertEquals("FAILED", jdbc.queryForObject("select status from system_messages where id = ?", String.class, id));
        assertNull(jdbc.queryForObject("select body from system_messages where id = ?", String.class, id));
        assertEquals(4, jdbc.queryForObject("select attempts from system_messages where id = ?", Integer.class, id));
    }

    @Test void resetEmailsAreLocalizedAndTheLogMailerIsRefusedInProd() {
        for (String l : new String[]{"kk", "ru", "en"}) {
            var r = SystemMessageTemplates.passwordReset(l, "TOKEN123", "https://app.example.kz/", 30);
            assertTrue(r.body().contains("TOKEN123") && r.body().contains("30"), l);
            assertTrue(r.body().contains("https://app.example.kz/reset?token=TOKEN123"), l + " link");
            assertFalse(r.subject().isBlank());
        }
        assertNotEquals(SystemMessageTemplates.passwordReset("en", "T", "", 30).subject(), SystemMessageTemplates.passwordReset("kk", "T", "", 30).subject());
        assertFalse(SystemMessageTemplates.passwordReset("en", "T", "", 30).body().contains("/reset?token"), "no link without a configured web app");
        assertEquals(SystemMessageTemplates.passwordReset("ru", "T", "", 30), SystemMessageTemplates.passwordReset("fr", "T", "", 30), "unknown language falls back to Russian");

        var cfg = new com.orleu.auth.PasswordResetMailers();
        var prod = new org.springframework.mock.env.MockEnvironment();
        prod.setActiveProfiles("prod");
        assertThrows(IllegalStateException.class, () -> cfg.passwordResetMailer(prod, null, null, "log", ""), "the log mailer prints tokens: never in prod");
    }
}
