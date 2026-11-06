package com.orleu.auth;

import com.orleu.support.AbstractIT;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class LoginHistoryIT extends AbstractIT {
    private static final String PASSWORD = "correct-horse-battery";
    @Autowired LoginHistoryService history;

    private record Account(String email, String token, UUID id) {}

    private Account account() {
        String t = newUser("hist");
        Res me = get(t, "/api/v1/me");
        return new Account(me.text("email"), t, UUID.fromString(me.text("id")));
    }

    private Res login(Account a, String password, String userAgent) {
        return call(MockMvcRequestBuilders.post("/api/v1/auth/login"), null, Map.of("email", a.email(), "password", password), "User-Agent", userAgent);
    }

    private Res hist(Account a) { return get(a.token(), "/api/v1/auth/login-history"); }

    @Test void successesAndFailuresAreRecordedNewestFirstWithTheFailureCountSinceTheLastSuccess() {
        Account a = account();
        assertEquals(200, login(a, PASSWORD, "Orleu/1.0 (Android 14)").status());
        assertEquals(401, login(a, "wrong-password-1", "Evil/9").status());
        assertEquals(401, login(a, "wrong-password-2", "Evil/9").status());
        Res h = hist(a);
        assertEquals(200, h.status());
        assertEquals(3, h.body().path("events").size());
        assertEquals("FAILED_PASSWORD", h.body().path("events").get(0).path("outcome").asText());
        assertEquals("SUCCESS", h.body().path("events").get(2).path("outcome").asText());
        assertEquals(2, h.body().path("failedSinceLastSuccess").asInt());
        assertNotNull(h.body().path("events").get(0).path("ip").asText());
        assertEquals(200, login(a, PASSWORD, "Orleu/1.0 (Android 14)").status());
        assertEquals(0, hist(a).body().path("failedSinceLastSuccess").asInt(), "a success resets the counter");
    }

    @Test void aNewDeviceIsFlaggedButTheFirstSignInAndVersionBumpsAreNot() {
        Account a = account();
        login(a, PASSWORD, "Mozilla/5.0 (Windows NT 10.0) Chrome/120.0.1");
        assertFalse(hist(a).body().path("events").get(0).path("newDevice").asBoolean(), "the very first sign-in is not suspicious");
        login(a, PASSWORD, "Mozilla/5.0 (Windows NT 10.0) Chrome/121.0.5");
        assertFalse(hist(a).body().path("events").get(0).path("newDevice").asBoolean(), "a browser update is the same device");
        login(a, PASSWORD, "Orleu/1.0 (iPhone; iOS 17)");
        Res h = hist(a);
        assertTrue(h.body().path("events").get(0).path("newDevice").asBoolean());
        assertTrue(h.body().path("newDeviceRecently").asBoolean());
        login(a, PASSWORD, "Orleu/1.1 (iPhone; iOS 18)");
        assertFalse(hist(a).body().path("events").get(0).path("newDevice").asBoolean(), "the device is known from now on");
    }

    @Test void lockoutAndSecondFactorOutcomesAreRecorded() {
        Account a = account();
        login(a, PASSWORD, "Orleu/1.0");
        for (int i = 0; i < 5; i++) login(a, "wrong-password-" + i, "Orleu/1.0");
        assertEquals(429, login(a, PASSWORD, "Orleu/1.0").status());
        var events = hist(a).body().path("events");
        assertEquals("LOCKED", events.get(0).path("outcome").asText());
        assertEquals(5, hist(a).body().path("failedSinceLastSuccess").asInt(), "lockout rows are shown but are not counted as extra failures");

        Account b = account();
        byte[] secret = enrol(b);
        Res challenge = login(b, PASSWORD, "Orleu/2.0");
        String token = challenge.text("mfaToken");
        assertEquals(401, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", token, "code", "000000")).status());
        assertEquals("FAILED_MFA", hist(b).body().path("events").get(0).path("outcome").asText());
        assertEquals(200, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", token, "code", Totp.codeAt(secret, Totp.stepNow(Instant.now().getEpochSecond())))).status());
        var last = hist(b).body().path("events").get(0);
        assertEquals("SUCCESS", last.path("outcome").asText());
        assertTrue(last.path("mfaUsed").asBoolean());
    }

    private byte[] enrol(Account a) {
        byte[] secret = decode(post(a.token(), "/api/v1/auth/mfa/setup", null).text("secret"));
        assertEquals(200, post(a.token(), "/api/v1/auth/mfa/enable", Map.of("code", Totp.codeAt(secret, Totp.stepNow(Instant.now().getEpochSecond()) - 1))).status());
        return secret;
    }

    private static byte[] decode(String s) {
        String alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        int buffer = 0, bits = 0;
        for (char c : s.toCharArray()) { buffer = (buffer << 5) | alphabet.indexOf(c); bits += 5; if (bits >= 8) { out.write((buffer >> (bits - 8)) & 0xFF); bits -= 8; } }
        return out.toByteArray();
    }

    @Test void historyIsPrivateAndUnknownAccountsLeaveNoTrace() {
        Account a = account(), b = account();
        login(a, PASSWORD, "Orleu/1.0");
        assertEquals(401, get(null, "/api/v1/auth/login-history").status());
        assertEquals(0, hist(b).body().path("events").size(), "another user's sign-ins are never visible");
        int before = jdbc.queryForObject("select count(*) from login_events", Integer.class);
        assertEquals(401, post(null, "/api/v1/auth/login", Map.of("email", "nobody-" + UUID.randomUUID() + "@example.com", "password", PASSWORD)).status());
        assertEquals(before, jdbc.queryForObject("select count(*) from login_events", Integer.class));
    }

    @Test void eventsOlderThanTheRetentionPeriodArePurged() {
        Account a = account();
        login(a, PASSWORD, "Orleu/1.0");
        jdbc.update("insert into login_events (user_id, outcome, device_key, occurred_at) values (?, 'SUCCESS', 'x', now() - interval '91 days')", a.id());
        jdbc.update("insert into login_events (user_id, outcome, device_key, occurred_at) values (?, 'SUCCESS', 'x', now() - interval '89 days')", a.id());
        assertTrue(history.purgeOld() >= 1);
        assertEquals(0, jdbc.queryForObject("select count(*) from login_events where user_id = ? and occurred_at < now() - interval '90 days'", Integer.class, a.id()));
        assertEquals(2, jdbc.queryForObject("select count(*) from login_events where user_id = ?", Integer.class, a.id()), "the 89-day-old and the fresh event stay");
    }
}
