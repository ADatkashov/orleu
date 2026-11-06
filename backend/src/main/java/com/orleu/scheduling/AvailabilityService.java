package com.orleu.scheduling;

import com.orleu.common.ApiException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;
import java.time.*;
import java.util.*;

/**
 * Computes bookable slots. Pure read logic; the authoritative double-booking guard is the PostgreSQL
 * exclusion constraint on bookings, this service only decides what to OFFER.
 *
 * Model: branch working hours per ISO weekday, employees eligible for (branch, service), their active
 * bookings (including service buffer) and time off. All calculation happens in the branch timezone.
 */
@Service
public class AvailabilityService {
    public static final int SLOT_STEP_MINUTES = 15;
    private final JdbcClient jdbc;

    public AvailabilityService(JdbcClient jdbc) { this.jdbc = jdbc; }

    public record Slot(Instant start, List<UUID> employeeIds) {}

    private record Interval(Instant start, Instant end) {
        boolean overlaps(Instant s, Instant e) { return start.isBefore(e) && s.isBefore(end); }
    }

    /**
     * @param excludeBookingId booking to ignore (used when rescheduling)
     * @param applyOnlineRules enforce min-notice / max-advance (public booking); staff only need "not in the past"
     */
    public List<Slot> slots(UUID businessId, UUID branchId, UUID serviceId, UUID employeeId, LocalDate date,
                            Instant now, UUID excludeBookingId, boolean applyOnlineRules) {
        var branch = jdbc.sql("select timezone from branches where id = :id and business_id = :b and active")
                .param("id", branchId).param("b", businessId).query(String.class).optional()
                .orElseThrow(() -> ApiException.notFound("Branch"));
        var svc = jdbc.sql("select duration_minutes, buffer_minutes from services where id = :id and business_id = :b and active")
                .param("id", serviceId).param("b", businessId)
                .query((rs, i) -> new int[]{rs.getInt(1), rs.getInt(2)}).optional()
                .orElseThrow(() -> ApiException.notFound("Service"));
        var rules = jdbc.sql("select min_notice_minutes, max_advance_days from businesses where id = :b")
                .param("b", businessId).query((rs, i) -> new int[]{rs.getInt(1), rs.getInt(2)}).single();

        ZoneId zone = ZoneId.of(branch);
        var hours = jdbc.sql("select open_time, close_time from branch_hours where branch_id = :id and day_of_week = :d")
                .param("id", branchId).param("d", date.getDayOfWeek().getValue())
                .query((rs, i) -> new LocalTime[]{rs.getObject(1, LocalTime.class), rs.getObject(2, LocalTime.class)}).optional();
        if (hours.isEmpty()) return List.of();

        List<UUID> employees = jdbc.sql("""
                select e.id from employees e
                join employee_branches eb on eb.employee_id = e.id and eb.branch_id = :br
                join employee_services es on es.employee_id = e.id and es.service_id = :sv
                where e.business_id = :b and e.active and (cast(:emp as uuid) is null or e.id = :emp)
                order by e.display_name, e.id
                """).param("br", branchId).param("sv", serviceId).param("b", businessId).param("emp", employeeId, java.sql.Types.OTHER)
                .query(UUID.class).list();
        if (employees.isEmpty()) return List.of();

        ZonedDateTime open = ZonedDateTime.of(date, hours.get()[0], zone);
        ZonedDateTime close = ZonedDateTime.of(date, hours.get()[1], zone);
        Instant windowStart = open.toInstant().minus(Duration.ofDays(1));
        Instant windowEnd = close.toInstant().plus(Duration.ofDays(1));

        Map<UUID, List<Interval>> busy = new HashMap<>();
        jdbc.sql("""
                select employee_id, starts_at, blocked_until from bookings
                where business_id = :b and employee_id in (:ids)
                  and status in ('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS')
                  and starts_at < :we and blocked_until > :ws
                  and (cast(:ex as uuid) is null or id <> :ex)
                """).param("b", businessId).param("ids", employees)
                .param("we", Timestamp.from(windowEnd)).param("ws", Timestamp.from(windowStart))
                .param("ex", excludeBookingId, java.sql.Types.OTHER)
                .query((rs, i) -> {
                    busy.computeIfAbsent(rs.getObject(1, UUID.class), k -> new ArrayList<>())
                            .add(new Interval(rs.getTimestamp(2).toInstant(), rs.getTimestamp(3).toInstant()));
                    return 0;
                }).list();
        jdbc.sql("""
                select employee_id, starts_at, ends_at from employee_time_off
                where business_id = :b and employee_id in (:ids) and starts_at < :we and ends_at > :ws
                """).param("b", businessId).param("ids", employees)
                .param("we", Timestamp.from(windowEnd)).param("ws", Timestamp.from(windowStart))
                .query((rs, i) -> {
                    busy.computeIfAbsent(rs.getObject(1, UUID.class), k -> new ArrayList<>())
                            .add(new Interval(rs.getTimestamp(2).toInstant(), rs.getTimestamp(3).toInstant()));
                    return 0;
                }).list();

        // Personal schedules: no rows = follows the branch; rows = only inside one of that weekday's ranges (a service cannot span a break).
        Map<UUID, List<LocalTime[]>> personal = new HashMap<>();
        Set<UUID> hasSchedule = new HashSet<>(jdbc.sql("select distinct employee_id from employee_hours where employee_id in (:ids)").param("ids", employees).query(UUID.class).list());
        if (!hasSchedule.isEmpty()) {
            jdbc.sql("select employee_id, start_time, end_time from employee_hours where employee_id in (:ids) and day_of_week = :d")
                    .param("ids", employees).param("d", date.getDayOfWeek().getValue())
                    .query((rs, i) -> {
                        personal.computeIfAbsent(rs.getObject(1, UUID.class), k -> new ArrayList<>()).add(new LocalTime[]{rs.getObject(2, LocalTime.class), rs.getObject(3, LocalTime.class)});
                        return 0;
                    }).list();
        }

        Instant earliest = applyOnlineRules ? now.plus(Duration.ofMinutes(rules[0])) : now;
        Instant latest = applyOnlineRules ? now.plus(Duration.ofDays(rules[1])) : Instant.MAX;

        Duration duration = Duration.ofMinutes(svc[0]);
        Duration blocked = Duration.ofMinutes(svc[0] + svc[1]);
        List<Slot> result = new ArrayList<>();
        for (ZonedDateTime t = open; !t.plus(duration).isAfter(close); t = t.plusMinutes(SLOT_STEP_MINUTES)) {
            Instant start = t.toInstant();
            if (start.isBefore(earliest) || start.isAfter(latest)) continue;
            Instant blockedUntil = start.plus(blocked);
            List<UUID> free = new ArrayList<>();
            LocalTime slotStart = t.toLocalTime(), slotEnd = t.plus(duration).toLocalTime();
            boolean sameDay = t.plus(duration).toLocalDate().equals(date);
            for (UUID e : employees) {
                if (hasSchedule.contains(e)) {
                    boolean inside = sameDay && personal.getOrDefault(e, List.of()).stream().anyMatch(r -> !slotStart.isBefore(r[0]) && !slotEnd.isAfter(r[1]));
                    if (!inside) continue;
                }
                boolean clash = busy.getOrDefault(e, List.of()).stream().anyMatch(iv -> iv.overlaps(start, blockedUntil));
                if (!clash) free.add(e);
            }
            if (!free.isEmpty()) result.add(new Slot(start, free));
        }
        return result;
    }
}
