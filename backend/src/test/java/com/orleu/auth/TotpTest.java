package com.orleu.auth;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;

/** RFC 6238 appendix B test vectors (SHA-1, secret "12345678901234567890"), truncated to 6 digits. */
class TotpTest {
    private static final byte[] SECRET = "12345678901234567890".getBytes(StandardCharsets.US_ASCII);

    @Test void matchesTheRfc6238Vectors() {
        assertEquals("287082", Totp.codeAt(SECRET, 59 / 30));
        assertEquals("081804", Totp.codeAt(SECRET, 1111111109L / 30));
        assertEquals("050471", Totp.codeAt(SECRET, 1111111111L / 30));
        assertEquals("005924", Totp.codeAt(SECRET, 1234567890L / 30));
        assertEquals("279037", Totp.codeAt(SECRET, 2000000000L / 30));
        assertEquals("353130", Totp.codeAt(SECRET, 20000000000L / 30));
    }

    @Test void base32MatchesTheRfc4648Vectors() {
        assertEquals("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", Totp.base32(SECRET));
        assertEquals("MZXW6YTBOI", Totp.base32("foobar".getBytes(StandardCharsets.US_ASCII)));
    }

    @Test void verifyAcceptsOneStepOfClockDriftButNotMoreAndRejectsMalformedCodes() {
        long now = 1111111111L / 30;
        assertEquals(now, Totp.verify(SECRET, Totp.codeAt(SECRET, now), now));
        assertEquals(now - 1, Totp.verify(SECRET, Totp.codeAt(SECRET, now - 1), now));
        assertEquals(now + 1, Totp.verify(SECRET, Totp.codeAt(SECRET, now + 1), now));
        assertEquals(-1, Totp.verify(SECRET, Totp.codeAt(SECRET, now - 2), now));
        assertEquals(-1, Totp.verify(SECRET, Totp.codeAt(SECRET, now + 2), now));
        for (String bad : new String[]{null, "", "12345", "1234567", "abcdef", "12 345"}) assertEquals(-1, Totp.verify(SECRET, bad, now), String.valueOf(bad));
    }

    @Test void otpauthUriCarriesIssuerAccountSecretAndParameters() {
        String uri = Totp.otpauthUri("ORLEU", "a@b.kz", SECRET);
        assertTrue(uri.startsWith("otpauth://totp/ORLEU%3Aa%40b.kz?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=ORLEU&algorithm=SHA1&digits=6&period=30"), uri);
    }
}
