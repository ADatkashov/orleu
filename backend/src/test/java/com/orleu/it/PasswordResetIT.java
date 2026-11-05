package com.orleu.it;

import com.orleu.auth.PasswordResetMailer;
import com.orleu.support.AbstractIT;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

@Import(PasswordResetIT.Capture.class)
class PasswordResetIT extends AbstractIT {
    static final Map<String, String> SENT = new ConcurrentHashMap<>();
    static final AtomicInteger SENT_COUNT = new AtomicInteger();

    @TestConfiguration
    static class Capture {
        @Bean @Primary PasswordResetMailer capturingMailer() {
            return (email, token) -> { SENT.put(email.toLowerCase(), token); SENT_COUNT.incrementAndGet(); };
        }
    }

    private static final String PW = "correct-horse-battery";

    private String register(String prefix) {
        String email = unique(prefix) + "@example.com";
        assertEquals(201, post(null, "/api/v1/auth/register", Map.of("email", email, "password", PW, "fullName", "Reset Me")).status());
        return email;
    }

    private Res login(String email, String pw) { return post(null, "/api/v1/auth/login", Map.of("email", email, "password", pw)); }

    @Test void fullResetFlowChangesPasswordAndEndsAllSessions() {
        String email = register("rst");
        Res session = login(email, PW);
        assertEquals(200, session.status());

        assertEquals(202, post(null, "/api/v1/auth/password-reset/request", Map.of("email", email)).status());
        String token = SENT.get(email.toLowerCase());
        assertNotNull(token);
        assertEquals(204, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", token, "newPassword", "brand-new-secret-1")).status());

        assertEquals(401, login(email, PW).status());                              // old password is dead
        assertEquals(200, login(email, "brand-new-secret-1").status());            // new one works
        assertEquals(401, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", session.text("refreshToken"))).status()); // old sessions revoked
    }

    @Test void tokenIsSingleUseAndStoredOnlyHashed() {
        String email = register("one");
        post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        String token = SENT.get(email.toLowerCase());
        assertEquals(0, jdbc.queryForObject("select count(*) from password_reset_tokens where token_hash = ?", Integer.class, token));
        assertEquals(204, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", token, "newPassword", "another-secret-22")).status());
        Res again = post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", token, "newPassword", "third-secret-333"));
        assertEquals(400, again.status());
        assertEquals("INVALID_RESET_TOKEN", again.text("code"));
        assertEquals(200, login(email, "another-secret-22").status());
    }

    @Test void newRequestInvalidatesEarlierTokenAfterUse() {
        String email = register("two");
        post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        String first = SENT.get(email.toLowerCase());
        post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        String second = SENT.get(email.toLowerCase());
        assertNotEquals(first, second);
        assertEquals(204, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", second, "newPassword", "fresh-secret-4444")).status());
        assertEquals(400, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", first, "newPassword", "other-secret-55555")).status()); // siblings die with the used one
    }

    @Test void expiredOrGarbageTokensAreRejected() {
        String email = register("exp");
        post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        String token = SENT.get(email.toLowerCase());
        jdbc.update("update password_reset_tokens set expires_at = now() - interval '1 minute' where user_id = (select id from users where lower(email) = lower(?))", email);
        assertEquals(400, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", token, "newPassword", "late-secret-666666")).status());
        assertEquals(400, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", "x".repeat(43), "newPassword", "late-secret-666666")).status());
        assertEquals(200, login(email, PW).status()); // nothing changed
    }

    @Test void requestNeverRevealsWhetherAnAccountExists() {
        String email = register("known");
        int before = SENT_COUNT.get();
        Res known = post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        Res unknown = post(null, "/api/v1/auth/password-reset/request", Map.of("email", "nobody" + System.nanoTime() + "@example.com"));
        assertEquals(202, known.status());
        assertEquals(202, unknown.status());
        assertEquals(known.body(), unknown.body());
        assertEquals(before + 1, SENT_COUNT.get(), "only the real account gets a message");
    }

    @Test void weakNewPasswordIsRejectedAndTokenStaysUsable() {
        String email = register("weak");
        post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        String token = SENT.get(email.toLowerCase());
        assertEquals(400, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", token, "newPassword", "short")).status());
        assertEquals(204, post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", token, "newPassword", "long-enough-secret-7")).status());
    }

    @Test void resetClearsAccountLockout() {
        String email = register("lock");
        for (int i = 0; i < 5; i++) login(email, "bad-bad-bad-bad");
        assertEquals(429, login(email, PW).status());
        post(null, "/api/v1/auth/password-reset/request", Map.of("email", email));
        post(null, "/api/v1/auth/password-reset/confirm", Map.of("token", SENT.get(email.toLowerCase()), "newPassword", "unlocked-secret-8"));
        assertEquals(200, login(email, "unlocked-secret-8").status());
    }

    @Test void changePasswordRequiresCurrentPasswordAndSignsOutOtherDevices() {
        String email = register("chg");
        Res phone = login(email, PW), laptop = login(email, PW);
        String access = laptop.text("accessToken");
        assertEquals(400, post(access, "/api/v1/auth/change-password", Map.of("currentPassword", "wrong-wrong-wrong", "newPassword", "changed-secret-99")).status());
        Res changed = post(access, "/api/v1/auth/change-password", Map.of("currentPassword", PW, "newPassword", "changed-secret-99"));
        assertEquals(200, changed.status());
        // Regression: a stale device replaying its (password-change-revoked) token is rejected but must NOT be treated as theft,
        // otherwise it would also kill the session the user just continued on.
        assertEquals(401, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", phone.text("refreshToken"))).status());   // other device signed out
        assertEquals(200, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", changed.text("refreshToken"))).status()); // this device keeps working
        assertEquals(401, post(null, "/api/v1/auth/change-password", Map.of("currentPassword", PW, "newPassword", "x".repeat(12))).status()); // needs auth
    }

    @Test void sessionsCanBeListedAndRevokedOnlyByTheirOwner() {
        String a = register("sa"), b = register("sb");
        Res a1 = login(a, PW), a2 = login(a, PW), b1 = login(b, PW);
        Res list = get(a1.text("accessToken"), "/api/v1/auth/sessions");
        assertEquals(200, list.status());
        assertEquals(3, list.body().size()); // register + two logins
        String sid = list.body().get(0).path("id").asText();
        // another user cannot see or revoke it
        assertEquals(404, call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/api/v1/auth/sessions/" + sid), b1.text("accessToken"), null).status());
        assertEquals(3, get(a1.text("accessToken"), "/api/v1/auth/sessions").body().size());
        for (var s : list.body()) assertFalse(get(b1.text("accessToken"), "/api/v1/auth/sessions").body().toString().contains(s.path("id").asText()));
        // the owner can
        assertEquals(204, call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/api/v1/auth/sessions/" + sid), a1.text("accessToken"), null).status());
        assertEquals(2, get(a1.text("accessToken"), "/api/v1/auth/sessions").body().size());
        assertEquals(401, get(null, "/api/v1/auth/sessions").status());
    }
}
