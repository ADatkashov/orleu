package com.orleu.portal;

import com.orleu.audit.AuditService;
import com.orleu.bookings.BookingService;
import com.orleu.bookings.BookingService.ManageView;
import com.orleu.common.ApiException;
import com.orleu.common.PhoneNumbers;
import com.orleu.notifications.SystemMessageService;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

/**
 * Customer portal inside ONE business. A customer proves they own the phone number with a one-time SMS code and then sees and cancels only their own
 * bookings. Security properties (all tested): the code request never reveals whether the number is known; codes are 6 digits, stored hashed, valid 10 minutes,
 * 5 wrong attempts burn the code, at most 3 codes per 15 minutes and 10 per day per customer; a successful verification burns every other open code; sessions are
 * random 256-bit tokens stored hashed (12 hours, revocable); every query is filtered by business AND customer. Blocked and anonymised customers get no code.
 * Delivery needs a message sender (orleu.messaging.provider): without one no code is queued and the portal cannot be entered.
 */
@Service
public class PortalService {
    static final Duration CODE_TTL = Duration.ofMinutes(10);
    static final Duration SESSION_TTL = Duration.ofHours(12);
    static final int MAX_ATTEMPTS = 5;
    private static final SecureRandom RANDOM = new SecureRandom();

    public record Session(String token, Instant expiresAt) {}
    public record BookingRow(UUID id, Instant startsAt, String serviceName, String employeeName, String status, java.math.BigDecimal price, String currency,
                             boolean canCancel, Instant cancelUntil) {}
    public record Me(String fullName, String businessName, List<BookingRow> bookings) {}
    private record Ctx(UUID businessId, UUID customerId) {}

    private final JdbcClient jdbc;
    private final ObjectProvider<SystemMessageService> messages;
    private final BookingService bookings;
    private final AuditService audit;

    public PortalService(JdbcClient jdbc, ObjectProvider<SystemMessageService> messages, BookingService bookings, AuditService audit) {
        this.jdbc = jdbc; this.messages = messages; this.bookings = bookings; this.audit = audit;
    }

    private static String sha256(String s) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    private record Biz(UUID id, String name, String locale) {}

    private Biz business(String slug) {
        return jdbc.sql("select id, name, customer_locale from businesses where slug = :s and published and status <> 'SUSPENDED'").param("s", slug)
                .query((rs, i) -> new Biz(rs.getObject(1, UUID.class), rs.getString(2), rs.getString(3))).optional().orElse(null);
    }

    private UUID customer(UUID businessId, String phone) {
        return jdbc.sql("select id from customers where business_id = :b and phone = :p and anonymized_at is null and not blocked").param("b", businessId).param("p", phone)
                .query(UUID.class).optional().orElse(null);
    }

    /** Always returns normally: the caller cannot tell whether a code was sent. */
    @Transactional
    public void requestCode(String slug, String rawPhone) {
        String phone = PhoneNumbers.normalize(rawPhone);
        Biz biz = business(slug);
        SystemMessageService queue = messages.getIfAvailable();
        if (phone == null || biz == null || queue == null) return;
        UUID cid = customer(biz.id(), phone);
        if (cid == null) return;
        // serialise per customer so concurrent requests cannot slip past the caps
        jdbc.sql("select id from customers where id = :c for update").param("c", cid).query(UUID.class).single();
        int recent = jdbc.sql("select count(*) from portal_otps where customer_id = :c and created_at > now() - interval '15 minutes'").param("c", cid).query(Integer.class).single();
        int daily = jdbc.sql("select count(*) from portal_otps where customer_id = :c and created_at > now() - interval '24 hours'").param("c", cid).query(Integer.class).single();
        if (recent >= 3 || daily >= 10) return;
        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        UUID otp = jdbc.sql("insert into portal_otps (business_id, customer_id, code_hash, expires_at) values (:b, :c, :h, :e) returning id")
                .param("b", biz.id()).param("c", cid).param("h", sha256(otpSalt(cid) + code)).param("e", Timestamp.from(Instant.now().plus(CODE_TTL))).query(UUID.class).single();
        queue.enqueue("SMS", phone, null, PortalMessages.code(biz.locale(), biz.name(), code, (int) CODE_TTL.toMinutes()), "PORTAL_CODE", CODE_TTL);
    }

    private static String otpSalt(UUID customerId) { return customerId + ":"; }

