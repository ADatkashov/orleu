package com.orleu.auth;

import com.orleu.audit.AuditService;
import com.orleu.auth.AuthDtos.TokenResponse;
import com.orleu.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

@Service
public class PasswordService {
    static final Duration RESET_TTL = Duration.ofMinutes(30);
    private static final SecureRandom RANDOM = new SecureRandom();

    public record SessionView(UUID id, String userAgent, Instant createdAt, Instant expiresAt) {}

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder encoder;
    private final PasswordResetMailer mailer;
    private final AuthService auth;
    private final JdbcClient jdbc;
    private final AuditService audit;

    public PasswordService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordEncoder encoder,
                           PasswordResetMailer mailer, AuthService auth, JdbcClient jdbc, AuditService audit) {
        this.users = users; this.refreshTokens = refreshTokens; this.encoder = encoder; this.mailer = mailer;
        this.auth = auth; this.jdbc = jdbc; this.audit = audit;
    }

    /** Always succeeds from the caller's view: the response must not reveal whether the e-mail has an account. */
    @Transactional
    public void requestReset(String email) {
        var user = users.findByEmailIgnoreCase(email.trim()).filter(u -> "ACTIVE".equals(u.getStatus()));
        if (user.isEmpty()) return;
        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        jdbc.sql("insert into password_reset_tokens (user_id, token_hash, expires_at) values (:u, :h, :e)")
                .param("u", user.get().getId()).param("h", AuthService.hash(token)).param("e", Timestamp.from(Instant.now().plus(RESET_TTL))).update();
        audit.log(null, user.get().getId(), "PASSWORD_RESET_REQUESTED", "USER", user.get().getId(), null);
        mailer.send(user.get().getEmail(), token);
    }

    @Transactional
    public void confirmReset(String token, String newPassword) {
        var row = jdbc.sql("select id, user_id from password_reset_tokens where token_hash = :h and used_at is null and expires_at > now() for update")
                .param("h", AuthService.hash(token)).query((rs, i) -> new UUID[]{rs.getObject(1, UUID.class), rs.getObject(2, UUID.class)}).optional()
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "INVALID_RESET_TOKEN", "This reset link is invalid or has expired"));
        jdbc.sql("update password_reset_tokens set used_at = now() where id = :id").param("id", row[0]).update();
        jdbc.sql("update password_reset_tokens set used_at = now() where user_id = :u and used_at is null").param("u", row[1]).update(); // invalidate siblings
        setPassword(row[1], newPassword);
        audit.log(null, row[1], "PASSWORD_RESET_COMPLETED", "USER", row[1], null);
    }

    /** Verifies the current password, sets the new one and signs out every other device; returns fresh tokens for this one. */
    @Transactional
    public TokenResponse changePassword(UUID userId, String currentPassword, String newPassword, String userAgent) {
        User u = users.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        if (!encoder.matches(currentPassword, u.getPasswordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "WRONG_PASSWORD", "The current password is incorrect");
        }
        setPassword(userId, newPassword);
        audit.log(null, userId, "PASSWORD_CHANGED", "USER", userId, null);
        return auth.issueTokens(u, userAgent);
    }

    private void setPassword(UUID userId, String newPassword) {
        User u = users.findById(userId).orElseThrow();
        u.setPasswordHash(encoder.encode(newPassword));
        u.setFailedAttempts(0);
        u.setLockedUntil(null);
        users.save(u);
        refreshTokens.revokeAllForUser(userId, Instant.now(), "PASSWORD"); // a changed password ends every session
    }

    public List<SessionView> sessions(UUID userId) {
        return jdbc.sql("select id, user_agent, created_at, expires_at from refresh_tokens where user_id = :u and revoked_at is null and expires_at > now() order by created_at desc")
                .param("u", userId).query((rs, i) -> new SessionView(rs.getObject(1, UUID.class), rs.getString(2), rs.getTimestamp(3).toInstant(), rs.getTimestamp(4).toInstant())).list();
    }

    @Transactional
    public void revokeSession(UUID userId, UUID sessionId) {
        int n = jdbc.sql("update refresh_tokens set revoked_at = now(), revoked_reason = 'SESSION_REVOKED' where id = :id and user_id = :u and revoked_at is null")
                .param("id", sessionId).param("u", userId).update();
        if (n == 0) throw ApiException.notFound("Session"); // also hides other users' session ids
        audit.log(null, userId, "SESSION_REVOKED", "USER", userId, null);
    }
}
