package com.orleu.customers;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Customer data export and anonymisation (the technical side of access/erasure requests; whether and when they apply is a legal question).
 * Anonymisation removes name, phone, e-mail, notes, consent and message bodies, deletes review comments and booking notes and invalidates the
 * guest's manage link, but KEEPS the bookings and the immutable ledger (accounting records) which then point to an anonymous customer.
 */
@Service
public class CustomerPrivacyService {
    private static final SecureRandom RANDOM = new SecureRandom();

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;

    public CustomerPrivacyService(TenantAccess access, JdbcClient jdbc, AuditService audit) { this.access = access; this.jdbc = jdbc; this.audit = audit; }

    @Transactional
    public Map<String, Object> export(UUID businessId, UUID customerId) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        var customer = jdbc.sql("select id, full_name, phone, email, notes, marketing_opt_in, blocked, created_at, anonymized_at from customers where id = :c and business_id = :b")
                .param("c", customerId).param("b", businessId).query((rs, i) -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", rs.getObject(1, UUID.class)); m.put("fullName", rs.getString(2)); m.put("phone", rs.getString(3)); m.put("email", rs.getString(4));
                    m.put("notes", rs.getString(5)); m.put("marketingOptIn", rs.getBoolean(6)); m.put("blocked", rs.getBoolean(7));
                    m.put("createdAt", rs.getTimestamp(8).toInstant()); m.put("anonymizedAt", rs.getTimestamp(9) == null ? null : rs.getTimestamp(9).toInstant());
                    return m;
                }).optional().orElseThrow(() -> ApiException.notFound("Customer"));
        List<Map<String, Object>> bookings = jdbc.sql("""
            select b.id, b.starts_at, s.name, e.display_name, b.status, b.price, b.currency, b.notes, b.source,
                   coalesce((select sum(case when l.entry_type = 'PAYMENT' then l.amount else -l.amount end) from ledger_entries l where l.booking_id = b.id), 0)
            from bookings b join services s on s.id = b.service_id and s.business_id = b.business_id
            join employees e on e.id = b.employee_id and e.business_id = b.business_id
            where b.customer_id = :c and b.business_id = :b order by b.starts_at
            """).param("c", customerId).param("b", businessId).query((rs, i) -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("id", rs.getObject(1, UUID.class)); m.put("startsAt", rs.getTimestamp(2).toInstant()); m.put("service", rs.getString(3)); m.put("specialist", rs.getString(4));
                m.put("status", rs.getString(5)); m.put("price", rs.getBigDecimal(6)); m.put("currency", rs.getString(7)); m.put("notes", rs.getString(8));
                m.put("source", rs.getString(9)); m.put("netPaid", rs.getBigDecimal(10));
                return m;
            }).list();
        List<Map<String, Object>> messages = jdbc.sql("""
            select m.message_type, m.body, m.status, m.created_at from customer_messages m join bookings b on b.id = m.booking_id and b.business_id = m.business_id
            where b.customer_id = :c and m.business_id = :b order by m.created_at
            """).param("c", customerId).param("b", businessId).query((rs, i) -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("type", rs.getString(1)); m.put("body", rs.getString(2)); m.put("status", rs.getString(3)); m.put("createdAt", rs.getTimestamp(4).toInstant());
                return m;
            }).list();
        List<Map<String, Object>> reviews = jdbc.sql("""
            select r.rating, r.comment, r.created_at, r.booking_id from reviews r join bookings b on b.id = r.booking_id and b.business_id = r.business_id
            where b.customer_id = :c and r.business_id = :b order by r.created_at
            """).param("c", customerId).param("b", businessId).query((rs, i) -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("rating", rs.getInt(1)); m.put("comment", rs.getString(2)); m.put("createdAt", rs.getTimestamp(3).toInstant()); m.put("bookingId", rs.getObject(4, UUID.class));
                return m;
            }).list();
        audit.log(businessId, CurrentUser.id(), "CUSTOMER_DATA_EXPORTED", "CUSTOMER", customerId, null);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("exportedAt", Instant.now());
        out.put("customer", customer);
        out.put("bookings", bookings);
        out.put("messages", messages);
        out.put("reviews", reviews);
        return out;
    }

    /** Owner/admin action. Refuses while the customer still has upcoming active bookings (cancel them first). */
    @Transactional
    public void anonymize(UUID businessId, UUID customerId) {
        access.require(businessId, Permission.BUSINESS_MANAGE);
        boolean exists = jdbc.sql("select exists(select 1 from customers where id = :c and business_id = :b)").param("c", customerId).param("b", businessId).query(Boolean.class).single();
        if (!exists) throw ApiException.notFound("Customer");
        boolean upcoming = jdbc.sql("select exists(select 1 from bookings where customer_id = :c and business_id = :b and starts_at > now() and status in ('PENDING','AWAITING_PAYMENT','CONFIRMED'))")
                .param("c", customerId).param("b", businessId).query(Boolean.class).single();
        if (upcoming) throw ApiException.conflict("HAS_UPCOMING_BOOKINGS", "Cancel the customer's upcoming bookings first");
        anonymizeInternal(businessId, customerId);
        audit.log(businessId, CurrentUser.id(), "CUSTOMER_ANONYMIZED", "CUSTOMER", customerId, null);
    }

    /** No authorisation: callers (the endpoint above, the retention job) decide. Idempotent. */
    @Transactional
    public void anonymizeInternal(UUID businessId, UUID customerId) {
        String placeholder = null;
        for (int attempt = 0; attempt < 8 && placeholder == null; attempt++) {
            StringBuilder sb = new StringBuilder("+999");
            for (int i = 0; i < 11; i++) sb.append(RANDOM.nextInt(10)); // not a real country code: can never be a deliverable number
            String candidate = sb.toString();
            boolean taken = jdbc.sql("select exists(select 1 from customers where business_id = :b and phone = :p)").param("b", businessId).param("p", candidate).query(Boolean.class).single();
            if (!taken) placeholder = candidate;
        }
        if (placeholder == null) throw new IllegalStateException("could not allocate an anonymous placeholder number");
        jdbc.sql("""
            update customers set full_name = 'Deleted customer', phone = :p, email = null, notes = null, marketing_opt_in = false, anonymized_at = now()
            where id = :c and business_id = :b and anonymized_at is null
            """).param("p", placeholder).param("c", customerId).param("b", businessId).update();
        jdbc.sql("delete from customer_tags where customer_id = :c and business_id = :b").param("c", customerId).param("b", businessId).update();
        jdbc.sql("update bookings set notes = null, manage_token_hash = null where customer_id = :c and business_id = :b").param("c", customerId).param("b", businessId).update();
        jdbc.sql("delete from customer_messages where business_id = :b and booking_id in (select id from bookings where customer_id = :c and business_id = :b)").param("c", customerId).param("b", businessId).update();
        jdbc.sql("update reviews set comment = null where business_id = :b and booking_id in (select id from bookings where customer_id = :c and business_id = :b)").param("c", customerId).param("b", businessId).update();
    }
}
