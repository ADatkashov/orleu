package com.orleu.catalog;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** A bookable service (named ServiceOffering to avoid clashing with Spring's @Service). */
@Entity @Table(name = "services")
@Getter @Setter @NoArgsConstructor
public class ServiceOffering {
    @Id @GeneratedValue(strategy = GenerationType.UUID) private UUID id;
    @Column(name = "business_id") private UUID businessId;
    private String name;
    private String description;
    private String category;
    @Column(name = "duration_minutes") private int durationMinutes;
    @Column(name = "buffer_minutes") private int bufferMinutes;
    private BigDecimal price;
    @Column(name = "deposit_percent") private BigDecimal depositPercent;
    @Column(name = "online_bookable") private boolean onlineBookable = true;
    private boolean active = true;
    @Column(name = "created_at", updatable = false) private Instant createdAt;
    @PrePersist void onCreate() { createdAt = Instant.now(); }
}
