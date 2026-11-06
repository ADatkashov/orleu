package com.orleu.auth;

import com.orleu.support.AbstractIT;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

import java.time.Instant;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

@TestPropertySource(properties = "orleu.security.require-mfa-for-platform-roles=true")
class MfaPlatformIT extends AbstractIT {
    @Test void platformStaffNeedMfaWhenTheServerRequiresIt() {
        String t = newUser("root");
        jdbc.update("update users set platform_role = 'SUPER_ADMIN' where lower(email) = lower(?)", get(t, "/api/v1/me").text("email"));
        Res denied = get(t, "/api/v1/admin/me");
        assertEquals(403, denied.status());
        assertEquals("MFA_REQUIRED", denied.text("code"));
        assertEquals(403, get(t, "/api/v1/admin/businesses").status());

        Res setup = post(t, "/api/v1/auth/mfa/setup", null);
        String secret = setup.text("secret");
        byte[] raw = new byte[20];
        // decode base32 (same alphabet as the implementation)
        String alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        int buffer = 0, bits = 0, n = 0;
        for (char c : secret.toCharArray()) { buffer = (buffer << 5) | alphabet.indexOf(c); bits += 5; if (bits >= 8) { raw[n++] = (byte) ((buffer >> (bits - 8)) & 0xFF); bits -= 8; } }
        assertEquals(200, post(t, "/api/v1/auth/mfa/enable", Map.of("code", Totp.codeAt(raw, Totp.stepNow(Instant.now().getEpochSecond())))).status());
        assertEquals(200, get(t, "/api/v1/admin/me").status(), "with MFA enabled the platform role works");
    }

    @Test void ordinaryBusinessUsersAreNotAffected() {
        String t = newUser("owner");
        assertEquals(403, get(t, "/api/v1/admin/me").status());
        assertEquals(200, get(t, "/api/v1/me").status());
    }
}
