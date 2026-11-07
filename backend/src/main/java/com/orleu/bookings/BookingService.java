package com.orleu.bookings;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.bookings.BookingDtos.*;
import com.orleu.business.Business;
import com.orleu.promo.PromoService;
import com.orleu.business.BusinessRepository;
import com.orleu.catalog.BranchRepository;
import com.orleu.catalog.EmployeeRepository;
import com.orleu.catalog.ServiceRepository;
import com.orleu.catalog.ServiceOffering;
import com.orleu.common.ApiException;
import com.orleu.common.Money;
import com.orleu.customers.Customer;
import com.orleu.customers.CustomerRepository;
import com.orleu.customers.CustomerService;
import com.orleu.notifications.OutboxService;
import com.orleu.scheduling.AvailabilityService;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.*;
import java.util.List;
import java.util.UUID;

@Service
public class BookingService {
    private final TenantAccess access;
    private final BookingRepository bookings;
    private final BusinessRepository businesses;
    private final ServiceRepository services;
    private final BranchRepository branches;
    private final CustomerRepository customers;
    private final CustomerService customerService;
    private final AvailabilityService availability;
    private final BookingQueries queries;
    private final AuditService audit;
    private final JdbcClient jdbc;
    private final OutboxService outbox;
    private final PromoService promos;

    public BookingService(TenantAccess access, BookingRepository bookings, BusinessRepository businesses,
                          ServiceRepository services, BranchRepository branches, CustomerRepository customers,
                          CustomerService customerService, AvailabilityService availability, BookingQueries queries,
                          AuditService audit, JdbcClient jdbc, OutboxService outbox, PromoService promos) {
        this.access = access; this.bookings = bookings; this.businesses = businesses; this.services = services;
        this.branches = branches; this.customers = customers; this.customerService = customerService;
        this.availability = availability; this.queries = queries; this.audit = audit; this.jdbc = jdbc; this.outbox = outbox; this.promos = promos;
    }

    // ---------- staff-facing ----------

    @Transactional
    public BookingView createByStaff(UUID businessId, CreateBookingRequest r) {
        access.require(businessId, Permission.BOOKINGS_MANAGE);
        Customer customer;
        if (r.customerId() != null) {
            customer = customers.findByIdAndBusinessId(r.customerId(), businessId).orElseThrow(() -> ApiException.notFound("Customer"));
        } else if (r.customer() != null) {
            customer = customerService.upsert(businessId, r.customer());
        } else {
            throw ApiException.badRequest("CUSTOMER_REQUIRED", "customerId or customer is required");
        }
        Booking b = place(businessId, r.branchId(), r.serviceId(), r.employeeId(), customer, r.startsAt(), r.notes(), "STAFF", false, r.promoCode());
        return queries.find(businessId, b.getId()).orElseThrow();
    }

