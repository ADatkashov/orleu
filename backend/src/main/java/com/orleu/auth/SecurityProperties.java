package com.orleu.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

@ConfigurationProperties(prefix = "orleu.security")
public record SecurityProperties(
        String jwtSecret,
        Duration accessTokenTtl,
        Duration refreshTokenTtl,
        int maxFailedLogins,
        Duration lockoutDuration,
        java.util.List<String> allowedOrigins) {
    public SecurityProperties {
        if (jwtSecret == null || jwtSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("orleu.security.jwt-secret (ORLEU_JWT_SECRET) must be at least 32 bytes");
        }
        if (accessTokenTtl == null) accessTokenTtl = Duration.ofMinutes(15);
        if (refreshTokenTtl == null) refreshTokenTtl = Duration.ofDays(30);
        if (maxFailedLogins <= 0) maxFailedLogins = 5;
        if (lockoutDuration == null) lockoutDuration = Duration.ofMinutes(15);
        if (allowedOrigins == null) allowedOrigins = java.util.List.of();
    }
}
