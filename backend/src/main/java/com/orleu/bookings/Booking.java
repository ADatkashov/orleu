package com.orleu.bookings;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "bookings")
@Getter @Setter @NoArgsConstructor
public class Booking {
    @Id @GeneratedValue(strategy = GenerationType.UUID) private UUID id;
    @Column(name = "business_id", updatable = false) private UUID businessId;
    @Column(name = "branch_id") private UUID branchId;
    @Column(name = "service_id") private UUID serviceId;
    @Column(name = "employee_id") private UUID employeeId;
    @Column(name = "customer_id") private UUID customerId;
    @Column(name = "starts_at") private Instant startsAt;
    @Column(name = "ends_at") private Instant endsAt;
    @Column(name = "blocked_until") private Instant blockedUntil;
    @Enumerated(EnumType.STRING) private BookingStatus status;
    private BigDecimal price;
    @Column(name = "deposit_amount") private BigDecimal depositAmount;
    private String currency;
    @Column(name = "hold_expires_at") private Instant holdExpiresAt;
    private String notes;
    private String source;
    @Column(name = "manage_token_hash") private String manageTokenHash;
    @Transient private String rawManageToken; // only available on the instance that created it
    @Version private long version;
    @Column(name = "created_at", updatable = false) private Instant createdAt;
    @Column(name = "updated_at") private Instant updatedAt;

    @PrePersist void onCreate() { createdAt = updatedAt = Instant.now(); }
    @PreUpdate void onUpdate() { updatedAt = Instant.now(); }
}
