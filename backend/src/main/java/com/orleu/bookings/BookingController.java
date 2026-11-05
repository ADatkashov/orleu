package com.orleu.bookings;

import com.orleu.bookings.BookingDtos.*;
import com.orleu.scheduling.AvailabilityService;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}")
public class BookingController {
    private final BookingService service;
    private final AvailabilityService availability;
    private final TenantAccess access;

    public BookingController(BookingService service, AvailabilityService availability, TenantAccess access) {
        this.service = service; this.availability = availability; this.access = access;
    }

    @GetMapping("/availability")
    public List<AvailabilityService.Slot> availability(@PathVariable UUID businessId, @RequestParam UUID branchId,
            @RequestParam UUID serviceId, @RequestParam(required = false) UUID employeeId, @RequestParam LocalDate date,
            @RequestParam(required = false) UUID excludeBookingId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        // excludeBookingId lets staff reschedule a booking into overlapping time of its own (only filters out that booking)
        return availability.slots(businessId, branchId, serviceId, employeeId, date, Instant.now(), excludeBookingId, false);
    }

    @PostMapping("/bookings") @ResponseStatus(HttpStatus.CREATED)
    public BookingView create(@PathVariable UUID businessId, @Valid @RequestBody CreateBookingRequest r) { return service.createByStaff(businessId, r); }

    @GetMapping("/bookings")
    public List<BookingView> list(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to,
                                  @RequestParam(required = false) UUID employeeId, @RequestParam(required = false) BookingStatus status) {
        return service.list(businessId, from, to, employeeId, status);
    }

    @GetMapping("/bookings/{bookingId}")
    public BookingView get(@PathVariable UUID businessId, @PathVariable UUID bookingId) { return service.get(businessId, bookingId); }

    @PostMapping("/bookings/{bookingId}/transition")
    public BookingView transition(@PathVariable UUID businessId, @PathVariable UUID bookingId, @Valid @RequestBody TransitionRequest r) {
        return service.transition(businessId, bookingId, r);
    }

    @PostMapping("/bookings/{bookingId}/reschedule")
    public BookingView reschedule(@PathVariable UUID businessId, @PathVariable UUID bookingId, @Valid @RequestBody RescheduleRequest r) {
        return service.reschedule(businessId, bookingId, r);
    }
}
