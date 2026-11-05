package com.orleu.auth;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter @Setter @NoArgsConstructor
public class User {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private String email;
    private String phone;
    @Column(name = "password_hash") private String passwordHash;
    @Column(name = "full_name") private String fullName;
    private String locale = "ru";
    private String status = "ACTIVE";
    @Column(name = "failed_attempts") private int failedAttempts;
    @Column(name = "locked_until") private Instant lockedUntil;
    @Column(name = "created_at", updatable = false) private Instant createdAt;
    @Column(name = "updated_at") private Instant updatedAt;

    @PrePersist void onCreate() { createdAt = updatedAt = Instant.now(); }
    @PreUpdate void onUpdate() { updatedAt = Instant.now(); }
}