    public List<BookingView> list(UUID businessId, Instant from, Instant to, UUID employeeId, BookingStatus status) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        if (!to.isAfter(from) || Duration.between(from, to).toDays() > 92) {
            throw ApiException.badRequest("INVALID_RANGE", "range must be positive and at most 92 days");
        }
        return queries.list(businessId, from, to, employeeId, status);
    }

    public BookingView get(UUID businessId, UUID bookingId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        return queries.find(businessId, bookingId).orElseThrow(() -> ApiException.notFound("Booking"));
    }

    @Transactional
    public BookingView transition(UUID businessId, UUID bookingId, TransitionRequest r) {
        access.require(businessId, Permission.BOOKINGS_MANAGE);
        Booking b = bookings.findByIdAndBusinessId(bookingId, businessId).orElseThrow(() -> ApiException.notFound("Booking"));
        BookingStatus target = r.status();
        if (target == BookingStatus.EXPIRED) {
            throw ApiException.badRequest("SYSTEM_TRANSITION", "EXPIRED is set by the system only");
        }
        if (b.getStatus() == BookingStatus.AWAITING_PAYMENT && target == BookingStatus.CONFIRMED) {
            throw ApiException.conflict("PAYMENT_REQUIRED", "A booking awaiting payment is confirmed by recording the deposit");
        }
        applyTransition(b, target, CurrentUser.id(), r.reason());
        return queries.find(businessId, bookingId).orElseThrow();
    }

    @Transactional
    public BookingView reschedule(UUID businessId, UUID bookingId, RescheduleRequest r) {
        access.require(businessId, Permission.BOOKINGS_MANAGE);
        Booking b = bookings.findByIdAndBusinessId(bookingId, businessId).orElseThrow(() -> ApiException.notFound("Booking"));
        if (b.getStatus() != BookingStatus.PENDING && b.getStatus() != BookingStatus.AWAITING_PAYMENT && b.getStatus() != BookingStatus.CONFIRMED) {
            throw ApiException.conflict("NOT_RESCHEDULABLE", "Only pending or confirmed bookings can be rescheduled");
        }
        ServiceOffering svc = services.findByIdAndBusinessId(b.getServiceId(), businessId).orElseThrow();
        UUID employee = pickEmployee(businessId, b.getBranchId(), b.getServiceId(),
                r.employeeId() != null ? r.employeeId() : b.getEmployeeId(), r.startsAt(), b.getId(), false);
        Instant end = r.startsAt().plus(Duration.ofMinutes(svc.getDurationMinutes()));
        b.setEmployeeId(employee);
        b.setStartsAt(r.startsAt());
        b.setEndsAt(end);
        b.setBlockedUntil(end.plus(Duration.ofMinutes(svc.getBufferMinutes())));
        try {
            bookings.saveAndFlush(b);
        } catch (DataIntegrityViolationException e) {
            throw slotTaken();
        }
        audit.log(businessId, CurrentUser.id(), "BOOKING_RESCHEDULED", "BOOKING", bookingId, null);
        outbox.publish(businessId, "BOOKING_RESCHEDULED", bookingId, "BOOKING_RESCHEDULED:" + bookingId + ":" + r.startsAt().toEpochMilli());
        return queries.find(businessId, bookingId).orElseThrow();
    }

    // ---------- shared core (also used by the public booking flow) ----------

    /**
     * Validates the slot and creates the booking in one transaction. The conflict check here decides
     * what to offer; the DB exclusion constraint is the final arbiter if two requests race.
     */
    @Transactional
    public Booking place(UUID businessId, UUID branchId, UUID serviceId, UUID employeeId, Customer customer,
                         Instant startsAt, String notes, String source, boolean applyOnlineRules, String promoCode) {
        Business biz = businesses.findById(businessId).orElseThrow(() -> ApiException.notFound("Business"));
        branches.findByIdAndBusinessId(branchId, businessId).filter(x -> x.isActive()).orElseThrow(() -> ApiException.notFound("Branch"));
        ServiceOffering svc = services.findByIdAndBusinessId(serviceId, businessId).filter(ServiceOffering::isActive)
                .orElseThrow(() -> ApiException.notFound("Service"));
        if (applyOnlineRules && !svc.isOnlineBookable()) throw ApiException.notFound("Service");
        if (customer.isBlocked()) throw ApiException.forbidden();

        UUID chosen = pickEmployee(businessId, branchId, serviceId, employeeId, startsAt, null, applyOnlineRules);

        BigDecimal listPrice = Money.scale(svc.getPrice());
        PromoService.Applied promo = promoCode == null || promoCode.isBlank() ? null : promos.preview(businessId, promoCode, serviceId, listPrice);
        BigDecimal price = promo != null ? promo.finalPrice() : listPrice;
        BigDecimal pct = svc.getDepositPercent() != null ? svc.getDepositPercent() : biz.getDepositPercent();
        BigDecimal deposit = Money.percentOf(price, pct);

        Booking b = new Booking();
        b.setBusinessId(businessId);
        b.setBranchId(branchId);
        b.setServiceId(serviceId);
        b.setEmployeeId(chosen);
        b.setCustomerId(customer.getId());
        b.setStartsAt(startsAt);
        b.setEndsAt(startsAt.plus(Duration.ofMinutes(svc.getDurationMinutes())));
        b.setBlockedUntil(b.getEndsAt().plus(Duration.ofMinutes(svc.getBufferMinutes())));
        b.setPrice(price);
        b.setDepositAmount(deposit);
        if (promo != null) { b.setPromoCodeId(promo.promoId()); b.setDiscountAmount(promo.discount()); }
        b.setCurrency(biz.getCurrency());
        b.setNotes(notes);
        b.setSource(source);
        String rawToken = newToken();
        b.setManageTokenHash(hashToken(rawToken));
        if (deposit.signum() > 0) {
            b.setStatus(BookingStatus.AWAITING_PAYMENT);
            b.setHoldExpiresAt(Instant.now().plus(Duration.ofMinutes(biz.getPaymentHoldMinutes())));
        } else {
            b.setStatus(biz.isAutoConfirm() ? BookingStatus.CONFIRMED : BookingStatus.PENDING);
        }
        try {
            bookings.saveAndFlush(b);
        } catch (DataIntegrityViolationException e) {
            throw slotTaken();
        }
        if (promo != null) promos.redeem(businessId, promo.promoId()); // atomic; a failure rolls the whole booking back
        b.setRawManageToken(rawToken);
        history(businessId, b.getId(), null, b.getStatus(), "PUBLIC".equals(source) ? null : CurrentUser.id(), null);
        outbox.publish(businessId, "BOOKING_CREATED", b.getId(), "BOOKING_CREATED:" + b.getId());
        audit.log(businessId, "PUBLIC".equals(source) ? null : CurrentUser.id(), "BOOKING_CREATED", "BOOKING", b.getId(), null);
        return b;
    }

    /** Validates that startsAt is an offered slot and returns the employee to use. */
    private UUID pickEmployee(UUID businessId, UUID branchId, UUID serviceId, UUID employeeId, Instant startsAt,
                              UUID excludeBookingId, boolean applyOnlineRules) {
        ZoneId zone = ZoneId.of(jdbc.sql("select timezone from branches where id = :id and business_id = :b")
                .param("id", branchId).param("b", businessId).query(String.class).single());
        LocalDate date = startsAt.atZone(zone).toLocalDate();
        var slots = availability.slots(businessId, branchId, serviceId, employeeId, date, Instant.now(), excludeBookingId, applyOnlineRules);
        return slots.stream().filter(s -> s.start().equals(startsAt)).findFirst()
                .map(s -> s.employeeIds().get(0))
                .orElseThrow(BookingService::slotTaken);
    }

    /** Applies a validated status change and records history. Callers must already be authorized. */
    @Transactional
    public void applyTransition(Booking b, BookingStatus target, UUID actor, String reason) {
        BookingStatus from = b.getStatus();
        if (!from.canTransitionTo(target)) {
            throw ApiException.conflict("INVALID_TRANSITION", "Cannot change booking from " + from + " to " + target);
        }
        b.setStatus(target);
        if (target != BookingStatus.AWAITING_PAYMENT) b.setHoldExpiresAt(null);
        bookings.saveAndFlush(b);
        history(b.getBusinessId(), b.getId(), from, target, actor, reason);
        outbox.publish(b.getBusinessId(), "BOOKING_" + target, b.getId(), "BOOKING_" + target + ":" + b.getId());
        audit.log(b.getBusinessId(), actor, "BOOKING_" + target, "BOOKING", b.getId(), null);
    }

    /** Releases unpaid holds. Idempotent and safe to run on several instances. */
    @Transactional
    public int expireStaleHolds() {
        List<UUID[]> expired = jdbc.sql("""
                update bookings set status = 'EXPIRED', hold_expires_at = null, updated_at = now(), version = version + 1
                where status = 'AWAITING_PAYMENT' and hold_expires_at < now()
                returning id, business_id
                """).query((rs, i) -> new UUID[]{rs.getObject(1, UUID.class), rs.getObject(2, UUID.class)}).list();
        for (UUID[] e : expired) {
            history(e[1], e[0], BookingStatus.AWAITING_PAYMENT, BookingStatus.EXPIRED, null, "payment hold expired");
            outbox.publish(e[1], "BOOKING_EXPIRED", e[0], "BOOKING_EXPIRED:" + e[0]);
        }
        return expired.size();
    }

    // ---------- customer self-service (secret link) ----------

    public record ManageView(String businessName, String serviceName, java.time.Instant startsAt, BookingStatus status,
                             BigDecimal price, BigDecimal depositAmount, BigDecimal remainingBalance, String currency,
                             boolean canCancel, Instant cancelUntil,
                             boolean canReview, Integer reviewRating, String businessReply) {}

    @Transactional(readOnly = true)
    public ManageView manageView(String rawToken) {
        Booking b = byToken(rawToken);
        return view(b);
    }

    /** Portal: a booking of exactly this customer in exactly this business (404 otherwise), in the same view the secret link gives. */
    @Transactional(readOnly = true)
    public ManageView manageViewFor(UUID businessId, UUID customerId, UUID bookingId) {
        return view(ownBooking(businessId, customerId, bookingId));
    }

    /** Portal: same rules as the secret link (free-cancellation window, idempotent). */
    @Transactional
    public ManageView cancelByCustomerFor(UUID businessId, UUID customerId, UUID bookingId) {
        return cancel(ownBooking(businessId, customerId, bookingId));
    }

    private Booking ownBooking(UUID businessId, UUID customerId, UUID bookingId) {
        Booking b = bookings.findByIdAndBusinessId(bookingId, businessId).orElseThrow(() -> ApiException.notFound("Booking"));
        if (!b.getCustomerId().equals(customerId)) throw ApiException.notFound("Booking");
        return b;
    }

    /** The customer cancels via the secret link. Allowed until the business's cancellation deadline. */
    @Transactional
    public ManageView cancelByCustomer(String rawToken) {
        return cancel(byToken(rawToken));
    }

    private ManageView cancel(Booking b) {
        ManageView v = view(b);
        if (b.getStatus() == BookingStatus.CANCELLED) return v; // idempotent
        if (!v.canCancel()) {
            throw ApiException.conflict("CANCELLATION_NOT_ALLOWED", b.getStatus().isActive()
                    ? "The free-cancellation window has passed; please contact the business" : "This booking can no longer be cancelled");
        }
        applyTransition(b, BookingStatus.CANCELLED, null, "cancelled by customer");
        return view(b);
    }

    private ManageView view(Booking b) {
        Business biz = businesses.findById(b.getBusinessId()).orElseThrow();
        String svc = services.findByIdAndBusinessId(b.getServiceId(), b.getBusinessId()).map(ServiceOffering::getName).orElse("");
        BigDecimal paid = jdbc.sql("select coalesce(sum(case when entry_type='PAYMENT' then amount else -amount end),0) from ledger_entries where booking_id = :id")
                .param("id", b.getId()).query(BigDecimal.class).single();
        Instant cancelUntil = b.getStartsAt().minus(Duration.ofHours(biz.getCancellationDeadlineHours()));
        boolean open = b.getStatus() == BookingStatus.PENDING || b.getStatus() == BookingStatus.AWAITING_PAYMENT || b.getStatus() == BookingStatus.CONFIRMED;
        boolean canCancel = open && (b.getStatus() == BookingStatus.AWAITING_PAYMENT || Instant.now().isBefore(cancelUntil));
        var review = jdbc.sql("select rating, case when hidden then null else reply end from reviews where booking_id = :id").param("id", b.getId())
                .query((rs, i) -> new Object[]{rs.getInt(1), rs.getString(2)}).optional().orElse(null);
        Integer rating = review == null ? null : (Integer) review[0];
        String reply = review == null ? null : (String) review[1];
        return new ManageView(biz.getName(), svc, b.getStartsAt(), b.getStatus(), b.getPrice(), b.getDepositAmount(),
                Money.scale(b.getPrice().subtract(paid).max(BigDecimal.ZERO)), b.getCurrency(), canCancel, cancelUntil,
                b.getStatus() == BookingStatus.COMPLETED && rating == null, rating, reply);
    }

    private Booking byToken(String raw) {
        if (raw == null || raw.length() < 20 || raw.length() > 100) throw ApiException.notFound("Booking");
        return bookings.findByManageTokenHash(hashToken(raw)).orElseThrow(() -> ApiException.notFound("Booking"));
    }

    private static final java.security.SecureRandom RANDOM = new java.security.SecureRandom();

    private static String newToken() {
        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
    }

    public static String hashToken(String token) {
        try {
            return java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    private void history(UUID businessId, UUID bookingId, BookingStatus from, BookingStatus to, UUID actor, String reason) {
        jdbc.sql("""
                insert into booking_status_history (business_id, booking_id, from_status, to_status, actor_user_id, reason)
                values (:b, :id, :f, :t, :a, :r)
                """).param("b", businessId).param("id", bookingId).param("f", from == null ? null : from.name(), java.sql.Types.VARCHAR)
                .param("t", to.name()).param("a", actor, java.sql.Types.OTHER).param("r", reason, java.sql.Types.VARCHAR).update();
    }

    private static ApiException slotTaken() {
        return ApiException.conflict("SLOT_UNAVAILABLE", "This time is no longer available");
    }
}
