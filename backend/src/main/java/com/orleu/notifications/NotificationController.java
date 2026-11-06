package com.orleu.notifications;

import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.*;
import com.orleu.common.ApiException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** In-app notifications. The client renders text from eventType (localized kk/ru/en on the client). */
@RestController
@RequestMapping("/api/v1/businesses/{businessId}/notifications")
public class NotificationController {
    public record NotificationView(UUID id, String eventType, UUID bookingId, Instant createdAt, boolean read,
                                   String customerName, String serviceName, Instant startsAt) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;

    public NotificationController(TenantAccess access, JdbcClient jdbc) { this.access = access; this.jdbc = jdbc; }

    @GetMapping
    public List<NotificationView> list(@PathVariable UUID businessId, @RequestParam(defaultValue = "false") boolean unreadOnly) {
        var membership = access.require(businessId, Permission.BOOKINGS_VIEW);
        // support replies concern the people who can open support requests (owners/admins), not every staff role
        boolean seesSupport = membership.getRole().allows(Permission.BUSINESS_MANAGE);
        return jdbc.sql("""
            select n.id, n.event_type, n.booking_id, n.created_at, n.read_at is not null as is_read, c.full_name, s.name, b.starts_at
            from notifications n
            left join bookings b on b.id = n.booking_id and b.business_id = n.business_id
            left join customers c on c.id = b.customer_id and c.business_id = b.business_id
            left join services s on s.id = b.service_id and s.business_id = b.business_id
            where n.business_id = :b and (not :u or n.read_at is null) and (:support or n.event_type <> 'SUPPORT_REPLIED')
            order by n.created_at desc limit 100
            """).param("b", businessId).param("u", unreadOnly).param("support", seesSupport)
            .query((rs, i) -> new NotificationView(rs.getObject(1, UUID.class), rs.getString(2), rs.getObject(3, UUID.class),
                    rs.getTimestamp(4).toInstant(), rs.getBoolean(5), rs.getString(6), rs.getString(7),
                    rs.getTimestamp(8) == null ? null : rs.getTimestamp(8).toInstant())).list();
    }

    @PostMapping("/read-all") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markAllRead(@PathVariable UUID businessId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        jdbc.sql("update notifications set read_at = now() where business_id = :b and read_at is null").param("b", businessId).update();
    }

    @PostMapping("/{id}/read") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@PathVariable UUID businessId, @PathVariable UUID id) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        int n = jdbc.sql("update notifications set read_at = coalesce(read_at, now()) where id = :id and business_id = :b")
                .param("id", id).param("b", businessId).update();
        if (n == 0) throw ApiException.notFound("Notification");
    }

    public record MessageView(UUID id, String messageType, UUID bookingId, String locale, String recipientPhone, String body, String status, Instant createdAt) {}

    /** The customer messages the system has prepared. Status NOT_SENT = no delivery provider is configured yet. */
    @GetMapping("/customer-messages")
    public List<MessageView> customerMessages(@PathVariable UUID businessId) {
        access.require(businessId, Permission.CUSTOMERS_VIEW); // contains customer phone numbers
        return jdbc.sql("""
            select id, message_type, booking_id, locale, recipient_phone, body, status, created_at from customer_messages
            where business_id = :b order by created_at desc limit 100
            """).param("b", businessId)
            .query((rs, i) -> new MessageView(rs.getObject(1, UUID.class), rs.getString(2), rs.getObject(3, UUID.class), rs.getString(4),
                    rs.getString(5), rs.getString(6), rs.getString(7), rs.getTimestamp(8).toInstant())).list();
    }
}
