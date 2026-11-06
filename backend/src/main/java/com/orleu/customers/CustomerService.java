package com.orleu.customers;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.customers.CustomerDtos.*;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class CustomerService {
    private final CustomerRepository customers;
    private final TenantAccess access;
    private final AuditService audit;
    private final JdbcClient jdbc;

    public CustomerService(CustomerRepository customers, TenantAccess access, AuditService audit, JdbcClient jdbc) {
        this.customers = customers; this.access = access; this.audit = audit; this.jdbc = jdbc;
    }

    @Transactional
    public CustomerView create(UUID businessId, CustomerInput in) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        if (customers.findByBusinessIdAndPhone(businessId, in.phone()).isPresent()) {
            throw ApiException.conflict("CUSTOMER_EXISTS", "A customer with this phone already exists");
        }
        return CustomerView.of(upsert(businessId, in), java.util.List.of());
    }

    public PageView<CustomerView> search(UUID businessId, String q, String tag, int page, int size) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        String t = tag == null || tag.isBlank() ? null : tag.trim().toLowerCase();
        var p = customers.search(businessId, q == null || q.isBlank() ? null : q.trim(), t,
                PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100)));
        var tags = tagsFor(businessId, p.getContent().stream().map(Customer::getId).toList());
        return new PageView<>(p.getContent().stream().map(c -> CustomerView.of(c, tags.getOrDefault(c.getId(), java.util.List.of()))).toList(),
                p.getNumber(), p.getSize(), p.getTotalElements());
    }

    private java.util.Map<UUID, java.util.List<String>> tagsFor(UUID businessId, java.util.Collection<UUID> ids) {
        var out = new java.util.HashMap<UUID, java.util.List<String>>();
        if (ids.isEmpty()) return out;
        jdbc.sql("select customer_id, tag from customer_tags where business_id = :b and customer_id in (:ids) order by tag")
                .param("b", businessId).param("ids", ids)
                .query((rs, i) -> java.util.Map.entry(rs.getObject("customer_id", UUID.class), rs.getString("tag")))
                .list().forEach(e -> out.computeIfAbsent(e.getKey(), k -> new java.util.ArrayList<>()).add(e.getValue()));
        return out;
    }

    private CustomerView view(UUID businessId, Customer c) {
        return CustomerView.of(c, tagsFor(businessId, java.util.List.of(c.getId())).getOrDefault(c.getId(), java.util.List.of()));
    }

    /** All tags in use with the number of customers carrying each (for the filter chips). */
    public java.util.List<TagCount> tagCounts(UUID businessId) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        return jdbc.sql("select tag, count(*) as n from customer_tags where business_id = :b group by tag order by n desc, tag")
                .param("b", businessId).query((rs, i) -> new TagCount(rs.getString("tag"), rs.getLong("n"))).list();
    }

    /** Replaces the customer's tags. Tags are trimmed, lower-cased and de-duplicated; at most 10. */
    @Transactional
    public CustomerView setTags(UUID businessId, UUID id, TagsRequest r) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        Customer c = customers.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Customer"));
        var clean = r.tags().stream().map(t -> t.trim().toLowerCase()).filter(t -> !t.isEmpty()).distinct().sorted().toList();
        if (clean.size() > 10) throw ApiException.badRequest("TOO_MANY_TAGS", "At most 10 tags per customer");
        jdbc.sql("delete from customer_tags where customer_id = :c and business_id = :b").param("c", id).param("b", businessId).update();
        for (String t : clean) {
            jdbc.sql("insert into customer_tags (customer_id, business_id, tag) values (:c, :b, :t)").param("c", id).param("b", businessId).param("t", t).update();
        }
        audit.log(businessId, CurrentUser.id(), "CUSTOMER_TAGS_UPDATED", "CUSTOMER", id, null);
        return CustomerView.of(c, clean);
    }

    public CustomerView get(UUID businessId, UUID id) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        return view(businessId, customers.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Customer")));
    }

    @Transactional
    public CustomerView update(UUID businessId, UUID id, UpdateCustomerRequest r) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        Customer c = customers.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Customer"));
        if (r.fullName() != null) {
            if (r.fullName().isBlank()) throw ApiException.badRequest("INVALID_NAME", "Name cannot be blank");
            c.setFullName(r.fullName().trim());
        }
        if (r.email() != null) c.setEmail(r.email().isBlank() ? null : r.email().trim());
        if (r.notes() != null) c.setNotes(r.notes());
        if (r.marketingOptIn() != null) c.setMarketingOptIn(r.marketingOptIn());
        audit.log(businessId, CurrentUser.id(), "CUSTOMER_UPDATED", "CUSTOMER", id, null);
        return view(businessId, c);
    }

    /** Customer card: identity, measured statistics and the latest 50 bookings. Everything is filtered by business id. */
    public CustomerProfile profile(UUID businessId, UUID id) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        Customer c = customers.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Customer"));
        var lines = jdbc.sql("""
            select b.id, b.starts_at, s.name as service_name, e.display_name as employee_name, b.status, b.price,
                   coalesce((select sum(case when l.entry_type = 'PAYMENT' then l.amount else -l.amount end)
                             from ledger_entries l where l.booking_id = b.id), 0) as net_paid
            from bookings b
            join services s on s.id = b.service_id and s.business_id = b.business_id
            join employees e on e.id = b.employee_id and e.business_id = b.business_id
            where b.business_id = :biz and b.customer_id = :cid
            order by b.starts_at desc limit 50
            """).param("biz", businessId).param("cid", id)
            .query((rs, i) -> new BookingLine(rs.getObject("id", UUID.class), rs.getTimestamp("starts_at").toInstant(), rs.getString("service_name"),
                    rs.getString("employee_name"), rs.getString("status"), rs.getBigDecimal("price"), rs.getBigDecimal("net_paid"))).list();
        var stats = jdbc.sql("""
            select count(*) as total,
                   count(*) filter (where status = 'COMPLETED') as completed,
                   count(*) filter (where status = 'CANCELLED') as cancelled,
                   count(*) filter (where status = 'NO_SHOW') as no_show,
                   count(*) filter (where status in ('PENDING','AWAITING_PAYMENT','CONFIRMED') and starts_at > now()) as upcoming,
                   max(starts_at) filter (where status = 'COMPLETED') as last_visit
            from bookings where business_id = :biz and customer_id = :cid
            """).param("biz", businessId).param("cid", id)
            .query((rs, i) -> new Object[]{rs.getLong("total"), rs.getLong("completed"), rs.getLong("cancelled"), rs.getLong("no_show"),
                    rs.getLong("upcoming"), rs.getTimestamp("last_visit")}).single();
        java.math.BigDecimal spent = jdbc.sql("""
            select coalesce(sum(case when l.entry_type = 'PAYMENT' then l.amount else -l.amount end), 0)
            from ledger_entries l join bookings b on b.id = l.booking_id and b.business_id = l.business_id
            where l.business_id = :biz and b.customer_id = :cid
            """).param("biz", businessId).param("cid", id).query(java.math.BigDecimal.class).single();
        long completed = (Long) stats[1];
        // average per COMPLETED visit: cash collected on completed bookings only, so deposits on future/cancelled bookings don't distort it
        java.math.BigDecimal completedSpent = jdbc.sql("""
            select coalesce(sum(case when l.entry_type = 'PAYMENT' then l.amount else -l.amount end), 0)
            from ledger_entries l join bookings b on b.id = l.booking_id and b.business_id = l.business_id
            where l.business_id = :biz and b.customer_id = :cid and b.status = 'COMPLETED'
            """).param("biz", businessId).param("cid", id).query(java.math.BigDecimal.class).single();
        java.math.BigDecimal avg = completed == 0 ? null : completedSpent.divide(java.math.BigDecimal.valueOf(completed), 2, java.math.RoundingMode.HALF_UP);
        var last = (java.sql.Timestamp) stats[5];
        return new CustomerProfile(view(businessId, c), new CustomerStats((Long) stats[0], completed, (Long) stats[2], (Long) stats[3], (Long) stats[4],
                last == null ? null : last.toInstant(), com.orleu.common.Money.scale(spent), avg), lines);
    }

    @Transactional
    public CustomerView setBlocked(UUID businessId, UUID id, boolean blocked) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        Customer c = customers.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Customer"));
        c.setBlocked(blocked);
        audit.log(businessId, CurrentUser.id(), blocked ? "CUSTOMER_BLOCKED" : "CUSTOMER_UNBLOCKED", "CUSTOMER", id, null);
        return view(businessId, c);
    }

    /** Finds a customer by phone within the business or creates one. No authorization: callers must have done it. */
    @Transactional
    public Customer upsert(UUID businessId, CustomerInput in) {
        Customer c = customers.findByBusinessIdAndPhone(businessId, in.phone()).orElseGet(() -> {
            Customer n = new Customer();
            n.setBusinessId(businessId);
            n.setPhone(in.phone());
            return n;
        });
        if (c.getId() == null) {
            c.setFullName(in.fullName().trim());
            c.setEmail(in.email());
            c.setNotes(in.notes());
            c.setMarketingOptIn(Boolean.TRUE.equals(in.marketingOptIn()));
            return customers.save(c);
        }
        return c; // existing customers are not silently overwritten by (possibly anonymous) public input
    }
}
