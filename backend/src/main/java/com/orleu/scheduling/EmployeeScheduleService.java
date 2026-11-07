package com.orleu.scheduling;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.util.*;

/**
 * Personal schedules: weekly working ranges per specialist (several ranges per day = breaks) and time off. The availability service applies them;
 * changing a schedule never cancels existing bookings, it only reports how many upcoming bookings no longer fit so staff can move them.
 */
@Service
public class EmployeeScheduleService {
    static final int MAX_RANGES_PER_DAY = 6;

    public record Range(int dayOfWeek, LocalTime start, LocalTime end) {}
    public record TimeOff(UUID id, Instant startsAt, Instant endsAt, String reason, int affectedBookings) {}
    public record DateRange(LocalTime start, LocalTime end) {}
    public record DateException(LocalDate date, boolean dayOff, List<DateRange> ranges) {}
    public record ExceptionResult(DateException exception, int affectedBookings) {}
    public record Schedule(List<Range> hours, List<TimeOff> timeOff, List<DateException> exceptions) {}
    public record HoursResult(List<Range> hours, int affectedBookings) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;

    public EmployeeScheduleService(TenantAccess access, JdbcClient jdbc, AuditService audit) { this.access = access; this.jdbc = jdbc; this.audit = audit; }

    private void requireEmployee(UUID businessId, UUID employeeId) {
        boolean ok = jdbc.sql("select exists(select 1 from employees where id = :e and business_id = :b)").param("e", employeeId).param("b", businessId).query(Boolean.class).single();
        if (!ok) throw ApiException.notFound("Employee");
    }

    @Transactional(readOnly = true)
    public Schedule get(UUID businessId, UUID employeeId) {
        access.require(businessId, Permission.STAFF_MANAGE);
        requireEmployee(businessId, employeeId);
        List<TimeOff> off = jdbc.sql("select id, starts_at, ends_at, reason from employee_time_off where employee_id = :e and business_id = :b and ends_at > now() order by starts_at")
                .param("e", employeeId).param("b", businessId)
                .query((rs, i) -> {
                    Instant s = rs.getTimestamp(2).toInstant(), e = rs.getTimestamp(3).toInstant();
                    return new TimeOff(rs.getObject(1, UUID.class), s, e, rs.getString(4), countBookings(businessId, employeeId, s, e));
                }).list();
        return new Schedule(hours(employeeId), off, exceptions(employeeId));
    }

    /** Exceptions from yesterday on (the business-local date may lag UTC), grouped per date. */
    private List<DateException> exceptions(UUID employeeId) {
        record Row(LocalDate date, boolean dayOff, LocalTime start, LocalTime end) {}
        List<Row> rows = jdbc.sql("select on_date, day_off, start_time, end_time from employee_date_exceptions where employee_id = :e and on_date >= :from order by on_date, start_time")
                .param("e", employeeId).param("from", LocalDate.now(ZoneOffset.UTC).minusDays(1))
                .query((rs, i) -> new Row(rs.getObject(1, LocalDate.class), rs.getBoolean(2), rs.getObject(3, LocalTime.class), rs.getObject(4, LocalTime.class))).list();
        Map<LocalDate, List<Row>> byDate = new LinkedHashMap<>();
        rows.forEach(r -> byDate.computeIfAbsent(r.date(), k -> new ArrayList<>()).add(r));
        return byDate.entrySet().stream().map(e -> new DateException(e.getKey(), e.getValue().get(0).dayOff(),
                e.getValue().stream().filter(r -> !r.dayOff()).map(r -> new DateRange(r.start(), r.end())).toList())).toList();
    }

