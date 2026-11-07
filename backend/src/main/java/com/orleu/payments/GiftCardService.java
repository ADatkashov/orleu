package com.orleu.payments;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.bookings.BookingDtos.BookingView;
import com.orleu.common.ApiException;
import com.orleu.common.Money;
import com.orleu.payments.PaymentDtos.Method;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

/**
 * Prepaid gift cards. Selling one takes money (recorded here, counted in the cash register closing) but is a liability, not revenue and not a booking payment.
 * Redeeming writes a PAYMENT with method GIFT_CARD to the ledger, so booking balances and reports work unchanged. The code is shown ONCE at sale and stored as a hash.
 * The balance is reduced by an atomic conditional UPDATE, so concurrent redemptions can never overspend a card.
 * Not built: restoring value to a card on refund (gift-card value is never paid out in cash), transfers, top-ups, partial voids, expiry rules (legal input needed).
 */
@Service
public class GiftCardService {
    public record CardView(UUID id, String codeLast4, BigDecimal initialAmount, BigDecimal balance, String currency, String soldMethod, String buyerName, String note,
                           LocalDate expiresOn, boolean expired, String status, Instant createdAt) {}
    public record Sold(CardView card, String code, boolean codeShown) {}

    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final BigDecimal MAX = new BigDecimal("10000000");

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;
    private final PaymentService payments;

    public GiftCardService(TenantAccess access, JdbcClient jdbc, AuditService audit, PaymentService payments) {
        this.access = access; this.jdbc = jdbc; this.audit = audit; this.payments = payments;
    }

    static String normalize(String code) { return code == null ? "" : code.toUpperCase().replaceAll("[^A-Z0-9]", ""); }

