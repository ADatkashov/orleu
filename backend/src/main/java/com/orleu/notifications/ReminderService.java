package com.orleu.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Publishes one BOOKING_REMINDER outbox event per upcoming CONFIRMED booking once it enters the business's reminder
 * window (reminder_hours, 0 = off). The dedupe key contains the start time, so a rescheduled booking is reminded
 * again for its new time but never twice for the same time, however often or on however many instances this runs.
 */
@Component
public class ReminderService {
    private static final Logger log = LoggerFactory.getLogger(ReminderService.class);
    private final JdbcClient jdbc;
    private final OutboxService outbox;

    public ReminderService(JdbcClient jdbc, OutboxService outbox) { this.jdbc = jdbc; this.outbox = outbox; }

    private record Due(UUID businessId, UUID bookingId, long startMillis) {}

    @Transactional
    public int scheduleDue() {
        List<Due> due = jdbc.sql("""
            select b.business_id, b.id, (extract(epoch from b.starts_at) * 1000)::bigint
            from bookings b join businesses bz on bz.id = b.business_id
            where b.status = 'CONFIRMED' and bz.reminder_hours > 0
              and b.starts_at > now() and b.starts_at <= now() + (bz.reminder_hours * interval '1 hour')
            """).query((rs, i) -> new Due(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getLong(3))).list();
        for (Due d : due) outbox.publish(d.businessId(), "BOOKING_REMINDER", d.bookingId(), "BOOKING_REMINDER:" + d.bookingId() + ":" + d.startMillis());
        return due.size();
    }

    @Scheduled(fixedDelayString = "${orleu.jobs.reminder-interval:PT5M}")
    public void run() {
        try { scheduleDue(); } catch (Exception e) { log.error("Reminder scheduling failed", e); }
    }
}
