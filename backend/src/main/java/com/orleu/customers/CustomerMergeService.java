package com.orleu.customers;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Merges a duplicate customer (source) into the one to keep (target), inside one business.
 * Bookings move to the target; tags are united; the target's phone, name and marketing consent win
 * (consent given to one record is never silently transferred to another); a block on either record is kept.
 * The source record is deleted. Irreversible, audited, owner/manager only.
 */
@Service
public class CustomerMergeService {
    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;
    private final CustomerService customers;

    public CustomerMergeService(TenantAccess access, JdbcClient jdbc, AuditService audit, CustomerService customers) {
        this.access = access; this.jdbc = jdbc; this.audit = audit; this.customers = customers;
    }

    @Transactional
    public CustomerDtos.CustomerView merge(UUID businessId, UUID targetId, UUID sourceId) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        if (targetId.equals(sourceId)) throw ApiException.badRequest("MERGE_SAME", "Choose a different customer to merge");
        // lock both rows in a fixed order so two concurrent merges cannot deadlock
        var rows = jdbc.sql("""
            select id, email, notes, blocked, anonymized_at is not null as anonymized from customers
            where business_id = :b and id in (:t, :s) order by id for update
            """).param("b", businessId).param("t", targetId).param("s", sourceId)
                .query((rs, i) -> new Object[]{rs.getObject("id", UUID.class), rs.getString("email"), rs.getString("notes"), rs.getBoolean("blocked"), rs.getBoolean("anonymized")}).list();
        if (rows.size() != 2) throw ApiException.notFound("Customer");
        Object[] target = rows.stream().filter(r -> r[0].equals(targetId)).findFirst().orElseThrow();
        Object[] source = rows.stream().filter(r -> r[0].equals(sourceId)).findFirst().orElseThrow();
        if ((Boolean) target[4] || (Boolean) source[4]) throw ApiException.conflict("CUSTOMER_ANONYMIZED", "Anonymised customers cannot be merged");

        int moved = jdbc.sql("update bookings set customer_id = :t where business_id = :b and customer_id = :s")
                .param("t", targetId).param("s", sourceId).param("b", businessId).update();
        jdbc.sql("""
            insert into customer_tags (customer_id, business_id, tag)
            select :t, business_id, tag from customer_tags where customer_id = :s and business_id = :b
            on conflict do nothing
            """).param("t", targetId).param("s", sourceId).param("b", businessId).update();
        String tEmail = (String) target[1], sEmail = (String) source[1];
        String tNotes = (String) target[2], sNotes = (String) source[2];
        String notes = sNotes == null || sNotes.isBlank() ? tNotes : (tNotes == null || tNotes.isBlank() ? sNotes : tNotes + "\n\n" + sNotes);
        boolean blocked = (Boolean) target[3] || (Boolean) source[3];
        jdbc.sql("delete from customers where id = :s and business_id = :b").param("s", sourceId).param("b", businessId).update();
        jdbc.sql("update customers set email = :e, notes = :n, blocked = :bl where id = :t and business_id = :b")
                .param("e", tEmail != null && !tEmail.isBlank() ? tEmail : sEmail).param("n", notes).param("bl", blocked)
                .param("t", targetId).param("b", businessId).update();
        audit.log(businessId, CurrentUser.id(), "CUSTOMER_MERGED", "CUSTOMER", targetId, "{\"mergedFrom\":\"" + sourceId + "\",\"bookingsMoved\":" + moved + "}");
        return customers.get(businessId, targetId);
    }
}
