package com.orleu.business;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "businesses")
@Getter @Setter @NoArgsConstructor
public class Business {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private String slug;
    private String name;
    @Column(name = "business_type") private String businessType;
    private String description;
    private String country = "KZ";
    private String city;
    private String address;
    private String phone;
    private String email;
    private String currency = "KZT";
    private String timezone = "Asia/Almaty";
    @Column(name = "plan_code") private String planCode = "FREE";
    private boolean published;
    @Column(name = "onboarding_step") private int onboardingStep = 1;
    @Column(name = "deposit_percent") private BigDecimal depositPercent = BigDecimal.ZERO;
    @Column(name = "auto_confirm") private boolean autoConfirm = true;
    @Column(name = "min_notice_minutes") private int minNoticeMinutes = 60;
    @Column(name = "max_advance_days") private int maxAdvanceDays = 60;
    @Column(name = "payment_hold_minutes") private int paymentHoldMinutes = 15;
    @Column(name = "cancellation_deadline_hours") private int cancellationDeadlineHours = 24;
    @Column(name = "created_at", updatable = false) private Instant createdAt;
    @Column(name = "updated_at") private Instant updatedAt;

    @PrePersist void onCreate() { createdAt = updatedAt = Instant.now(); }
    @PreUpdate void onUpdate() { updatedAt = Instant.now(); }
}
