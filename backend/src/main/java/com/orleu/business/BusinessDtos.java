package com.orleu.business;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.util.UUID;

public final class BusinessDtos {
    private BusinessDtos() {}

    public record CreateBusinessRequest(
            @NotBlank @Size(max = 200) String name,
            @NotBlank @Pattern(regexp = "^[a-z0-9]+(-[a-z0-9]+)*$", message = "slug: lowercase letters, digits and hyphens") @Size(min = 3, max = 60) String slug,
            @NotBlank @Pattern(regexp = "^[A-Z_]{3,40}$", message = "businessType must be UPPER_SNAKE_CASE, e.g. BARBERSHOP") String businessType,
            @Size(max = 2000) String description,
            @Pattern(regexp = "^[A-Z]{2}$") String country,
            @Size(max = 100) String city,
            @Size(max = 300) String address,
            @Pattern(regexp = "^\\+[1-9][0-9]{7,14}$") String phone,
            @Pattern(regexp = "^[A-Z]{3}$") String currency,
            @Size(max = 64) String timezone) {}

    public record UpdateSettingsRequest(
            @Size(max = 200) String name,
            @Size(max = 2000) String description,
            @Size(max = 100) String city,
            @Size(max = 300) String address,
            @DecimalMin("0") @DecimalMax("100") BigDecimal depositPercent,
            Boolean autoConfirm,
            @Min(0) @Max(10080) Integer minNoticeMinutes,
            @Min(1) @Max(730) Integer maxAdvanceDays,
            @Min(1) @Max(1440) Integer paymentHoldMinutes,
            @Min(0) @Max(720) Integer cancellationDeadlineHours,
            @Min(0) @Max(168) Integer reminderHours,
            @Pattern(regexp = "kk|ru|en") String customerLocale) {}

    public record BusinessView(UUID id, String slug, String name, String businessType, String description,
                               String country, String city, String address, String currency, String timezone,
                               String planCode, boolean published, int onboardingStep, BigDecimal depositPercent,
                               boolean autoConfirm, int minNoticeMinutes, int maxAdvanceDays, int paymentHoldMinutes,
                               int cancellationDeadlineHours, int reminderHours, String customerLocale) {
        public static BusinessView of(Business b) {
            return new BusinessView(b.getId(), b.getSlug(), b.getName(), b.getBusinessType(), b.getDescription(),
                    b.getCountry(), b.getCity(), b.getAddress(), b.getCurrency(), b.getTimezone(), b.getPlanCode(),
                    b.isPublished(), b.getOnboardingStep(), b.getDepositPercent(), b.isAutoConfirm(),
                    b.getMinNoticeMinutes(), b.getMaxAdvanceDays(), b.getPaymentHoldMinutes(), b.getCancellationDeadlineHours(),
                    b.getReminderHours(), b.getCustomerLocale());
        }
    }

    public record AddMemberRequest(@NotBlank @Email String email, @NotNull com.orleu.tenancy.BusinessRole role) {}

    public record MemberView(UUID userId, String email, String fullName, String role, String status) {}
}
