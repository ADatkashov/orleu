package com.orleu.notifications;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Optional;

/**
 * Renders the customer-facing text for booking events and stores it in customer_messages (status NOT_SENT).
 * Actual SMS/e-mail/WhatsApp delivery needs provider accounts and is NOT implemented; this never marks anything sent.
 * UNIQUE(event_id) makes redelivery harmless.
 */
@Component
public class CustomerMessageHandler implements OutboxHandler {
    private static final DateTimeFormatter WHEN = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");
    private final JdbcClient jdbc;

    public CustomerMessageHandler(JdbcClient jdbc) { this.jdbc = jdbc; }

    private record Row(String customerName, String phone, String business, String service, java.time.Instant startsAt, String tz, String locale, String status) {}

    @Override
    public void handle(Event e) {
        // Auto-confirmed bookings only ever publish BOOKING_CREATED: treat it as the confirmation, but only if still confirmed.
        String type = "BOOKING_CREATED".equals(e.type()) ? "BOOKING_CONFIRMED" : e.type();
        if (e.bookingId() == null || !MessageTemplates.handles(type)) return;
        Optional<Row> row = jdbc.sql("""
            select c.full_name, c.phone, bz.name, s.name, b.starts_at, bz.timezone, bz.customer_locale, b.status
            from bookings b
            join customers c on c.id = b.customer_id and c.business_id = b.business_id
            join services s on s.id = b.service_id and s.business_id = b.business_id
            join businesses bz on bz.id = b.business_id
            where b.id = :id and b.business_id = :biz
            """).param("id", e.bookingId()).param("biz", e.businessId())
            .query((rs, i) -> new Row(rs.getString(1), rs.getString(2), rs.getString(3), rs.getString(4),
                    rs.getTimestamp(5).toInstant(), rs.getString(6), rs.getString(7), rs.getString(8))).optional();
        if (row.isEmpty()) return;
        Row r = row.get();
        // Never tell a customer about a state the booking is no longer in (e.g. a reminder for a booking cancelled meanwhile).
        boolean needsConfirmed = type.equals("BOOKING_CONFIRMED") && "BOOKING_CREATED".equals(e.type()) || type.equals("BOOKING_REMINDER");
        if (needsConfirmed && !r.status().equals("CONFIRMED")) return;
        String when = WHEN.format(r.startsAt().atZone(ZoneId.of(r.tz())));
        String body = MessageTemplates.render(type, r.locale(),
                new MessageTemplates.Context(r.customerName(), r.business(), r.service(), when)).orElseThrow();
        jdbc.sql("""
            insert into customer_messages (business_id, event_id, booking_id, message_type, locale, recipient_phone, body)
            values (:biz, :ev, :bk, :t, :l, :p, :body) on conflict (event_id) do nothing
            """).param("biz", e.businessId()).param("ev", e.id()).param("bk", e.bookingId()).param("t", type)
            .param("l", r.locale()).param("p", r.phone()).param("body", body).update();
    }
}
