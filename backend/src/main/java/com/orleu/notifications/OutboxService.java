package com.orleu.notifications;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Transactional outbox: events are written in the SAME transaction as the business change, so they are
 * committed iff the change is. Delivery happens later in {@link OutboxProcessor}; a delivery failure can
 * therefore never roll back a booking.
 */
@Service
public class OutboxService {
    private final JdbcClient jdbc;

    public OutboxService(JdbcClient jdbc) { this.jdbc = jdbc; }

    /** Idempotent: the same dedupeKey is stored once. Must be called inside the caller's transaction. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void publish(UUID businessId, String eventType, UUID bookingId, String dedupeKey) {
        jdbc.sql("""
            insert into outbox_events (business_id, event_type, booking_id, dedupe_key)
            values (:b, :t, :bk, :k) on conflict (dedupe_key) do nothing
            """).param("b", businessId).param("t", eventType).param("bk", bookingId, java.sql.Types.OTHER).param("k", dedupeKey).update();
    }
}
