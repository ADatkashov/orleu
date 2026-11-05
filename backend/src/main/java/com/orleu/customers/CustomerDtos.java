package com.orleu.customers;

import jakarta.validation.constraints.*;

import java.util.UUID;

public final class CustomerDtos {
    private CustomerDtos() {}

    public record CustomerInput(
            @NotBlank @Size(max = 200) String fullName,
            @NotBlank @Pattern(regexp = "^\\+[1-9][0-9]{7,14}$", message = "phone must be E.164, e.g. +77011234567") String phone,
            @Email @Size(max = 254) String email,
            @Size(max = 2000) String notes,
            Boolean marketingOptIn) {}

    public record CustomerView(UUID id, String fullName, String phone, String email, String notes,
                               boolean marketingOptIn, boolean blocked) {
        public static CustomerView of(Customer c) {
            return new CustomerView(c.getId(), c.getFullName(), c.getPhone(), c.getEmail(), c.getNotes(), c.isMarketingOptIn(), c.isBlocked());
        }
    }

    /** All fields optional: null = leave unchanged. The phone number is the customer's identity and cannot be edited. */
    public record UpdateCustomerRequest(@Size(min = 1, max = 200) String fullName, @Email @Size(max = 254) String email,
                                        @Size(max = 2000) String notes, Boolean marketingOptIn) {}

    public record BookingLine(UUID id, java.time.Instant startsAt, String serviceName, String employeeName, String status,
                              java.math.BigDecimal price, java.math.BigDecimal netPaid) {}

    /** Measured figures only. totalSpent is cash actually collected (payments minus refunds), not booked value. */
    public record CustomerStats(long totalBookings, long completedVisits, long cancelled, long noShows, long upcoming,
                                java.time.Instant lastVisit, java.math.BigDecimal totalSpent, java.math.BigDecimal averageSpendPerVisit) {}

    public record CustomerProfile(CustomerView customer, CustomerStats stats, java.util.List<BookingLine> bookings) {}

    public record PageView<T>(java.util.List<T> items, int page, int size, long total) {}
}
