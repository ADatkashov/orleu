package com.orleu.tenancy;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "memberships")
@Getter @Setter @NoArgsConstructor
public class Membership {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(name = "user_id") private UUID userId;
    @Column(name = "business_id") private UUID businessId;
    @Enumerated(EnumType.STRING) private BusinessRole role;
    private String status = "ACTIVE";
    @Column(name = "created_at", updatable = false) private Instant createdAt;

    @PrePersist void onCreate() { createdAt = Instant.now(); }
}
