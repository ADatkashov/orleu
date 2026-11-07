package com.orleu.payments;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.bookings.BookingDtos.BookingView;
import com.orleu.common.ApiException;
import com.orleu.common.Money;
import com.orleu.payments.PaymentDtos.Method;
import com.orleu.payments.PaymentDtos.MoneyRequest;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Four-eyes control for refunds. With a threshold set, a refund above it recorded by a user without REFUND_APPROVE waits as a PENDING
 * request; an approver (owner/admin) then approves (the refund is recorded in the ledger, re-validated against what is paid at that moment)
 * or rejects it. Holders of REFUND_APPROVE and refunds at or below the threshold are recorded immediately.
 */
@Service
public class RefundRequestService {
    public record Outcome(BookingView booking, RefundRequestView request) {}
    public record RefundRequestView(UUID id, UUID bookingId, BigDecimal amount, String currency, Method method, String status,
                                    UUID requestedBy, String requestedByName, UUID decidedBy, Instant decidedAt, String decisionNote, Instant createdAt) {}
    public record Policy(BigDecimal threshold) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final PaymentService payments;
    private final AuditService audit;

    public RefundRequestService(TenantAccess access, JdbcClient jdbc, PaymentService payments, AuditService audit) {
        this.access = access; this.jdbc = jdbc; this.payments = payments; this.audit = audit;
    }

    public Policy policy(UUID businessId) {
        access.require(businessId, Permission.FINANCE_VIEW);
        return new Policy(threshold(businessId));
    }

    @Transactional
    public Policy setPolicy(UUID businessId, BigDecimal threshold) {
        access.require(businessId, Permission.BUSINESS_MANAGE);
        if (threshold != null && threshold.signum() < 0) throw ApiException.badRequest("INVALID_THRESHOLD", "The threshold cannot be negative");
        BigDecimal t = threshold == null ? null : Money.scale(threshold);
        jdbc.sql("update businesses set refund_approval_threshold = :t where id = :b").param("t", t, java.sql.Types.NUMERIC).param("b", businessId).update();
        audit.log(businessId, CurrentUser.id(), "REFUND_POLICY_SET", "BUSINESS", businessId, "{\"threshold\":" + (t == null ? "null" : "\"" + t + "\"") + "}");
        return new Policy(t);
    }

    private BigDecimal threshold(UUID businessId) {
        return jdbc.sql("select refund_approval_threshold from businesses where id = :b").param("b", businessId).query(BigDecimal.class).optional().orElse(null);
    }

