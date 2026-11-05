package com.orleu.auth;

import com.orleu.auth.AuthDtos.*;
import com.orleu.audit.AuditService;
import com.orleu.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

@Service
public class AuthService {
    private static final SecureRandom RANDOM = new SecureRandom();
    // Verified against when the e-mail is unknown so login timing does not reveal account existence.
    private final String dummyHash;

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder encoder;
    private final JwtEncoder jwtEncoder;
    private final SecurityProperties props;
    private final AuditService audit;

    public AuthService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordEncoder encoder,
                       JwtEncoder jwtEncoder, SecurityProperties props, AuditService audit) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.encoder = encoder;
        this.jwtEncoder = jwtEncoder;
        this.props = props;
        this.audit = audit;
        this.dummyHash = encoder.encode("orleu-dummy-password");
    }

    @Transactional
    public TokenResponse register(RegisterRequest r, String userAgent) {
        if (users.findByEmailIgnoreCase(r.email()).isPresent()) {
            throw ApiException.conflict("EMAIL_TAKEN", "An account with this e-mail already exists");
        }
        User u = new User();
        u.setEmail(r.email().trim());
        u.setPhone(r.phone());
        u.setFullName(r.fullName().trim());
        u.setPasswordHash(encoder.encode(r.password()));
        if (r.locale() != null) u.setLocale(r.locale());
        try {
            users.saveAndFlush(u);
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            throw ApiException.conflict("ACCOUNT_EXISTS", "An account with this e-mail or phone already exists");
        }
        audit.log(null, u.getId(), "USER_REGISTERED", "USER", u.getId(), null);
        return issue(u, userAgent);
    }

    @Transactional(noRollbackFor = ApiException.class)
    public TokenResponse login(LoginRequest r, String userAgent) {
        User u = users.findByEmailIgnoreCase(r.email().trim()).orElse(null);
        if (u == null) {
            encoder.matches(r.password(), dummyHash);
            throw invalidCredentials();
        }
        Instant now = Instant.now();
        if (u.getLockedUntil() != null && u.getLockedUntil().isAfter(now)) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "ACCOUNT_LOCKED",
                    "Too many failed attempts. Try again later.");
        }
        if (!"ACTIVE".equals(u.getStatus()) || !encoder.matches(r.password(), u.getPasswordHash())) {
            u.setFailedAttempts(u.getFailedAttempts() + 1);
            if (u.getFailedAttempts() >= props.maxFailedLogins()) {
                u.setLockedUntil(now.plus(props.lockoutDuration()));
                u.setFailedAttempts(0);
                audit.log(null, u.getId(), "ACCOUNT_LOCKED", "USER", u.getId(), null);
            }
            users.save(u);
            throw invalidCredentials();
        }
        u.setFailedAttempts(0);
        u.setLockedUntil(null);
        users.save(u);
        audit.log(null, u.getId(), "LOGIN", "USER", u.getId(), null);
        return issue(u, userAgent);
    }

    /** Rotates the refresh token. Presenting an already-used token revokes every session of that user. */
    @Transactional(noRollbackFor = ApiException.class)
    public TokenResponse refresh(String rawToken, String userAgent) {
        RefreshToken t = refreshTokens.findByTokenHash(hash(rawToken))
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Invalid refresh token"));
        Instant now = Instant.now();
        if (t.getRevokedAt() != null) {
            // Only a token that was already ROTATED (null = legacy rows) is evidence of theft. Tokens revoked by logout,
            // password change or session revocation are just rejected; otherwise a stale device would sign out the user everywhere.
            if (t.getRevokedReason() == null || "ROTATED".equals(t.getRevokedReason())) {
                refreshTokens.revokeAllForUser(t.getUserId(), now, "REUSE");
                audit.log(null, t.getUserId(), "REFRESH_TOKEN_REUSE", "USER", t.getUserId(), null);
            }
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Invalid refresh token");
        }
        if (t.getExpiresAt().isBefore(now)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Refresh token expired");
        }
        User u = users.findById(t.getUserId())
                .filter(x -> "ACTIVE".equals(x.getStatus()))
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Invalid refresh token"));
        t.setRevokedAt(now);
        t.setRevokedReason("ROTATED");
        refreshTokens.save(t);
        return issue(u, userAgent);
    }

    @Transactional
    public void logout(String rawToken) {
        refreshTokens.findByTokenHash(hash(rawToken)).ifPresent(t -> {
            if (t.getRevokedAt() == null) {
                t.setRevokedAt(Instant.now());
                t.setRevokedReason("LOGOUT");
                refreshTokens.save(t);
            }
        });
    }

    @Transactional
    public void logoutEverywhere(UUID userId) {
        refreshTokens.revokeAllForUser(userId, Instant.now(), "LOGOUT");
    }

    /** Issues a fresh access/refresh pair (used by login, register, refresh and password change). */
    TokenResponse issueTokens(User u, String userAgent) { return issue(u, userAgent); }

    private TokenResponse issue(User u, String userAgent) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("orleu")
                .subject(u.getId().toString())
                .issuedAt(now)
                .expiresAt(now.plus(props.accessTokenTtl()))
                .id(UUID.randomUUID().toString())
                .build();
        String access = jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();

        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        RefreshToken t = new RefreshToken();
        t.setUserId(u.getId());
        t.setTokenHash(hash(refresh));
        t.setUserAgent(userAgent == null ? null : userAgent.substring(0, Math.min(300, userAgent.length())));
        t.setExpiresAt(now.plus(props.refreshTokenTtl()));
        refreshTokens.save(t);
        return new TokenResponse(access, refresh, props.accessTokenTtl().toSeconds(), "Bearer");
    }

    static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static ApiException invalidCredentials() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Invalid e-mail or password");
    }
}
