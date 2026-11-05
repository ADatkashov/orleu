package com.orleu.catalog;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "employees")
@Getter @Setter @NoArgsConstructor
public class Employee {
    @Id @GeneratedValue(strategy = GenerationType.UUID) private UUID id;
    @Column(name = "business_id") private UUID businessId;
    @Column(name = "user_id") private UUID userId;
    @Column(name = "display_name") private String displayName;
    private boolean active = true;
    @Column(name = "created_at", updatable = false) private Instant createdAt;
    @PrePersist void onCreate() { createdAt = Instant.now(); }
}
