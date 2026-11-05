package com.orleu.payments;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.bookings.*;
import com.orleu.bookings.BookingDtos.BookingView;
import com.orleu.common.ApiException;
import com.orleu.common.Money;
import com.orleu.notifications.OutboxService;
import com.orleu.payments.PaymentDtos.MoneyRequest;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

/**
 * Manual payments and refunds recorded in the append-only ledger. Balances are always derived from
 * the ledger on the backend, never from client state. Provider-backed online payments (FreedomPay,
 * Kaspi, ...) are NOT implemented: they require provider credentials and verified webhooks.
 */
@Service
public class PaymentService {
    private final TenantAccess access;
    private final BookingRepository bookings;
    private final BookingService bookingService;
    private final BookingQueries queries;
    private final AuditService audit;
    private final JdbcClient jdbc;
    private final OutboxService outbox;

    public PaymentService(TenantAccess access, BookingRepository bookings, BookingService bookingService,
                          BookingQueries queries, AuditService audit, JdbcClient jdbc, OutboxService outbox) {
        this.access = access; this.bookings = bookings; this.bookingService = bookingService;
        this.queries = queries; this.audit = audit; this.jdbc = jdbc; this.outbox = outbox;
    }

    @Transactional
    public BookingView recordPayment(UUID businessId, UUID bookingId, String idempotencyKey, MoneyRequest r) {
        access.require(businessId, Permission.FINANCE_MANAGE);
        requireKey(idempotencyKey);
        lockBooking(businessId, bookingId);
        Booking b = bookings.findByIdAndBusinessId(bookingId, businessId).orElseThrow(() -> ApiException.notFound("Booking"));
        BigDecimal amount = Money.scale(r.amount());

        Optional<UUID[]> existing = replay(businessId, idempotencyKey, "PAYMENT", bookingId, amount);
        if (existing.isPresent()) return queries.find(businessId, bookingId).orElseThrow(); // idempotent replay

        if (b.getStatus() == BookingStatus.CANCELLED || b.getStatus() == BookingStatus.EXPIRED || b.getStatus() == BookingStatus.NO_SHOW) {
            throw ApiException.conflict("BOOKING_CLOSED", "Payments cannot be recorded for a " + b.getStatus() + " booking");
        }
        BigDecimal paid = sum(bookingId, "PAYMENT");
        BigDecimal refunded = sum(bookingId, "REFUND");
        BigDecimal remaining = b.getPrice().subtract(paid.subtract(refunded));
        if (amount.compareTo(remaining) > 0) {
            throw ApiException.conflict("OVERPAYMENT", "Amount exceeds the remaining balance of " + Money.scale(remaining));
        }
        insert(businessId, bookingId, "PAYMENT", amount, b.getCurrency(), r, idempotencyKey);
        outbox.publish(businessId, "PAYMENT_RECEIVED", bookingId, "PAYMENT_RECEIVED:" + idempotencyKey);

        BigDecimal net = paid.subtract(refunded).add(amount);
        if (b.getStatus() == BookingStatus.AWAITING_PAYMENT && net.compareTo(b.getDepositAmount()) >= 0) {
            bookingService.applyTransition(b, BookingStatus.CONFIRMED, CurrentUser.id(), "deposit received");
        }
        return queries.find(businessId, bookingId).orElseThrow();
    }

    @Transactional
    public BookingView recordRefund(UUID businessId, UUID bookingId, String idempotencyKey, MoneyRequest r) {
        access.require(businessId, Permission.FINANCE_MANAGE);
        requireKey(idempotencyKey);
        lockBooking(businessId, bookingId);
        Booking b = bookings.findByIdAndBusinessId(bookingId, businessId).orElseThrow(() -> ApiException.notFound("Booking"));
        BigDecimal amount = Money.scale(r.amount());
        if (replay(businessId, idempotencyKey, "REFUND", bookingId, amount).isPresent()) {
            return queries.find(businessId, bookingId).orElseThrow();
        }
        BigDecimal net = sum(bookingId, "PAYMENT").subtract(sum(bookingId, "REFUND"));
        if (amount.compareTo(net) > 0) {
            throw ApiException.conflict("REFUND_EXCEEDS_PAID", "Refund exceeds the amount currently paid (" + Money.scale(net) + ")");
        }
        insert(businessId, bookingId, "REFUND", amount, b.getCurrency(), r, idempotencyKey);
        audit.log(businessId, CurrentUser.id(), "REFUND_RECORDED", "BOOKING", bookingId, "{\"amount\":\"" + amount + "\"}");
        return queries.find(businessId, bookingId).orElseThrow();
    }

    // Serializes concurrent money operations on one booking.
    private void lockBooking(UUID businessId, UUID bookingId) {
        jdbc.sql("select id from bookings where id = :id and business_id = :b for update")
                .param("id", bookingId).param("b", businessId).query(UUID.class).optional()
                .orElseThrow(() -> ApiException.notFound("Booking"));
    }

    private Optional<UUID[]> replay(UUID businessId, String key, String type, UUID bookingId, BigDecimal amount) {
        return jdbc.sql("select booking_id, entry_type, amount from ledger_entries where business_id = :b and idempotency_key = :k")
                .param("b", businessId).param("k", key)
                .query((rs, i) -> {
                    if (!rs.getObject(1, UUID.class).equals(bookingId) || !rs.getString(2).equals(type)
                            || rs.getBigDecimal(3).compareTo(amount) != 0) {
                        throw ApiException.conflict("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used for a different operation");
                    }
                    return new UUID[]{bookingId};
                }).optional();
    }

    private void insert(UUID businessId, UUID bookingId, String type, BigDecimal amount, String currency, MoneyRequest r, String key) {
        try {
            jdbc.sql("""
                insert into ledger_entries (business_id, booking_id, entry_type, amount, currency, method, idempotency_key, provider_ref, created_by)
                values (:b, :bk, :t, :a, :c, :m, :k, :p, :u)
                """).param("b", businessId).param("bk", bookingId).param("t", type).param("a", amount).param("c", currency)
                .param("m", r.method().name()).param("k", key).param("p", r.providerRef(), java.sql.Types.VARCHAR)
                .param("u", CurrentUser.id()).update();
        } catch (DataIntegrityViolationException e) {
            throw ApiException.conflict("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used");
        }
        audit.log(businessId, CurrentUser.id(), "LEDGER_" + type, "BOOKING", bookingId, "{\"amount\":\"" + amount + "\"}");
    }

    private BigDecimal sum(UUID bookingId, String type) {
        return jdbc.sql("select coalesce(sum(amount), 0) from ledger_entries where booking_id = :id and entry_type = :t")
                .param("id", bookingId).param("t", type).query(BigDecimal.class).single();
    }

    private static void requireKey(String key) {
        if (key == null || key.isBlank() || key.length() > 100) {
            throw ApiException.badRequest("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header (1-100 chars) is required");
        }
    }
}