    /**
     * Replaces the schedule of ONE date: either a day off, or one or more working ranges that replace that weekday's weekly ranges.
     * Existing bookings are never cancelled; the result says how many that day no longer fit.
     */
    @Transactional
    public ExceptionResult setException(UUID businessId, UUID employeeId, LocalDate date, boolean dayOff, List<DateRange> ranges) {
        access.require(businessId, Permission.STAFF_MANAGE);
        requireEmployee(businessId, employeeId);
        if (date.isBefore(LocalDate.now(ZoneOffset.UTC).minusDays(1))) throw ApiException.badRequest("PAST_DATE", "The date is in the past");
        List<DateRange> sorted = new ArrayList<>(ranges == null ? List.<DateRange>of() : ranges);
        if (dayOff && !sorted.isEmpty()) throw ApiException.badRequest("INVALID_EXCEPTION", "A day off has no working ranges");
        if (!dayOff && sorted.isEmpty()) throw ApiException.badRequest("INVALID_EXCEPTION", "Give at least one working range, or mark the day off");
        if (sorted.size() > MAX_RANGES_PER_DAY) throw ApiException.badRequest("TOO_MANY_RANGES", "At most " + MAX_RANGES_PER_DAY + " ranges per day");
        for (DateRange r : sorted) if (r.start() == null || r.end() == null || !r.end().isAfter(r.start())) throw ApiException.badRequest("INVALID_RANGE", "end must be after start");
        sorted.sort(Comparator.comparing(DateRange::start));
        for (int i = 1; i < sorted.size(); i++) if (sorted.get(i).start().isBefore(sorted.get(i - 1).end())) throw ApiException.badRequest("OVERLAPPING_RANGES", "Working ranges of one day must not overlap");
        jdbc.sql("delete from employee_date_exceptions where employee_id = :e and business_id = :b and on_date = :d").param("e", employeeId).param("b", businessId).param("d", date).update();
        if (dayOff) {
            jdbc.sql("insert into employee_date_exceptions (business_id, employee_id, on_date, day_off) values (:b, :e, :d, true)").param("b", businessId).param("e", employeeId).param("d", date).update();
        } else for (DateRange r : sorted) {
            jdbc.sql("insert into employee_date_exceptions (business_id, employee_id, on_date, day_off, start_time, end_time) values (:b, :e, :d, false, :s, :en)")
                    .param("b", businessId).param("e", employeeId).param("d", date).param("s", r.start()).param("en", r.end()).update();
        }
        audit.log(businessId, CurrentUser.id(), "EMPLOYEE_DATE_EXCEPTION_SET", "EMPLOYEE", employeeId, "{\"date\":\"" + date + "\"}");
        return new ExceptionResult(new DateException(date, dayOff, sorted), bookingsOutsideOnDate(businessId, employeeId, date, dayOff ? List.of() : sorted));
    }

    @Transactional
    public void deleteException(UUID businessId, UUID employeeId, LocalDate date) {
        access.require(businessId, Permission.STAFF_MANAGE);
        requireEmployee(businessId, employeeId);
        int n = jdbc.sql("delete from employee_date_exceptions where employee_id = :e and business_id = :b and on_date = :d").param("e", employeeId).param("b", businessId).param("d", date).update();
        if (n == 0) throw ApiException.notFound("Exception");
        audit.log(businessId, CurrentUser.id(), "EMPLOYEE_DATE_EXCEPTION_REMOVED", "EMPLOYEE", employeeId, "{\"date\":\"" + date + "\"}");
    }

    private int bookingsOutsideOnDate(UUID businessId, UUID employeeId, LocalDate date, List<DateRange> ranges) {
        record B(Instant start, Instant end, String tz) {}
        List<B> bookings = jdbc.sql("""
            select b.starts_at, b.ends_at, br.timezone from bookings b join branches br on br.id = b.branch_id and br.business_id = b.business_id
            where b.business_id = :b and b.employee_id = :e and b.starts_at > now() - interval '2 days' and b.starts_at < now() + interval '400 days'
              and b.status in ('PENDING','AWAITING_PAYMENT','CONFIRMED') and b.ends_at > now()
            """).param("b", businessId).param("e", employeeId)
                .query((rs, i) -> new B(rs.getTimestamp(1).toInstant(), rs.getTimestamp(2).toInstant(), rs.getString(3))).list();
        int outside = 0;
        for (B b : bookings) {
            ZonedDateTime s = b.start().atZone(ZoneId.of(b.tz())), e = b.end().atZone(ZoneId.of(b.tz()));
            if (!s.toLocalDate().equals(date)) continue;
            boolean fits = e.toLocalDate().equals(date) && ranges.stream().anyMatch(r -> !s.toLocalTime().isBefore(r.start()) && !e.toLocalTime().isAfter(r.end()));
            if (!fits) outside++;
        }
        return outside;
    }

    private List<Range> hours(UUID employeeId) {
        return jdbc.sql("select day_of_week, start_time, end_time from employee_hours where employee_id = :e order by day_of_week, start_time").param("e", employeeId)
                .query((rs, i) -> new Range(rs.getInt(1), rs.getObject(2, LocalTime.class), rs.getObject(3, LocalTime.class))).list();
    }

