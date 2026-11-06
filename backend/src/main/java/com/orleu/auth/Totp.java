package com.orleu.auth;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.security.SecureRandom;

/** RFC 6238 TOTP (HMAC-SHA1, 30 s step, 6 digits) with RFC 4648 base32 secrets, as used by authenticator apps. */
final class Totp {
    static final int STEP_SECONDS = 30, DIGITS = 6;
    private static final String B32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    private static final SecureRandom RANDOM = new SecureRandom();
    private Totp() {}

    static byte[] newSecret() { byte[] s = new byte[20]; RANDOM.nextBytes(s); return s; }

    static String base32(byte[] data) {
        StringBuilder sb = new StringBuilder();
        int buffer = 0, bits = 0;
        for (byte b : data) {
            buffer = (buffer << 8) | (b & 0xFF);
            bits += 8;
            while (bits >= 5) { sb.append(B32.charAt((buffer >> (bits - 5)) & 31)); bits -= 5; }
        }
        if (bits > 0) sb.append(B32.charAt((buffer << (5 - bits)) & 31));
        return sb.toString();
    }

    static String codeAt(byte[] secret, long step) {
        try {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(secret, "HmacSHA1"));
            byte[] h = mac.doFinal(ByteBuffer.allocate(8).putLong(step).array());
            int off = h[h.length - 1] & 0xF;
            int bin = ((h[off] & 0x7F) << 24) | ((h[off + 1] & 0xFF) << 16) | ((h[off + 2] & 0xFF) << 8) | (h[off + 3] & 0xFF);
            return String.format("%0" + DIGITS + "d", bin % 1_000_000);
        } catch (java.security.GeneralSecurityException e) { throw new IllegalStateException(e); }
    }

    static long stepNow(long epochSeconds) { return epochSeconds / STEP_SECONDS; }

    /** @return the matched time step (current step ±1 for clock drift) or -1. Compares all candidates in constant time per candidate. */
    static long verify(byte[] secret, String code, long nowStep) {
        if (code == null || !code.matches("\\d{6}")) return -1;
        long matched = -1;
        for (long s = nowStep - 1; s <= nowStep + 1; s++) {
            if (java.security.MessageDigest.isEqual(codeAt(secret, s).getBytes(), code.getBytes())) matched = s;
        }
        return matched;
    }

    static String otpauthUri(String issuer, String account, byte[] secret) {
        String label = java.net.URLEncoder.encode(issuer + ":" + account, java.nio.charset.StandardCharsets.UTF_8).replace("+", "%20");
        return "otpauth://totp/" + label + "?secret=" + base32(secret) + "&issuer=" + java.net.URLEncoder.encode(issuer, java.nio.charset.StandardCharsets.UTF_8)
                + "&algorithm=SHA1&digits=" + DIGITS + "&period=" + STEP_SECONDS;
    }
}
