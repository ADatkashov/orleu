package com.orleu.notifications;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

/**
 * Creates the in-app notification shown to the business. UNIQUE(event_id) makes redelivery harmless.
 * Customer-facing SMS/e-mail/push are NOT implemented: they need provider accounts (see IMPLEMENTATION_STATUS).
 */
@Component
public class InAppNotificationHandler implements OutboxHandler {
    private final JdbcClient jdbc;

    public InAppNotificationHandler(JdbcClient jdbc) { this.jdbc = jdbc; }

    @Override
    public void handle(Event e) {
        jdbc.sql("""
            insert into notifications (business_id, event_id, event_type, booking_id)
            values (:b, :e, :t, :bk) on conflict (event_id) do nothing
            """).param("b", e.businessId()).param("e", e.id()).param("t", e.type())
            .param("bk", e.bookingId(), java.sql.Types.OTHER).update();
    }
}
