package com.orleu.auth;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "refresh_tokens")
@Getter @Setter @NoArgsConstructor
public class RefreshToken {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(name = "user_id") private UUID userId;
    @Column(name = "token_hash") private String tokenHash;
    @Column(name = "user_agent") private String userAgent;
    @Column(name = "expires_at") private Instant expiresAt;
    @Column(name = "revoked_at") private Instant revokedAt;
    @Column(name = "created_at", updatable = false) private Instant createdAt;

    @PrePersist void onCreate() { createdAt = Instant.now(); }
}