    /** Replaces the whole weekly schedule. An empty list means "follow the branch hours". */
    @Transactional
    public HoursResult setHours(UUID businessId, UUID employeeId, List<Range> ranges) {
        access.require(businessId, Permission.STAFF_MANAGE);
        requireEmployee(businessId, employeeId);
        Map<Integer, List<Range>> byDay = new TreeMap<>();
        for (Range r : ranges) {
            if (r.dayOfWeek() < 1 || r.dayOfWeek() > 7) throw ApiException.badRequest("INVALID_DAY", "dayOfWeek must be 1 (Monday) to 7 (Sunday)");
            if (r.start() == null || r.end() == null || !r.end().isAfter(r.start())) throw ApiException.badRequest("INVALID_RANGE", "end must be after start");
            byDay.computeIfAbsent(r.dayOfWeek(), k -> new ArrayList<>()).add(r);
        }
        for (var e : byDay.entrySet()) {
            List<Range> day = e.getValue();
            if (day.size() > MAX_RANGES_PER_DAY) throw ApiException.badRequest("TOO_MANY_RANGES", "At most " + MAX_RANGES_PER_DAY + " ranges per day");
            day.sort(Comparator.comparing(Range::start));
            for (int i = 1; i < day.size(); i++) {
                if (day.get(i).start().isBefore(day.get(i - 1).end())) throw ApiException.badRequest("OVERLAPPING_RANGES", "Working ranges of one day must not overlap");
            }
        }
        jdbc.sql("delete from employee_hours where employee_id = :e").param("e", employeeId).update();
        for (List<Range> day : byDay.values()) for (Range r : day) {
            jdbc.sql("insert into employee_hours (business_id, employee_id, day_of_week, start_time, end_time) values (:b, :e, :d, :s, :en)")
                    .param("b", businessId).param("e", employeeId).param("d", r.dayOfWeek()).param("s", r.start()).param("en", r.end()).update();
        }
        int affected = byDay.isEmpty() ? 0 : bookingsOutside(businessId, employeeId, byDay);
        audit.log(businessId, CurrentUser.id(), "EMPLOYEE_HOURS_SET", "EMPLOYEE", employeeId, null);
        return new HoursResult(hours(employeeId), affected);
    }

    @Transactional
    public void deleteTimeOff(UUID businessId, UUID employeeId, UUID timeOffId) {
        access.require(businessId, Permission.STAFF_MANAGE);
        int n = jdbc.sql("delete from employee_time_off where id = :id and employee_id = :e and business_id = :b").param("id", timeOffId).param("e", employeeId).param("b", businessId).update();
        if (n == 0) throw ApiException.notFound("Time off");
        audit.log(businessId, CurrentUser.id(), "EMPLOYEE_TIME_OFF_REMOVED", "EMPLOYEE", employeeId, null);
    }

    private int countBookings(UUID businessId, UUID employeeId, Instant from, Instant to) {
        return jdbc.sql("""
            select count(*) from bookings where business_id = :b and employee_id = :e and status in ('PENDING','AWAITING_PAYMENT','CONFIRMED')
              and starts_at < :to and ends_at > :from and ends_at > now()
            """).param("b", businessId).param("e", employeeId).param("from", java.sql.Timestamp.from(from)).param("to", java.sql.Timestamp.from(to)).query(Integer.class).single();
    }

    /** Upcoming active bookings of the specialist that do not fit entirely inside one working range of their (branch-local) weekday. */
    private int bookingsOutside(UUID businessId, UUID employeeId, Map<Integer, List<Range>> byDay) {
        record B(Instant start, Instant end, String tz) {}
        List<B> bookings = jdbc.sql("""
            select b.starts_at, b.ends_at, br.timezone from bookings b join branches br on br.id = b.branch_id and br.business_id = b.business_id
            where b.business_id = :b and b.employee_id = :e and b.starts_at > now() and b.status in ('PENDING','AWAITING_PAYMENT','CONFIRMED')
            """).param("b", businessId).param("e", employeeId)
                .query((rs, i) -> new B(rs.getTimestamp(1).toInstant(), rs.getTimestamp(2).toInstant(), rs.getString(3))).list();
        int outside = 0;
        for (B b : bookings) {
            ZoneId zone = ZoneId.of(b.tz());
            ZonedDateTime s = b.start().atZone(zone), e = b.end().atZone(zone);
            List<Range> day = byDay.getOrDefault(s.getDayOfWeek().getValue(), List.of());
            boolean fits = e.toLocalDate().equals(s.toLocalDate()) && day.stream().anyMatch(r -> !s.toLocalTime().isBefore(r.start()) && !e.toLocalTime().isAfter(r.end()));
            if (!fits) outside++;
        }
        return outside;
    }
}
