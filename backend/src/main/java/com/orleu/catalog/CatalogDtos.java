package com.orleu.catalog;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

public final class CatalogDtos {
    private CatalogDtos() {}

    public record CreateBranchRequest(@NotBlank @Size(max = 200) String name, @Size(max = 300) String address,
                                      @Pattern(regexp = "^\\+[1-9][0-9]{7,14}$") String phone, @Size(max = 64) String timezone) {}
    /** hours is null (omitted from JSON) where not loaded, e.g. the public profile. */
    public record BranchView(UUID id, String name, String address, String phone, String timezone, boolean active, List<HourRange> hours) {
        public static BranchView of(Branch b) { return new BranchView(b.getId(), b.getName(), b.getAddress(), b.getPhone(), b.getTimezone(), b.isActive(), null); }
        public static BranchView of(Branch b, List<HourRange> hours) { return new BranchView(b.getId(), b.getName(), b.getAddress(), b.getPhone(), b.getTimezone(), b.isActive(), hours); }
    }

    public record HourRange(@Min(1) @Max(7) int dayOfWeek, @NotNull LocalTime open, @NotNull LocalTime close) {}
    public record SetHoursRequest(@NotNull @Size(max = 7) List<@Valid HourRange> hours) {}

    public record CreateServiceRequest(
            @NotBlank @Size(max = 200) String name, @Size(max = 2000) String description, @Size(max = 100) String category,
            @Min(5) @Max(1440) int durationMinutes, @Min(0) @Max(240) Integer bufferMinutes,
            @NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal price,
            @DecimalMin("0") @DecimalMax("100") BigDecimal depositPercent, Boolean onlineBookable) {}
    public record ServiceView(UUID id, String name, String description, String category, int durationMinutes,
                              int bufferMinutes, BigDecimal price, BigDecimal depositPercent, boolean onlineBookable, boolean active) {
        public static ServiceView of(ServiceOffering s) {
            return new ServiceView(s.getId(), s.getName(), s.getDescription(), s.getCategory(), s.getDurationMinutes(),
                    s.getBufferMinutes(), s.getPrice(), s.getDepositPercent(), s.isOnlineBookable(), s.isActive());
        }
    }

    public record CreateEmployeeRequest(@NotBlank @Size(max = 200) String displayName) {}
    public record AssignmentsRequest(@NotNull List<UUID> branchIds, @NotNull List<UUID> serviceIds) {}
    public record EmployeeView(UUID id, String displayName, boolean active, List<UUID> branchIds, List<UUID> serviceIds) {}

    public record TimeOffRequest(@NotNull Instant startsAt, @NotNull Instant endsAt, @Size(max = 200) String reason) {}
}
