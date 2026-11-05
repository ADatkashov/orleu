package com.orleu.customers;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "customers")
@Getter @Setter @NoArgsConstructor
public class Customer {
    @Id @GeneratedValue(strategy = GenerationType.UUID) private UUID id;
    @Column(name = "business_id") private UUID businessId;
    @Column(name = "full_name") private String fullName;
    private String phone;
    private String email;
    private String notes;
    @Column(name = "marketing_opt_in") private boolean marketingOptIn;
    private boolean blocked;
    @Column(name = "created_at", updatable = false) private Instant createdAt;
    @PrePersist void onCreate() { createdAt = Instant.now(); }
}
