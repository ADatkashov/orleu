package com.orleu.publicapi;

import com.orleu.bookings.Booking;
import com.orleu.bookings.BookingQueries;
import com.orleu.bookings.BookingService;
import com.orleu.business.Business;
import com.orleu.business.BusinessRepository;
import com.orleu.catalog.CatalogDtos.*;
import com.orleu.catalog.BranchRepository;
import com.orleu.catalog.EmployeeRepository;
import com.orleu.catalog.ServiceRepository;
import com.orleu.common.ApiException;
import com.orleu.customers.Customer;
import com.orleu.customers.CustomerDtos.CustomerInput;
import com.orleu.customers.CustomerService;
import com.orleu.scheduling.AvailabilityService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Unauthenticated guest booking. Only PUBLISHED businesses are visible; unpublished and unknown slugs
 * are indistinguishable (404). No endpoint here returns customer data or lets a caller list bookings.
 */
@RestController
@RequestMapping("/api/v1/public/businesses/{slug}")
public class PublicBookingController {
    public record PublicEmployee(UUID id, String displayName, List<UUID> branchIds, List<UUID> serviceIds) {}
    public record PublicProfile(String slug, String name, String description, String city, String address, String currency,
                                String timezone, List<BranchView> branches, List<ServiceView> services, List<PublicEmployee> employees) {}
    public record PublicBookingRequest(@NotNull UUID branchId, @NotNull UUID serviceId, UUID employeeId, @NotNull Instant startsAt,
                                       @Valid @NotNull CustomerInput customer) {}
    public record PublicBookingConfirmation(UUID bookingId, String status, Instant startsAt, BigDecimal price, BigDecimal depositAmount,
                                            BigDecimal remainingBalance, String currency, Instant holdExpiresAt) {}

    private final BusinessRepository businesses;
    private final BranchRepository branches;
    private final ServiceRepository services;
    private final AvailabilityService availability;
    private final CustomerService customerService;
    private final BookingService bookingService;
    private final JdbcClient jdbc;

    public PublicBookingController(BusinessRepository businesses, BranchRepository branches, ServiceRepository services,
                                   AvailabilityService availability, CustomerService customerService,
                                   BookingService bookingService, JdbcClient jdbc) {
        this.businesses = businesses; this.branches = branches; this.services = services;
        this.availability = availability; this.customerService = customerService;
        this.bookingService = bookingService; this.jdbc = jdbc;
    }

    @GetMapping
    public PublicProfile profile(@PathVariable String slug) {
        Business b = published(slug);
        var emps = jdbc.sql("select id, display_name from employees where business_id = :b and active order by display_name")
                .param("b", b.getId())
                .query((rs, i) -> {
                    UUID id = rs.getObject(1, UUID.class);
                    return new PublicEmployee(id, rs.getString(2),
                            jdbc.sql("select branch_id from employee_branches where employee_id = :e").param("e", id).query(UUID.class).list(),
                            jdbc.sql("select service_id from employee_services where employee_id = :e").param("e", id).query(UUID.class).list());
                }).list();
        return new PublicProfile(b.getSlug(), b.getName(), b.getDescription(), b.getCity(), b.getAddress(), b.getCurrency(), b.getTimezone(),
                branches.findByBusinessIdOrderByName(b.getId()).stream().filter(x -> x.isActive()).map(BranchView::of).toList(),
                services.findByBusinessIdAndActiveTrueAndOnlineBookableTrueOrderByName(b.getId()).stream().map(ServiceView::of).toList(),
                emps);
    }

    @GetMapping("/availability")
    public List<AvailabilityService.Slot> slots(@PathVariable String slug, @RequestParam UUID branchId, @RequestParam UUID serviceId,
                                                @RequestParam(required = false) UUID employeeId, @RequestParam LocalDate date) {
        Business b = published(slug);
        return availability.slots(b.getId(), branchId, serviceId, employeeId, date, Instant.now(), null, true);
    }

    @PostMapping("/bookings") @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public PublicBookingConfirmation book(@PathVariable String slug, @Valid @RequestBody PublicBookingRequest r) {
        Business b = published(slug);
        Customer customer = customerService.upsert(b.getId(), r.customer());
        Booking booking = bookingService.place(b.getId(), r.branchId(), r.serviceId(), r.employeeId(), customer, r.startsAt(),
                null, "PUBLIC", true);
        return new PublicBookingConfirmation(booking.getId(), booking.getStatus().name(), booking.getStartsAt(), booking.getPrice(),
                booking.getDepositAmount(), booking.getPrice(), booking.getCurrency(), booking.getHoldExpiresAt());
    }

    private Business published(String slug) {
        return businesses.findBySlug(slug).filter(Business::isPublished).orElseThrow(() -> ApiException.notFound("Business"));
    }
}
