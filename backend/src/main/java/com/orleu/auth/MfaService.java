package com.orleu.auth;

import com.orleu.audit.AuditService;
import com.orleu.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * TOTP multi-factor authentication: enrolment, login challenge, recovery codes. The challenge token is opaque and stored hashed,
 * lives 5 minutes, allows 5 attempts and is single-use. Wrong codes also count towards the account lockout, so MFA cannot be
 * brute-forced by requesting new challenges with a stolen password.
 */
@Service
public class MfaService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final String ISSUER = "ORLEU";
    private static final int MAX_CHALLENGE_ATTEMPTS = 5, RECOVERY_CODES = 10;
    private static final java.time.Duration CHALLENGE_TTL = java.time.Duration.ofMinutes(5);

    public record Status(boolean enabled, int recoveryCodesLeft) {}
    public record Setup(String secret, String otpauthUri) {}

    private final JdbcClient jdbc;
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final SecurityProperties props;
    private final AuditService audit;
    private final byte[] aesKey;

    public MfaService(JdbcClient jdbc, UserRepository users, PasswordEncoder encoder, SecurityProperties props, AuditService audit) {
        this.jdbc = jdbc; this.users = users; this.encoder = encoder; this.props = props; this.audit = audit;
        this.aesKey = deriveKey(props);
    }

    /** AES key: SHA-256 of the dedicated MFA key, or HMAC(jwtSecret, "orleu-mfa-v1") when none is configured. */
    private static byte[] deriveKey(SecurityProperties p) {
        try {
            if (p.mfaKey() != null && !p.mfaKey().isBlank()) return MessageDigest.getInstance("SHA-256").digest(p.mfaKey().getBytes(StandardCharsets.UTF_8));
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(p.jwtSecret().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return mac.doFinal("orleu-mfa-v1".getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) { throw new IllegalStateException(e); }
    }

    // ---------- status & enrolment ----------

    public boolean isEnabled(UUID userId) {
        return Boolean.TRUE.equals(jdbc.sql("select enabled from user_mfa where user_id = :u").param("u", userId).query(Boolean.class).optional().orElse(false));
    }

    public Status status(UUID userId) {
        int left = jdbc.sql("select count(*) from mfa_recovery_codes where user_id = :u and used_at is null").param("u", userId).query(Integer.class).single();
        return new Status(isEnabled(userId), left);
    }

    @Transactional
    public Setup setup(UUID userId) {
        if (isEnabled(userId)) throw ApiException.conflict("MFA_ALREADY_ENABLED", "Two-factor authentication is already enabled");
        User u = users.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        byte[] secret = Totp.newSecret();
        jdbc.sql("""
            insert into user_mfa (user_id, secret_cipher, enabled) values (:u, :c, false)
            on conflict (user_id) do update set secret_cipher = excluded.secret_cipher, enabled = false, last_used_step = 0, created_at = now()
            """).param("u", userId).param("c", encrypt(secret)).update();
        return new Setup(Totp.base32(secret), Totp.otpauthUri(ISSUER, u.getEmail(), secret));
    }

    /** Confirms enrolment with a first valid code and returns the one-time recovery codes (shown only now). */
    @Transactional
    public List<String> enable(UUID userId, String code) {
        var row = jdbc.sql("select secret_cipher, enabled from user_mfa where user_id = :u for update").param("u", userId)
                .query((rs, i) -> new Object[]{rs.getBytes(1), rs.getBoolean(2)}).optional()
                .orElseThrow(() -> ApiException.conflict("MFA_NOT_SET_UP", "Start the setup first"));
        if ((Boolean) row[1]) throw ApiException.conflict("MFA_ALREADY_ENABLED", "Two-factor authentication is already enabled");
        long step = Totp.verify(decrypt((byte[]) row[0]), code, Totp.stepNow(Instant.now().getEpochSecond()));
        if (step < 0) throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_MFA_CODE", "The code is not correct");
        jdbc.sql("update user_mfa set enabled = true, enabled_at = now(), last_used_step = :s where user_id = :u").param("s", step).param("u", userId).update();
        List<String> codes = newRecoveryCodes(userId);
        audit.log(null, userId, "MFA_ENABLED", "USER", userId, null);
        return codes;
    }

    /** Disabling needs the password AND a current code (or recovery code): a stolen session alone cannot remove the second factor. */
    @Transactional(noRollbackFor = ApiException.class)
    public void disable(UUID userId, String password, String code) {
        User u = users.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        if (!encoder.matches(password, u.getPasswordHash())) throw new ApiException(HttpStatus.BAD_REQUEST, "WRONG_PASSWORD", "The current password is incorrect");
        if (!isEnabled(userId)) throw ApiException.conflict("MFA_NOT_ENABLED", "Two-factor authentication is not enabled");
        if (!checkCode(userId, code)) throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_MFA_CODE", "The code is not correct");
        jdbc.sql("delete from user_mfa where user_id = :u").param("u", userId).update();
        jdbc.sql("delete from mfa_recovery_codes where user_id = :u").param("u", userId).update();
        audit.log(null, userId, "MFA_DISABLED", "USER", userId, null);
    }

    // ---------- login challenge ----------

    /** @return the raw challenge token (returned to the client once). */
    @Transactional
    public String startChallenge(UUID userId, String userAgent) {
        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        jdbc.sql("insert into mfa_challenges (user_id, token_hash, user_agent, expires_at) values (:u, :h, :ua, :e)")
                .param("u", userId).param("h", hash(token)).param("ua", userAgent == null ? null : userAgent.substring(0, Math.min(300, userAgent.length())), java.sql.Types.VARCHAR)
                .param("e", java.sql.Timestamp.from(Instant.now().plus(CHALLENGE_TTL))).update();
        return token;
    }

    /** Verifies the code for a challenge and consumes it. @return the user id; counts failures towards the account lockout. */
    @Transactional(noRollbackFor = ApiException.class)
    public User completeChallenge(String token, String code) {
        var ch = jdbc.sql("select id, user_id, attempts, expires_at, used_at from mfa_challenges where token_hash = :h for update").param("h", hash(token))
                .query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getInt(3), rs.getTimestamp(4).toInstant(), rs.getTimestamp(5)})
                .optional().orElseThrow(MfaService::invalidChallenge);
        UUID challengeId = (UUID) ch[0], userId = (UUID) ch[1];
        if (ch[4] != null || ((Instant) ch[3]).isBefore(Instant.now()) || (Integer) ch[2] >= MAX_CHALLENGE_ATTEMPTS) throw invalidChallenge();
        User u = users.findById(userId).filter(x -> "ACTIVE".equals(x.getStatus())).orElseThrow(MfaService::invalidChallenge);
        Instant now = Instant.now();
        if (u.getLockedUntil() != null && u.getLockedUntil().isAfter(now)) throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "ACCOUNT_LOCKED", "Too many failed attempts. Try again later.");
        if (!checkCode(userId, code)) {
            jdbc.sql("update mfa_challenges set attempts = attempts + 1 where id = :id").param("id", challengeId).update();
            u.setFailedAttempts(u.getFailedAttempts() + 1);
            if (u.getFailedAttempts() >= props.maxFailedLogins()) {
                u.setLockedUntil(now.plus(props.lockoutDuration()));
                u.setFailedAttempts(0);
                audit.log(null, userId, "ACCOUNT_LOCKED", "USER", userId, null);
            }
            users.save(u);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_MFA_CODE", "The code is not correct");
        }
        jdbc.sql("update mfa_challenges set used_at = now() where id = :id").param("id", challengeId).update();
        u.setFailedAttempts(0);
        u.setLockedUntil(null);
        users.save(u);
        audit.log(null, userId, "LOGIN_MFA", "USER", userId, null);
        return u;
    }

    // ---------- codes ----------

    /** Accepts a current TOTP code (each time step only once) or an unused recovery code. */
    private boolean checkCode(UUID userId, String code) {
        if (code == null) return false;
        String c = code.trim().replace(" ", "");
        var row = jdbc.sql("select secret_cipher, last_used_step from user_mfa where user_id = :u and enabled for update").param("u", userId)
                .query((rs, i) -> new Object[]{rs.getBytes(1), rs.getLong(2)}).optional();
        if (row.isEmpty()) return false;
        if (c.matches("\\d{6}")) {
            long step = Totp.verify(decrypt((byte[]) row.get()[0]), c, Totp.stepNow(Instant.now().getEpochSecond()));
            if (step < 0 || step <= (Long) row.get()[1]) return false; // wrong, or this time step was already used (replay)
            jdbc.sql("update user_mfa set last_used_step = :s where user_id = :u").param("s", step).param("u", userId).update();
            return true;
        }
        int n = jdbc.sql("update mfa_recovery_codes set used_at = now() where user_id = :u and code_hash = :h and used_at is null")
                .param("u", userId).param("h", hash(c.toLowerCase())).update();
        if (n == 1) audit.log(null, userId, "MFA_RECOVERY_CODE_USED", "USER", userId, null);
        return n == 1;
    }

    private List<String> newRecoveryCodes(UUID userId) {
        jdbc.sql("delete from mfa_recovery_codes where user_id = :u").param("u", userId).update();
        List<String> out = new ArrayList<>();
        String alphabet = "abcdefghjkmnpqrstuvwxyz23456789";
        for (int i = 0; i < RECOVERY_CODES; i++) {
            StringBuilder sb = new StringBuilder();
            for (int j = 0; j < 10; j++) { if (j == 5) sb.append('-'); sb.append(alphabet.charAt(RANDOM.nextInt(alphabet.length()))); }
            String code = sb.toString();
            out.add(code);
            jdbc.sql("insert into mfa_recovery_codes (user_id, code_hash) values (:u, :h)").param("u", userId).param("h", hash(code)).update();
        }
        return out;
    }

    // ---------- crypto helpers ----------

    private byte[] encrypt(byte[] plain) {
        try {
            byte[] iv = new byte[12];
            RANDOM.nextBytes(iv);
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(aesKey, "AES"), new GCMParameterSpec(128, iv));
            byte[] ct = c.doFinal(plain);
            byte[] out = new byte[iv.length + ct.length];
            System.arraycopy(iv, 0, out, 0, iv.length);
            System.arraycopy(ct, 0, out, iv.length, ct.length);
            return out;
        } catch (GeneralSecurityException e) { throw new IllegalStateException(e); }
    }

    private byte[] decrypt(byte[] blob) {
        try {
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, new SecretKeySpec(aesKey, "AES"), new GCMParameterSpec(128, blob, 0, 12));
            return c.doFinal(blob, 12, blob.length - 12);
        } catch (GeneralSecurityException e) { throw new IllegalStateException("MFA secret cannot be decrypted (was the MFA key changed?)", e); }
    }

    private static String hash(String v) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(v.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    private static ApiException invalidChallenge() { return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_MFA_CHALLENGE", "The sign-in attempt expired; please sign in again"); }
}