    static String hash(String normalized) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(normalized.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    private static String newCode() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 12; i++) { if (i > 0 && i % 4 == 0) sb.append('-'); sb.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length()))); }
        return sb.toString();
    }

    private static final String SELECT = """
        select id, code_last4, initial_amount, balance, currency, sold_method, buyer_name, note, expires_on, status, created_at,
               (expires_on is not null and expires_on < (now() at time zone :tz)::date) as expired
        from gift_cards
        """;

    private CardView map(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new CardView(rs.getObject(1, UUID.class), rs.getString(2), rs.getBigDecimal(3), rs.getBigDecimal(4), rs.getString(5), rs.getString(6), rs.getString(7), rs.getString(8),
                rs.getObject(9, LocalDate.class), rs.getBoolean(12), rs.getString(10), rs.getTimestamp(11).toInstant());
    }

    private String tz(UUID businessId) { return jdbc.sql("select timezone from businesses where id = :b").param("b", businessId).query(String.class).single(); }

    @Transactional
    public Sold sell(UUID businessId, String idempotencyKey, BigDecimal amount, Method method, String buyerName, String note, LocalDate expiresOn) {
        access.require(businessId, Permission.FINANCE_MANAGE);
        if (idempotencyKey == null || idempotencyKey.isBlank() || idempotencyKey.length() > 100) throw ApiException.badRequest("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header (1-100 chars) is required");
        BigDecimal a = Money.scale(amount);
        if (a.signum() <= 0 || a.compareTo(MAX) > 0) throw ApiException.badRequest("INVALID_AMOUNT", "The amount must be between 0.01 and 10,000,000");
        String tz = tz(businessId);
        if (expiresOn != null && expiresOn.isBefore(LocalDate.now(ZoneId.of(tz)))) throw ApiException.badRequest("INVALID_EXPIRY", "The expiry date is in the past");
        var existing = jdbc.sql(SELECT + " where business_id = :b and idempotency_key = :k").param("tz", tz).param("b", businessId).param("k", idempotencyKey).query((rs, i) -> map(rs)).optional();
        if (existing.isPresent()) {
            if (existing.get().initialAmount().compareTo(a) != 0) throw ApiException.conflict("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used for a different operation");
            return new Sold(existing.get(), null, false); // the code was shown to the first caller only; it cannot be recovered
        }
        String code = null, h = null;
        for (int attempt = 0; attempt < 5 && code == null; attempt++) {
            String c = newCode();
            String ch = hash(normalize(c));
            boolean taken = jdbc.sql("select exists(select 1 from gift_cards where business_id = :b and code_hash = :h)").param("b", businessId).param("h", ch).query(Boolean.class).single();
            if (!taken) { code = c; h = ch; }
        }
        if (code == null) throw new IllegalStateException("could not generate a unique gift card code");
        String currency = jdbc.sql("select currency from businesses where id = :b").param("b", businessId).query(String.class).single();
        String last4 = normalize(code).substring(8);
        UUID id;
        try {
            id = jdbc.sql("""
                insert into gift_cards (business_id, code_hash, code_last4, initial_amount, balance, currency, sold_method, buyer_name, note, idempotency_key, expires_on, created_by)
                values (:b, :h, :l, :a, :a, :c, :m, :bn, :n, :k, :e, :u) returning id
                """).param("b", businessId).param("h", h).param("l", last4).param("a", a).param("c", currency).param("m", method.name())
                    .param("bn", blank(buyerName), java.sql.Types.VARCHAR).param("n", blank(note), java.sql.Types.VARCHAR).param("k", idempotencyKey)
                    .param("e", expiresOn, java.sql.Types.DATE).param("u", CurrentUser.id()).query(UUID.class).single();
        } catch (DataIntegrityViolationException e) {
            throw ApiException.conflict("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used");
        }
        audit.log(businessId, CurrentUser.id(), "GIFT_CARD_SOLD", "GIFT_CARD", id, "{\"amount\":\"" + a + "\",\"method\":\"" + method.name() + "\"}");
        return new Sold(one(businessId, id), code, true);
    }

    private static String blank(String s) {
        if (s == null || s.isBlank()) return null;
        String t = s.strip();
        return t.length() > 300 ? t.substring(0, 300) : t;
    }

    private CardView one(UUID businessId, UUID id) {
        return jdbc.sql(SELECT + " where business_id = :b and id = :id").param("tz", tz(businessId)).param("b", businessId).param("id", id).query((rs, i) -> map(rs)).single();
    }

    @Transactional(readOnly = true)
    public List<CardView> list(UUID businessId) {
        access.require(businessId, Permission.FINANCE_VIEW);
        return jdbc.sql(SELECT + " where business_id = :b order by created_at desc limit 200").param("tz", tz(businessId)).param("b", businessId).query((rs, i) -> map(rs)).list();
    }

    /** Balance check by code. Generic 404 for anything unknown; staff only (the code is a bearer secret). */
    @Transactional(readOnly = true)
    public CardView lookup(UUID businessId, String code) {
        access.require(businessId, Permission.FINANCE_MANAGE);
        String n = normalize(code);
        if (n.length() != 12) throw ApiException.notFound("Gift card");
        return jdbc.sql(SELECT + " where business_id = :b and code_hash = :h").param("tz", tz(businessId)).param("b", businessId).param("h", hash(n)).query((rs, i) -> map(rs)).optional()
                .orElseThrow(() -> ApiException.notFound("Gift card"));
    }

    /** Voids a card (lost, fraud, refunded outside the system). Owner/admin only: it destroys customer value. The remaining balance is kept on record. */
    @Transactional
    public CardView voidCard(UUID businessId, UUID id) {
        access.require(businessId, Permission.REFUND_APPROVE);
        int n = jdbc.sql("update gift_cards set status = 'VOID', voided_by = :u, voided_at = now() where id = :id and business_id = :b and status = 'ACTIVE'")
                .param("u", CurrentUser.id()).param("id", id).param("b", businessId).update();
        if (n == 0) {
            boolean exists = jdbc.sql("select exists(select 1 from gift_cards where id = :id and business_id = :b)").param("id", id).param("b", businessId).query(Boolean.class).single();
            if (!exists) throw ApiException.notFound("Gift card");
        } else {
            audit.log(businessId, CurrentUser.id(), "GIFT_CARD_VOIDED", "GIFT_CARD", id, null);
        }
        return one(businessId, id);
    }

    @Transactional
    public BookingView redeem(UUID businessId, UUID bookingId, String idempotencyKey, String code, BigDecimal amount) {
        access.require(businessId, Permission.FINANCE_MANAGE);
        if (idempotencyKey == null || idempotencyKey.isBlank() || idempotencyKey.length() > 100) throw ApiException.badRequest("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header (1-100 chars) is required");
        BigDecimal a = Money.scale(amount);
        if (a.signum() <= 0) throw ApiException.badRequest("INVALID_AMOUNT", "The amount must be positive");
        String n = normalize(code);
        if (n.length() != 12) throw ApiException.conflict("GIFT_CARD_INVALID", "This gift card cannot be used");
        String h = hash(n);
        var replay = jdbc.sql("select booking_id, amount from gift_card_redemptions where business_id = :b and idempotency_key = :k").param("b", businessId).param("k", idempotencyKey)
                .query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getBigDecimal(2)}).optional();
        if (replay.isPresent()) {
            if (!replay.get()[0].equals(bookingId) || ((BigDecimal) replay.get()[1]).compareTo(a) != 0) throw ApiException.conflict("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used for a different operation");
            return payments.bookingView(businessId, bookingId);
        }
        var card = jdbc.sql("select id, code_last4 from gift_cards where business_id = :b and code_hash = :h").param("b", businessId).param("h", h)
                .query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getString(2)}).optional()
                .orElseThrow(() -> ApiException.conflict("GIFT_CARD_INVALID", "This gift card cannot be used"));
        UUID cardId = (UUID) card[0];
        String tz = tz(businessId);
        BookingView view = payments.recordGiftCardPayment(businessId, bookingId, "gift-" + idempotencyKey, a, (String) card[1], () -> {
            int updated = jdbc.sql("""
                update gift_cards set balance = balance - :a
                where id = :id and business_id = :b and status = 'ACTIVE' and balance >= :a and (expires_on is null or expires_on >= (now() at time zone :tz)::date)
                """).param("a", a).param("id", cardId).param("b", businessId).param("tz", tz).update();
            if (updated == 0) {
                var s = jdbc.sql(SELECT + " where id = :id and business_id = :b").param("tz", tz).param("id", cardId).param("b", businessId).query((rs, i) -> map(rs)).single();
                if (!"ACTIVE".equals(s.status()) || s.expired()) throw ApiException.conflict("GIFT_CARD_INVALID", "This gift card cannot be used");
                throw ApiException.conflict("GIFT_CARD_INSUFFICIENT", "The card balance is " + s.balance() + " " + s.currency());
            }
            jdbc.sql("insert into gift_card_redemptions (business_id, gift_card_id, booking_id, amount, idempotency_key, created_by) values (:b, :g, :bk, :a, :k, :u)")
                    .param("b", businessId).param("g", cardId).param("bk", bookingId).param("a", a).param("k", idempotencyKey).param("u", CurrentUser.id()).update();
        });
        audit.log(businessId, CurrentUser.id(), "GIFT_CARD_REDEEMED", "GIFT_CARD", cardId, "{\"booking\":\"" + bookingId + "\",\"amount\":\"" + a + "\"}");
        return view;
    }
}
