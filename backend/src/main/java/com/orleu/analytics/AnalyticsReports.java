package com.orleu.analytics;

import com.orleu.common.ApiException;
import com.orleu.common.Money;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.*;

/**
 * Chart/table data. Same money semantics as {@link AnalyticsService}: booked value is NOT cash; collected cash is attributed by
 * the time the payment was recorded. All day/hour bucketing uses the BUSINESS timezone, not UTC.
 */
@Service
public class AnalyticsReports {
    public enum Dimension { SERVICE, EMPLOYEE, BRANCH }

    public record BreakdownRow(UUID id, String name, long bookings, long completed, long cancelled, long noShows,
                               BigDecimal bookedValue, BigDecimal collected, BigDecimal refunded, BigDecimal netCollected) {}

    public record DayPoint(LocalDate date, long bookings, long completed, BigDecimal bookedValue, BigDecimal netCollected) {}

    public record CustomerMix(long newCustomers, long returningCustomers, double returningShare) {}

    private static final String LIVE = "('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS','COMPLETED')";
    private static final String DEMAND = "('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS','COMPLETED','NO_SHOW')";

    private final TenantAccess access;
    private final JdbcClient jdbc;

    public AnalyticsReports(TenantAccess access, JdbcClient jdbc) { this.access = access; this.jdbc = jdbc; }

