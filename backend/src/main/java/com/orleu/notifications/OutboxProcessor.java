package com.orleu.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.List;
import java.util.UUID;

/**
 * Delivers outbox events. Each event is handled in its own transaction (a failing handler leaves no partial
 * writes), with exponential backoff (30s, 1m, 2m, 4m ...) and dead-lettering after {@link #MAX_ATTEMPTS}.
 * Rows are claimed with FOR UPDATE SKIP LOCKED so several instances can run safely.
 */
@Component
public class OutboxProcessor {
    static final int MAX_ATTEMPTS = 5;
    private static final Logger log = LoggerFactory.getLogger(OutboxProcessor.class);

    private final JdbcClient jdbc;
    private final List<OutboxHandler> handlers;
    private final TransactionTemplate tx;

    public OutboxProcessor(JdbcClient jdbc, List<OutboxHandler> handlers, PlatformTransactionManager tm) {
        this.jdbc = jdbc;
        this.handlers = handlers;
        this.tx = new TransactionTemplate(tm);
    }

    @Scheduled(fixedDelayString = "${orleu.jobs.outbox-interval:PT5S}")
    public void scheduled() {
        try { processDue(); } catch (Exception e) { log.error("Outbox run failed", e); }
    }

    /** @return number of events delivered successfully */
    public int processDue() {
        List<UUID> due = jdbc.sql("select id from outbox_events where status = 'PENDING' and next_attempt_at <= now() order by created_at limit 50")
                .query(UUID.class).list();
        int ok = 0;
        for (UUID id : due) {
            try {
                Boolean done = tx.execute(s -> deliver(id));
                if (Boolean.TRUE.equals(done)) ok++;
            } catch (Exception e) {
                String msg = (e.getClass().getSimpleName() + ": " + e.getMessage());
                tx.executeWithoutResult(s -> markFailed(id, msg.substring(0, Math.min(500, msg.length()))));
            }
        }
        return ok;
    }

    private boolean deliver(UUID id) {
        var ev = jdbc.sql("""
            select id, business_id, event_type, booking_id from outbox_events
            where id = :id and status = 'PENDING' for update skip locked
            """).param("id", id)
            .query((rs, i) -> new OutboxHandler.Event(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class),
                    rs.getString(3), rs.getObject(4, UUID.class))).optional();
        if (ev.isEmpty()) return false; // already handled or locked by another instance
        for (OutboxHandler h : handlers) h.handle(ev.get());
        jdbc.sql("update outbox_events set status = 'DONE', processed_at = now(), attempts = attempts + 1 where id = :id").param("id", id).update();
        return true;
    }

    private void markFailed(UUID id, String error) {
        jdbc.sql("""
            update outbox_events set attempts = attempts + 1, last_error = :e,
              status = case when attempts + 1 >= :max then 'DEAD' else 'PENDING' end,
              next_attempt_at = now() + (interval '30 seconds' * power(2, least(attempts, 10)))
            where id = :id and status = 'PENDING'
            """).param("e", error).param("max", MAX_ATTEMPTS).param("id", id).update();
        log.warn("Outbox event {} failed: {}", id, error);
    }
}
