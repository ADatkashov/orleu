package com.orleu.customers;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * Opt-in automatic anonymisation: for businesses with customer_retention_months set, customers whose last activity (latest booking or, without
 * bookings, creation) is older than that many months and who have no upcoming active booking are anonymised. Bounded batch per run.
 */
@Component
public class CustomerRetentionJob {
    private static final Logger log = LoggerFactory.getLogger(CustomerRetentionJob.class);
    static final int BATCH = 500;

    private final JdbcClient jdbc;
    private final CustomerPrivacyService privacy;
    private final com.orleu.audit.AuditService audit;

    public CustomerRetentionJob(JdbcClient jdbc, CustomerPrivacyService privacy, com.orleu.audit.AuditService audit) { this.jdbc = jdbc; this.privacy = privacy; this.audit = audit; }

    private record Due(UUID businessId, UUID customerId) {}

    /** @return number of customers anonymised in this run. */
    public int runOnce() {
        List<Due> due = jdbc.sql("""
            select c.business_id, c.id from customers c join businesses b on b.id = c.business_id
            where b.customer_retention_months is not null and c.anonymized_at is null
              and coalesce((select max(k.starts_at) from bookings k where k.customer_id = c.id and k.business_id = c.business_id), c.created_at)
                  < now() - make_interval(months => b.customer_retention_months)
              and not exists (select 1 from bookings k where k.customer_id = c.id and k.business_id = c.business_id
                              and k.starts_at > now() and k.status in ('PENDING','AWAITING_PAYMENT','CONFIRMED'))
            order by c.created_at limit :lim
            """).param("lim", BATCH).query((rs, i) -> new Due(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class))).list();
        java.util.Map<UUID, Integer> perBusiness = new java.util.HashMap<>();
        for (Due d : due) {
            privacy.anonymizeInternal(d.businessId(), d.customerId());
            perBusiness.merge(d.businessId(), 1, Integer::sum);
        }
        perBusiness.forEach((biz, n) -> audit.log(biz, null, "CUSTOMERS_ANONYMIZED_BY_RETENTION", "CUSTOMER", null, "{\"count\":" + n + "}"));
        return due.size();
    }

    @Scheduled(fixedDelayString = "${orleu.jobs.retention-interval:PT24H}", initialDelayString = "PT15M")
    public void run() {
        try {
            int n = runOnce();
            if (n > 0) log.info("Retention: anonymised {} customers", n);
        } catch (Exception e) {
            log.error("Customer retention run failed", e);
        }
    }
}