    public List<BreakdownRow> breakdown(UUID businessId, Instant from, Instant to, Dimension by) {
        access.require(businessId, Permission.ANALYTICS_VIEW);
        range(from, to);
        // column / table names come from a closed enum, never from user input
        String col = switch (by) { case SERVICE -> "service_id"; case EMPLOYEE -> "employee_id"; case BRANCH -> "branch_id"; };
        String names = switch (by) {
            case SERVICE -> "select id, name from services where business_id = :b";
            case EMPLOYEE -> "select id, display_name as name from employees where business_id = :b";
            case BRANCH -> "select id, name from branches where business_id = :b";
        };
        Map<UUID, String> nameById = new HashMap<>();
        jdbc.sql(names).param("b", businessId).query((rs, i) -> nameById.put(rs.getObject(1, UUID.class), rs.getString(2))).list();

        Map<UUID, long[]> counts = new LinkedHashMap<>();
        Map<UUID, BigDecimal[]> money = new HashMap<>();
        jdbc.sql("select " + col + " as k, status, count(*) as n, coalesce(sum(price) filter (where status in " + LIVE + "), 0) as booked "
                + "from bookings where business_id = :b and starts_at >= :f and starts_at < :t group by " + col + ", status")
            .param("b", businessId).param("f", Timestamp.from(from)).param("t", Timestamp.from(to))
            .query((rs, i) -> {
                UUID k = rs.getObject("k", UUID.class);
                long[] c = counts.computeIfAbsent(k, x -> new long[4]); // bookings, completed, cancelled, noShows
                String st = rs.getString("status");
                long n = rs.getLong("n");
                if (!st.equals("CANCELLED") && !st.equals("EXPIRED")) c[0] += n;
                if (st.equals("COMPLETED")) c[1] += n;
                if (st.equals("CANCELLED")) c[2] += n;
                if (st.equals("NO_SHOW")) c[3] += n;
                BigDecimal[] m = money.computeIfAbsent(k, x -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO});
                m[0] = m[0].add(rs.getBigDecimal("booked"));
                return 0;
            }).list();
        jdbc.sql("select b." + col + " as k, coalesce(sum(l.amount) filter (where l.entry_type = 'PAYMENT'), 0) as paid, "
                + "coalesce(sum(l.amount) filter (where l.entry_type = 'REFUND'), 0) as refunded "
                + "from ledger_entries l join bookings b on b.id = l.booking_id and b.business_id = l.business_id "
                + "where l.business_id = :b and l.created_at >= :f and l.created_at < :t group by b." + col)
            .param("b", businessId).param("f", Timestamp.from(from)).param("t", Timestamp.from(to))
            .query((rs, i) -> {
                UUID k = rs.getObject("k", UUID.class);
                counts.computeIfAbsent(k, x -> new long[4]);
                BigDecimal[] m = money.computeIfAbsent(k, x -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO});
                m[1] = rs.getBigDecimal("paid");
                m[2] = rs.getBigDecimal("refunded");
                return 0;
            }).list();

        List<BreakdownRow> rows = new ArrayList<>();
        for (var e : counts.entrySet()) {
            long[] c = e.getValue();
            BigDecimal[] m = money.getOrDefault(e.getKey(), new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO});
            rows.add(new BreakdownRow(e.getKey(), nameById.getOrDefault(e.getKey(), "?"), c[0], c[1], c[2], c[3],
                    Money.scale(m[0]), Money.scale(m[1]), Money.scale(m[2]), Money.scale(m[1].subtract(m[2]))));
        }
        rows.sort(Comparator.comparing(BreakdownRow::netCollected).reversed().thenComparing(BreakdownRow::bookedValue, Comparator.reverseOrder()));
        return rows;
    }

    /** One point per calendar day in the business timezone, zero-filled, so charts have no gaps. */
    public List<DayPoint> timeseries(UUID businessId, Instant from, Instant to) {
        access.require(businessId, Permission.ANALYTICS_VIEW);
        range(from, to);
        ZoneId zone = zone(businessId);
        Map<LocalDate, long[]> n = new HashMap<>();
        Map<LocalDate, BigDecimal[]> m = new HashMap<>();
        jdbc.sql("select (starts_at at time zone :tz)::date as d, count(*) filter (where status in " + LIVE + ") as bookings, "
                + "count(*) filter (where status = 'COMPLETED') as completed, coalesce(sum(price) filter (where status in " + LIVE + "), 0) as booked "
                + "from bookings where business_id = :b and starts_at >= :f and starts_at < :t group by 1")
            .param("tz", zone.getId()).param("b", businessId).param("f", Timestamp.from(from)).param("t", Timestamp.from(to))
            .query((rs, i) -> {
                LocalDate d = rs.getObject("d", LocalDate.class);
                n.put(d, new long[]{rs.getLong("bookings"), rs.getLong("completed")});
                m.computeIfAbsent(d, x -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO})[0] = rs.getBigDecimal("booked");
                return 0;
            }).list();
        jdbc.sql("select (created_at at time zone :tz)::date as d, coalesce(sum(case when entry_type = 'PAYMENT' then amount else -amount end), 0) as net "
                + "from ledger_entries where business_id = :b and created_at >= :f and created_at < :t group by 1")
            .param("tz", zone.getId()).param("b", businessId).param("f", Timestamp.from(from)).param("t", Timestamp.from(to))
            .query((rs, i) -> {
                m.computeIfAbsent(rs.getObject("d", LocalDate.class), x -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO})[1] = rs.getBigDecimal("net");
                return 0;
            }).list();
        List<DayPoint> out = new ArrayList<>();
        LocalDate first = from.atZone(zone).toLocalDate(), last = to.minusMillis(1).atZone(zone).toLocalDate();
        for (LocalDate d = first; !d.isAfter(last); d = d.plusDays(1)) {
            long[] c = n.getOrDefault(d, new long[2]);
            BigDecimal[] mm = m.getOrDefault(d, new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO});
            out.add(new DayPoint(d, c[0], c[1], Money.scale(mm[0]), Money.scale(mm[1])));
        }
        return out;
    }

    /** Demand by hour of day (0..23) in the business timezone; cancelled and expired bookings are not demand. */
    public int[] peakHours(UUID businessId, Instant from, Instant to) {
        access.require(businessId, Permission.ANALYTICS_VIEW);
        range(from, to);
        int[] hours = new int[24];
        jdbc.sql("select extract(hour from (starts_at at time zone :tz))::int as h, count(*) as n from bookings "
                + "where business_id = :b and starts_at >= :f and starts_at < :t and status in " + DEMAND + " group by 1")
            .param("tz", zone(businessId).getId()).param("b", businessId).param("f", Timestamp.from(from)).param("t", Timestamp.from(to))
            .query((rs, i) -> { hours[rs.getInt("h")] = (int) rs.getLong("n"); return 0; }).list();
        return hours;
    }

    /**
     * New = customers whose FIRST non-cancelled booking falls in the range; returning = customers with a booking in the range
     * who already had an earlier one. returningShare is a share of active customers in the range, not a retention rate.
     */
    public CustomerMix customerMix(UUID businessId, Instant from, Instant to) {
        access.require(businessId, Permission.ANALYTICS_VIEW);
        range(from, to);
        long[] r = jdbc.sql("""
            with active as (select customer_id, min(starts_at) as first_at from bookings
                            where business_id = :b and status in ('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS','COMPLETED','NO_SHOW')
                            group by customer_id),
                 in_range as (select distinct customer_id from bookings
                              where business_id = :b and starts_at >= :f and starts_at < :t
                                and status in ('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS','COMPLETED','NO_SHOW'))
            select count(*) filter (where a.first_at >= :f) as new_c, count(*) filter (where a.first_at < :f) as returning_c
            from in_range ir join active a on a.customer_id = ir.customer_id
            """).param("b", businessId).param("f", Timestamp.from(from)).param("t", Timestamp.from(to))
            .query((rs, i) -> new long[]{rs.getLong("new_c"), rs.getLong("returning_c")}).single();
        long total = r[0] + r[1];
        return new CustomerMix(r[0], r[1], total == 0 ? 0.0 : Math.round(r[1] * 10000.0 / total) / 10000.0);
    }

    private ZoneId zone(UUID businessId) {
        return ZoneId.of(jdbc.sql("select timezone from businesses where id = :b").param("b", businessId).query(String.class).single());
    }

    private static void range(Instant from, Instant to) {
        if (!to.isAfter(from) || Duration.between(from, to).toDays() > 366) {
            throw ApiException.badRequest("INVALID_RANGE", "range must be positive and at most 366 days");
        }
    }
}
