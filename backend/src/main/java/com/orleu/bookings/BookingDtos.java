package com.orleu.bookings;

import com.orleu.customers.CustomerDtos.CustomerInput;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BookingDtos {
    private BookingDtos() {}

    public record CreateBookingRequest(
            @NotNull UUID branchId, @NotNull UUID serviceId, UUID employeeId, @NotNull Instant startsAt,
            UUID customerId, @Valid CustomerInput customer, @Size(max = 2000) String notes) {}

    public record RescheduleRequest(@NotNull Instant startsAt, UUID employeeId) {}

    public record TransitionRequest(@NotNull BookingStatus status, @Size(max = 300) String reason) {}

    public record Financials(BigDecimal price, BigDecimal depositAmount, BigDecimal paid, BigDecimal refunded,
                             BigDecimal netPaid, BigDecimal remaining, String paymentStatus) {}

    public record BookingView(UUID id, UUID branchId, UUID serviceId, String serviceName, UUID employeeId, String employeeName,
                              UUID customerId, String customerName, String customerPhone, Instant startsAt, Instant endsAt,
                              BookingStatus status, String currency, String notes, Instant holdExpiresAt, Financials financials) {}
}