    /** Records the refund now, or parks it as a pending request when the policy requires approval. */
    @Transactional
    public Outcome submit(UUID businessId, UUID bookingId, String idempotencyKey, MoneyRequest r) {
        access.require(businessId, Permission.FINANCE_MANAGE);
        BigDecimal amount = Money.scale(r.amount());
        BigDecimal threshold = threshold(businessId);
        boolean needsApproval = threshold != null && amount.compareTo(threshold) > 0 && !access.has(businessId, Permission.REFUND_APPROVE);
        if (!needsApproval) return new Outcome(payments.recordRefund(businessId, bookingId, idempotencyKey, r), null);

        if (idempotencyKey == null || idempotencyKey.isBlank() || idempotencyKey.length() > 100) {
            throw ApiException.badRequest("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header (1-100 chars) is required");
        }
        // lock the booking row so concurrent submits for it are serialised, then validate against what is paid right now
        var booking = jdbc.sql("select currency from bookings where id = :id and business_id = :b for update").param("id", bookingId).param("b", businessId).query(String.class).optional()
                .orElseThrow(() -> ApiException.notFound("Booking"));
        var existing = jdbc.sql("select id, booking_id, amount from refund_requests where business_id = :b and idempotency_key = :k").param("b", businessId).param("k", idempotencyKey)
                .query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getBigDecimal(3)}).optional();
        if (existing.isPresent()) {
            Object[] e = existing.get();
            if (!e[1].equals(bookingId) || ((BigDecimal) e[2]).compareTo(amount) != 0) throw ApiException.conflict("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used for a different operation");
            return new Outcome(null, view(businessId, (UUID) e[0]));
        }
        BigDecimal net = payments.refundable(bookingId);
        if (amount.compareTo(net) > 0) throw ApiException.conflict("REFUND_EXCEEDS_PAID", "Refund exceeds the amount that can be paid back in money (" + Money.scale(net) + ")");
        UUID id = jdbc.sql("""
            insert into refund_requests (business_id, booking_id, amount, currency, method, provider_ref, idempotency_key, requested_by)
            values (:b, :bk, :a, :c, :m, :p, :k, :u) returning id
            """).param("b", businessId).param("bk", bookingId).param("a", amount).param("c", booking).param("m", r.method().name())
                .param("p", r.providerRef(), java.sql.Types.VARCHAR).param("k", idempotencyKey).param("u", CurrentUser.id()).query(UUID.class).single();
        audit.log(businessId, CurrentUser.id(), "REFUND_REQUESTED", "BOOKING", bookingId, "{\"amount\":\"" + amount + "\",\"request\":\"" + id + "\"}");
        return new Outcome(null, view(businessId, id));
    }

    public List<RefundRequestView> list(UUID businessId, String status) {
        access.require(businessId, Permission.FINANCE_VIEW);
        String s = status == null || status.isBlank() ? null : status.trim().toUpperCase();
        if (s != null && !List.of("PENDING", "APPROVED", "REJECTED").contains(s)) throw ApiException.badRequest("INVALID_STATUS", "status must be PENDING, APPROVED or REJECTED");
        return jdbc.sql(SELECT + " where r.business_id = :b and (cast(:s as varchar) is null or r.status = :s) order by r.created_at desc limit 200")
                .param("b", businessId).param("s", s, java.sql.Types.VARCHAR).query(MAPPER).list();
    }

    @Transactional
    public RefundRequestView approve(UUID businessId, UUID requestId) {
        access.require(businessId, Permission.REFUND_APPROVE);
        var row = lockPending(businessId, requestId);
        if (row.requestedBy().equals(CurrentUser.id())) throw ApiException.conflict("SELF_APPROVAL", "A refund request cannot be approved by the person who made it");
        payments.recordApprovedRefund(businessId, row.bookingId(), "refund-request-" + requestId,
                new MoneyRequest(row.amount(), row.method(), row.providerRef()));
        jdbc.sql("update refund_requests set status = 'APPROVED', decided_by = :u, decided_at = now() where id = :id and business_id = :b").param("u", CurrentUser.id()).param("id", requestId).param("b", businessId).update();
        audit.log(businessId, CurrentUser.id(), "REFUND_REQUEST_APPROVED", "BOOKING", row.bookingId(), "{\"request\":\"" + requestId + "\"}");
        return view(businessId, requestId);
    }

    @Transactional
    public RefundRequestView reject(UUID businessId, UUID requestId, String note) {
        access.require(businessId, Permission.REFUND_APPROVE);
        var row = lockPending(businessId, requestId);
        String n = note == null || note.isBlank() ? null : note.trim();
        if (n != null && n.length() > 500) throw ApiException.badRequest("NOTE_TOO_LONG", "The note is limited to 500 characters");
        jdbc.sql("update refund_requests set status = 'REJECTED', decided_by = :u, decided_at = now(), decision_note = :n where id = :id and business_id = :b")
                .param("u", CurrentUser.id()).param("n", n, java.sql.Types.VARCHAR).param("id", requestId).param("b", businessId).update();
        audit.log(businessId, CurrentUser.id(), "REFUND_REQUEST_REJECTED", "BOOKING", row.bookingId(), "{\"request\":\"" + requestId + "\"}");
        return view(businessId, requestId);
    }

    private record Pending(UUID bookingId, BigDecimal amount, Method method, String providerRef, UUID requestedBy) {}

    /** Row-locks the request so two approvers cannot decide it twice; a decided request is a 409. */
    private Pending lockPending(UUID businessId, UUID requestId) {
        var row = jdbc.sql("select booking_id, amount, method, provider_ref, requested_by, status from refund_requests where id = :id and business_id = :b for update")
                .param("id", requestId).param("b", businessId)
                .query((rs, i) -> new Object[]{new Pending(rs.getObject(1, UUID.class), rs.getBigDecimal(2), Method.valueOf(rs.getString(3)), rs.getString(4), rs.getObject(5, UUID.class)), rs.getString(6)})
                .optional().orElseThrow(() -> ApiException.notFound("Refund request"));
        if (!"PENDING".equals(row[1])) throw ApiException.conflict("ALREADY_DECIDED", "This refund request was already " + row[1]);
        return (Pending) row[0];
    }

    private static final String SELECT = """
        select r.id, r.booking_id, r.amount, r.currency, r.method, r.status, r.requested_by, u.full_name, r.decided_by, r.decided_at, r.decision_note, r.created_at
        from refund_requests r left join users u on u.id = r.requested_by
        """;
    private static final org.springframework.jdbc.core.RowMapper<RefundRequestView> MAPPER = (rs, i) -> new RefundRequestView(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class),
            rs.getBigDecimal(3), rs.getString(4), Method.valueOf(rs.getString(5)), rs.getString(6), rs.getObject(7, UUID.class), rs.getString(8), rs.getObject(9, UUID.class),
            rs.getTimestamp(10) == null ? null : rs.getTimestamp(10).toInstant(), rs.getString(11), rs.getTimestamp(12).toInstant());

    private RefundRequestView view(UUID businessId, UUID id) {
        return jdbc.sql(SELECT + " where r.id = :id and r.business_id = :b").param("id", id).param("b", businessId).query(MAPPER).single();
    }
}
