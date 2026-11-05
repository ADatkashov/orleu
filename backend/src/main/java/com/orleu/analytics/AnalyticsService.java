package com.orleu.analytics;

import com.orleu.common.ApiException;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Measured figures only (no forecasts). Money is kept apart on purpose:
 *  bookedValue   = price of live+completed bookings starting in range (NOT cash)
 *  collected     = ledger payments created in range
 *  refunded      = ledger refunds created in range
 *  netCollected  = collected - refunded
 *  outstanding   = unpaid balance of non-cancelled bookings starting in range
 * Range boundaries are half-open instants supplied by the client (timezone resolution is the caller's job).
 */
@Service
public class AnalyticsService {
    public record Summary(Instant from, Instant to, Map<String, Long> bookingsByStatus, long totalBookings,
                          BigDecimal bookedValue, BigDecimal completedRevenue, BigDecimal collected, BigDecimal refunded,
                          BigDecimal netCollected, BigDecimal outstanding, double cancellationRate, double noShowRate) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;

    public AnalyticsService(TenantAccess access, JdbcClient jdbc) { this.access = access; this.jdbc = jdbc; }

    public Summary summary(UUID businessId, Instant from, Instant to) {
        access.require(businessId, Permission.ANALYTICS_VIEW);
        if (!to.isAfter(from) || Duration.between(from, to).toDays() > 366) {
            throw ApiException.badRequest("INVALID_RANGE", "range must be positive and at most 366 days");
        }
        Timestamp f = Timestamp.from(from), t = Timestamp.from(to);
        Map<String, Long> byStatus = new LinkedHashMap<>();
        jdbc.sql("select status, count(*) from bookings where business_id = :b and starts_at >= :f and starts_at < :t group by status order by status")
                .param("b", businessId).param("f", f).param("t", t)
                .query((rs, i) -> byStatus.put(rs.getString(1), rs.getLong(2))).list();
        long total = byStatus.values().stream().mapToLong(Long::longValue).sum();

        BigDecimal booked = money("""
            select coalesce(sum(price),0) from bookings where business_id = :b and starts_at >= :f and starts_at < :t
            and status in ('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS','COMPLETED')""", businessId, f, t);
        BigDecimal completed = money("""
            select coalesce(sum(price),0) from bookings where business_id = :b and starts_at >= :f and starts_at < :t
            and status = 'COMPLETED'""", businessId, f, t);
        BigDecimal collected = money("""
            select coalesce(sum(amount),0) from ledger_entries where business_id = :b and created_at >= :f and created_at < :t
            and entry_type = 'PAYMENT'""", businessId, f, t);
        BigDecimal refunded = money("""
            select coalesce(sum(amount),0) from ledger_entries where business_id = :b and created_at >= :f and created_at < :t
            and entry_type = 'REFUND'""", businessId, f, t);
        BigDecimal outstanding = money("""
            select coalesce(sum(greatest(b.price - coalesce(l.net,0), 0)),0)
            from bookings b left join (
                select booking_id, sum(case when entry_type='PAYMENT' then amount else -amount end) as net
                from ledger_entries where business_id = :b group by booking_id) l on l.booking_id = b.id
            where b.business_id = :b and b.starts_at >= :f and b.starts_at < :t
              and b.status in ('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS','COMPLETED')""", businessId, f, t);

        long cancelled = byStatus.getOrDefault("CANCELLED", 0L);
        long noShow = byStatus.getOrDefault("NO_SHOW", 0L);
        return new Summary(from, to, byStatus, total, booked, completed, collected, refunded, collected.subtract(refunded),
                outstanding, rate(cancelled, total), rate(noShow, total));
    }

    private BigDecimal money(String sql, UUID b, Timestamp f, Timestamp t) {
        return jdbc.sql(sql).param("b", b).param("f", f).param("t", t).query(BigDecimal.class).single();
    }

    private static double rate(long part, long total) { return total == 0 ? 0.0 : Math.round(part * 10000.0 / total) / 10000.0; }
}
