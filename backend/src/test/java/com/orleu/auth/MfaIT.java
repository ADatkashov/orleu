package com.orleu.auth;

import com.orleu.support.AbstractIT;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class MfaIT extends AbstractIT {
    private static final String PASSWORD = "correct-horse-battery";

    private record Account(String email, String token) {}

    private Account account() {
        String t = newUser("mfa");
        return new Account(get(t, "/api/v1/me").text("email"), t);
    }

    private static byte[] base32Decode(String s) {
        String alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        int buffer = 0, bits = 0;
        for (char c : s.toCharArray()) {
            buffer = (buffer << 5) | alphabet.indexOf(c);
            bits += 5;
            if (bits >= 8) { out.write((buffer >> (bits - 8)) & 0xFF); bits -= 8; }
        }
        return out.toByteArray();
    }

    private static long now() { return Totp.stepNow(Instant.now().getEpochSecond()); }
    private static String code(byte[] secret, long step) { return Totp.codeAt(secret, step); }

    /** Enrols the account; the enrolment consumes time step now-1 so that now and now+1 stay usable for later logins. */
    private byte[] enrol(Account a) {
        Res setup = post(a.token(), "/api/v1/auth/mfa/setup", null);
        assertEquals(200, setup.status(), setup.body().toString());
        byte[] secret = base32Decode(setup.text("secret"));
        assertTrue(setup.text("otpauthUri").startsWith("otpauth://totp/ORLEU"));
        assertEquals(400, post(a.token(), "/api/v1/auth/mfa/enable", Map.of("code", "000000")).status(), "a wrong code must not enable MFA");
        Res enable = post(a.token(), "/api/v1/auth/mfa/enable", Map.of("code", code(secret, now() - 1)));
        assertEquals(200, enable.status(), enable.body().toString());
        assertEquals(10, enable.body().path("recoveryCodes").size());
        return secret;
    }

    private Res login(Account a) { return post(null, "/api/v1/auth/login", Map.of("email", a.email(), "password", PASSWORD)); }

    @Test void loginWithMfaNeedsTheSecondStepAndTheChallengeIsNotAnAccessToken() {
        Account a = account();
        assertFalse(get(a.token(), "/api/v1/auth/mfa").body().path("enabled").asBoolean());
        assertTrue(login(a).body().has("accessToken"), "without MFA, login returns tokens directly");
        byte[] secret = enrol(a);
        assertEquals(10, get(a.token(), "/api/v1/auth/mfa").body().path("recoveryCodesLeft").asInt());

        Res first = login(a);
        assertEquals(200, first.status());
        assertTrue(first.body().path("mfaRequired").asBoolean());
        assertFalse(first.body().has("accessToken") || first.body().has("refreshToken"), "no tokens before the second factor");
        String challenge = first.text("mfaToken");
        assertEquals(401, get(challenge, "/api/v1/me").status(), "the challenge token must not work as an access token");

        assertEquals(401, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", challenge, "code", "123456")).status());
        Res ok = post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", challenge, "code", code(secret, now())));
        assertEquals(200, ok.status(), ok.body().toString());
        assertEquals(200, get(ok.text("accessToken"), "/api/v1/me").status());
        assertEquals(401, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", challenge, "code", code(secret, now() + 1))).status(), "a challenge is single-use");
    }

    @Test void aCodeCannotBeReplayedAndTheWrongPasswordNeverReachesTheSecondStep() {
        Account a = account();
        byte[] secret = enrol(a);
        String c1 = login(a).text("mfaToken");
        String used = code(secret, now());
        assertEquals(200, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", c1, "code", used)).status());
        String c2 = login(a).text("mfaToken");
        assertEquals(401, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", c2, "code", used)).status(), "the same code in the same time step is rejected");
        assertEquals(200, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", c2, "code", code(secret, now() + 1))).status());
        assertEquals(401, post(null, "/api/v1/auth/login", Map.of("email", a.email(), "password", "wrong-password-1")).status());
    }

    @Test void recoveryCodesWorkOnceAndAreStoredHashed() {
        Account a = account();
        Res setup = post(a.token(), "/api/v1/auth/mfa/setup", null);
        byte[] secret = base32Decode(setup.text("secret"));
        String recovery = post(a.token(), "/api/v1/auth/mfa/enable", Map.of("code", code(secret, now()))).body().path("recoveryCodes").get(0).asText();
        assertEquals(0, jdbc.queryForObject("select count(*) from mfa_recovery_codes where code_hash = ?", Integer.class, recovery), "never stored in clear");
        assertNotEquals(setup.text("secret"), new String(jdbc.queryForObject("select secret_cipher from user_mfa where user_id = (select id from users where lower(email) = lower(?))", byte[].class, a.email())), "the TOTP secret is encrypted at rest");

        assertEquals(200, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", login(a).text("mfaToken"), "code", recovery)).status());
        assertEquals(401, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", login(a).text("mfaToken"), "code", recovery)).status(), "a recovery code is single-use");
        assertEquals(9, get(a.token(), "/api/v1/auth/mfa").body().path("recoveryCodesLeft").asInt());
    }

    @Test void guessingIsLimitedPerChallengeAndFeedsTheAccountLockout() {
        Account a = account();
        byte[] secret = enrol(a);
        String challenge = login(a).text("mfaToken");
        for (int i = 0; i < 5; i++) {
            int s = post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", challenge, "code", "11111" + i)).status();
            assertTrue(s == 401 || s == 429, "attempt " + i + " -> " + s);
        }
        // five failures locked the account (maxFailedLogins = 5): even a correct code and a correct password are refused now
        assertEquals(429, login(a).status());
        assertEquals(401, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", challenge, "code", code(secret, now()))).status(), "the exhausted challenge is dead");
    }

    @Test void expiredChallengesAreRejected() {
        Account a = account();
        byte[] secret = enrol(a);
        String challenge = login(a).text("mfaToken");
        jdbc.update("update mfa_challenges set expires_at = now() - interval '1 minute' where user_id = (select id from users where lower(email) = lower(?))", a.email());
        Res r = post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", challenge, "code", code(secret, now())));
        assertEquals(401, r.status());
        assertEquals("INVALID_MFA_CHALLENGE", r.text("code"));
        assertEquals(401, post(null, "/api/v1/auth/mfa/verify", Map.of("mfaToken", "x".repeat(43), "code", "123456")).status());
    }

    @Test void disablingNeedsPasswordAndCodeAndRestoresPlainLogin() {
        Account a = account();
        byte[] secret = enrol(a);
        assertEquals(400, post(a.token(), "/api/v1/auth/mfa/disable", Map.of("password", "wrong-password-1", "code", code(secret, now()))).status());
        assertEquals(400, post(a.token(), "/api/v1/auth/mfa/disable", Map.of("password", PASSWORD, "code", "000000")).status());
        assertTrue(get(a.token(), "/api/v1/auth/mfa").body().path("enabled").asBoolean());
        assertEquals(204, post(a.token(), "/api/v1/auth/mfa/disable", Map.of("password", PASSWORD, "code", code(secret, now()))).status());
        assertTrue(login(a).body().has("accessToken"));
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where action = 'MFA_DISABLED' and actor_user_id = (select id from users where lower(email) = lower(?))", Integer.class, a.email()));
    }

    @Test void enrolmentEndpointsRequireSignInAndSetupIsRefusedOnceEnabled() {
        assertEquals(401, post(null, "/api/v1/auth/mfa/setup", null).status());
        assertEquals(401, get(null, "/api/v1/auth/mfa").status());
        Account a = account();
        enrol(a);
        assertEquals(409, post(a.token(), "/api/v1/auth/mfa/setup", null).status());
    }
}