    /** Generic failure for every wrong/unknown/expired/burnt case. */
    private static ApiException invalid() { return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "The code is wrong or has expired"); }

    @Transactional(noRollbackFor = ApiException.class)
    public Session verify(String slug, String rawPhone, String rawCode) {
        String phone = PhoneNumbers.normalize(rawPhone);
        Biz biz = business(slug);
        String code = rawCode == null ? "" : rawCode.trim();
        if (phone == null || biz == null || !code.matches("\\d{6}")) throw invalid();
        UUID cid = customer(biz.id(), phone);
        if (cid == null) throw invalid();
        jdbc.sql("select id from customers where id = :c for update").param("c", cid).query(UUID.class).single();
        var otp = jdbc.sql("""
            select id, code_hash from portal_otps
            where customer_id = :c and used_at is null and expires_at > now() and attempts < :m order by created_at desc limit 1
            """).param("c", cid).param("m", MAX_ATTEMPTS).query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getString(2)}).optional().orElse(null);
        if (otp == null) throw invalid();
        boolean ok = MessageDigest.isEqual(((String) otp[1]).getBytes(StandardCharsets.UTF_8), sha256(otpSalt(cid) + code).getBytes(StandardCharsets.UTF_8));
        if (!ok) {
            jdbc.sql("update portal_otps set attempts = attempts + 1 where id = :id").param("id", otp[0]).update();
            throw invalid();
        }
        jdbc.sql("update portal_otps set used_at = now() where customer_id = :c and used_at is null").param("c", cid).update(); // burns this and every other open code
        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        Instant exp = Instant.now().plus(SESSION_TTL);
        jdbc.sql("insert into portal_sessions (business_id, customer_id, token_hash, expires_at) values (:b, :c, :h, :e)")
                .param("b", biz.id()).param("c", cid).param("h", sha256(token)).param("e", Timestamp.from(exp)).update();
        audit.log(biz.id(), null, "PORTAL_SIGN_IN", "CUSTOMER", cid, null);
        return new Session(token, exp);
    }

    /** The session must belong to the business in the URL: a token of another business is just invalid here. */
    private Ctx session(String slug, String token) {
        Ctx c = session(token);
        Biz biz = business(slug);
        if (biz == null || !biz.id().equals(c.businessId())) throw unauthorized();
        return c;
    }

    private Ctx session(String token) {
        if (token == null || token.length() < 20 || token.length() > 100) throw unauthorized();
        return jdbc.sql("select business_id, customer_id from portal_sessions where token_hash = :h and revoked_at is null and expires_at > now()").param("h", sha256(token))
                .query((rs, i) -> new Ctx(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class))).optional().orElseThrow(PortalService::unauthorized);
    }

    private static ApiException unauthorized() { return new ApiException(HttpStatus.UNAUTHORIZED, "PORTAL_SESSION_INVALID", "Sign in again"); }

    @Transactional(readOnly = true)
    public Me me(String slug, String token) {
        Ctx c = session(slug, token);
        var who = jdbc.sql("select cu.full_name, bz.name from customers cu join businesses bz on bz.id = cu.business_id where cu.id = :c and cu.business_id = :b and cu.anonymized_at is null and not cu.blocked")
                .param("c", c.customerId()).param("b", c.businessId()).query((rs, i) -> new String[]{rs.getString(1), rs.getString(2)}).optional().orElseThrow(PortalService::unauthorized);
        List<UUID> ids = jdbc.sql("select id from bookings where business_id = :b and customer_id = :c order by starts_at desc limit 30").param("b", c.businessId()).param("c", c.customerId()).query(UUID.class).list();
        List<BookingRow> rows = ids.stream().map(id -> {
            ManageView v = bookings.manageViewFor(c.businessId(), c.customerId(), id);
            var extra = jdbc.sql("select e.display_name from bookings b join employees e on e.id = b.employee_id and e.business_id = b.business_id where b.id = :id").param("id", id).query(String.class).single();
            return new BookingRow(id, v.startsAt(), v.serviceName(), extra, v.status().name(), v.price(), v.currency(), v.canCancel(), v.cancelUntil());
        }).toList();
        return new Me(who[0], who[1], rows);
    }

    @Transactional
    public BookingRow cancel(String slug, String token, UUID bookingId) {
        Ctx c = session(slug, token);
        ManageView v = bookings.cancelByCustomerFor(c.businessId(), c.customerId(), bookingId);
        var extra = jdbc.sql("select e.display_name from bookings b join employees e on e.id = b.employee_id and e.business_id = b.business_id where b.id = :id").param("id", bookingId).query(String.class).single();
        return new BookingRow(bookingId, v.startsAt(), v.serviceName(), extra, v.status().name(), v.price(), v.currency(), v.canCancel(), v.cancelUntil());
    }

    @Transactional
    public void logout(String token) {
        if (token == null || token.length() < 20 || token.length() > 100) return;
        jdbc.sql("update portal_sessions set revoked_at = now() where token_hash = :h and revoked_at is null").param("h", sha256(token)).update();
    }
}
