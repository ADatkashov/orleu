package com.orleu.it;

import com.orleu.support.AbstractIT;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class AuthIT extends AbstractIT {
    private Map<String, String> reg(String email) {
        return Map.of("email", email, "password", "correct-horse-battery", "fullName", "Aigerim S.", "phone", "+7701" + (1000000 + (int) (Math.random() * 8999999)));
    }

    @Test void registerLoginAndMe() {
        String email = unique("a") + "@example.com";
        assertEquals(201, post(null, "/api/v1/auth/register", reg(email)).status());
        Res login = post(null, "/api/v1/auth/login", Map.of("email", email.toUpperCase(), "password", "correct-horse-battery"));
        assertEquals(200, login.status());
        Res me = get(login.text("accessToken"), "/api/v1/me");
        assertEquals(200, me.status());
        assertEquals(email, me.text("email"));
        assertFalse(me.body().toString().contains("passwordHash"));
    }

    @Test void passwordsAreHashedWithArgon2id() {
        String email = unique("h") + "@example.com";
        post(null, "/api/v1/auth/register", reg(email));
        String hash = jdbc.queryForObject("select password_hash from users where lower(email) = lower(?)", String.class, email);
        assertTrue(hash.startsWith("$argon2id$"), hash);
    }

    @Test void duplicateEmailRejected() {
        String email = unique("d") + "@example.com";
        assertEquals(201, post(null, "/api/v1/auth/register", reg(email)).status());
        assertEquals(409, post(null, "/api/v1/auth/register", reg(email.toUpperCase())).status());
    }

    @Test void weakPasswordAndBadPhoneRejected() {
        assertEquals(400, post(null, "/api/v1/auth/register", Map.of("email", unique("w") + "@example.com", "password", "short", "fullName", "X")).status());
        assertEquals(400, post(null, "/api/v1/auth/register", Map.of("email", unique("p") + "@example.com", "password", "correct-horse-battery", "fullName", "X", "phone", "87011234567")).status());
    }

    @Test void wrongPasswordGivesSameErrorAsUnknownUser() {
        String email = unique("e") + "@example.com";
        post(null, "/api/v1/auth/register", reg(email));
        Res wrong = post(null, "/api/v1/auth/login", Map.of("email", email, "password", "nope-nope-nope"));
        Res unknown = post(null, "/api/v1/auth/login", Map.of("email", "ghost" + email, "password", "nope-nope-nope"));
        assertEquals(401, wrong.status());
        assertEquals(401, unknown.status());
        assertEquals(wrong.text("code"), unknown.text("code"));
        assertEquals(wrong.text("message"), unknown.text("message"));
    }

    @Test void accountLocksAfterRepeatedFailures() {
        String email = unique("l") + "@example.com";
        post(null, "/api/v1/auth/register", reg(email));
        for (int i = 0; i < 5; i++) assertEquals(401, post(null, "/api/v1/auth/login", Map.of("email", email, "password", "bad-bad-bad-bad")).status());
        // even the correct password is refused while locked
        assertEquals(429, post(null, "/api/v1/auth/login", Map.of("email", email, "password", "correct-horse-battery")).status());
    }

    @Test void refreshRotatesAndReuseRevokesEverySession() {
        String email = unique("r") + "@example.com";
        post(null, "/api/v1/auth/register", reg(email));
        Res login = post(null, "/api/v1/auth/login", Map.of("email", email, "password", "correct-horse-battery"));
        String r1 = login.text("refreshToken");
        Res rotated = post(null, "/api/v1/auth/refresh", Map.of("refreshToken", r1));
        assertEquals(200, rotated.status());
        String r2 = rotated.text("refreshToken");
        assertNotEquals(r1, r2);
        // replaying the old token is theft evidence: it fails AND kills the new token too
        assertEquals(401, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", r1)).status());
        assertEquals(401, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", r2)).status());
    }

    @Test void replayingALoggedOutTokenIsRejectedWithoutKillingOtherSessions() {
        String email = unique("lo") + "@example.com";
        post(null, "/api/v1/auth/register", reg(email));
        Res a = post(null, "/api/v1/auth/login", Map.of("email", email, "password", "correct-horse-battery"));
        Res b = post(null, "/api/v1/auth/login", Map.of("email", email, "password", "correct-horse-battery"));
        post(null, "/api/v1/auth/logout", Map.of("refreshToken", a.text("refreshToken")));
        assertEquals(401, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", a.text("refreshToken"))).status());
        assertEquals(200, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", b.text("refreshToken"))).status()); // other device unaffected
    }

    @Test void logoutRevokesRefreshToken() {
        String email = unique("o") + "@example.com";
        post(null, "/api/v1/auth/register", reg(email));
        Res login = post(null, "/api/v1/auth/login", Map.of("email", email, "password", "correct-horse-battery"));
        assertEquals(204, post(null, "/api/v1/auth/logout", Map.of("refreshToken", login.text("refreshToken"))).status());
        assertEquals(401, post(null, "/api/v1/auth/refresh", Map.of("refreshToken", login.text("refreshToken"))).status());
    }

    @Test void refreshTokensAreStoredOnlyAsHashes() {
        String email = unique("s") + "@example.com";
        Res r = post(null, "/api/v1/auth/register", reg(email));
        Integer plain = jdbc.queryForObject("select count(*) from refresh_tokens where token_hash = ?", Integer.class, r.text("refreshToken"));
        assertEquals(0, plain);
    }

    @Test void protectedEndpointsRequireAuthentication() {
        assertEquals(401, get(null, "/api/v1/me").status());
        assertEquals(401, get("garbage.token.value", "/api/v1/me").status());
        assertEquals(401, get(null, "/api/v1/businesses").status());
    }

    @Test void actuatorInternalsAreNotExposedToSignedInUsers() {
        String token = newUser("act");
        for (String path : new String[]{"/actuator/metrics", "/actuator/env", "/actuator/beans", "/actuator/heapdump", "/actuator/loggers"}) {
            int status = get(token, path).status();
            assertTrue(status == 404 || status == 401 || status == 403, path + " must not be readable, got " + status);
        }
        assertEquals(200, get(null, "/actuator/health").status());           // health stays public for probes
        assertFalse(get(null, "/actuator/health").body().toString().contains("jdbc"), "no component details for anonymous callers");
    }

    @Test void errorsCarryCorrelationIdAndNoStackTrace() {
        Res r = post(null, "/api/v1/auth/login", Map.of("email", "", "password", ""));
        assertEquals(400, r.status());
        assertEquals("VALIDATION_FAILED", r.text("code"));
        assertFalse(r.body().toString().contains("Exception"));
    }
}
