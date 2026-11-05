package com.orleu.it;

import com.orleu.notifications.OutboxHandler;
import com.orleu.notifications.OutboxProcessor;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import static org.junit.jupiter.api.Assertions.*;

@Import(NotificationsIT.Failing.class)
class NotificationsIT extends AbstractIT {
    static final Set<UUID> FAIL_FOR = ConcurrentHashMap.newKeySet();

    @TestConfiguration
    static class Failing {
        @Bean OutboxHandler failingHandler() {
            return e -> { if (FAIL_FOR.contains(e.businessId())) throw new IllegalStateException("provider down"); };
        }
    }

    @Autowired OutboxProcessor processor;

    private Res book(Fixture f, int h) {
        return post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), h, 0).toString(), "customer", f.customer("+7701000" + (3000 + h))), f.businessId);
    }

    private int count(String sql, Object... a) { return jdbc.queryForObject(sql, Integer.class, a); }

    @Test void bookingEventsBecomeExactlyOneInAppNotificationEach() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 10).id();
        assertEquals(1, count("select count(*) from outbox_events where business_id = ? and status = 'PENDING'", f.businessId));
        assertEquals(0, get(f.ownerToken, "/api/v1/businesses/%s/notifications", f.businessId).body().size()); // not delivered yet
        processor.processDue();
        processor.processDue(); // redelivery attempt must not duplicate
        Res list = get(f.ownerToken, "/api/v1/businesses/%s/notifications", f.businessId);
        assertEquals(1, list.body().size());
        assertEquals("BOOKING_CREATED", list.body().get(0).path("eventType").asText());
        assertEquals(id.toString(), list.body().get(0).path("bookingId").asText());

        post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), f.businessId, id);
        processor.processDue();
        assertEquals(2, get(f.ownerToken, "/api/v1/businesses/%s/notifications", f.businessId).body().size());

        UUID nid = UUID.fromString(list.body().get(0).path("id").asText());
        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/notifications/%s/read", null, f.businessId, nid).status());
        assertEquals(1, get(f.ownerToken, "/api/v1/businesses/%s/notifications?unreadOnly=true", f.businessId).body().size());
    }

    @Test void paymentRetriesDoNotMultiplyEvents() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 11).id();
        for (int i = 0; i < 3; i++) {
            call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + id + "/payments"),
                    f.ownerToken, Map.of("amount", "500", "method", "CASH"), "Idempotency-Key", "ev-pay-1");
        }
        assertEquals(1, count("select count(*) from outbox_events where business_id = ? and event_type = 'PAYMENT_RECEIVED'", f.businessId));
    }

    @Test void notificationsAreTenantIsolated() {
        Fixture a = Fixture.create(this, 1, false), b = Fixture.create(this, 1, false);
        UUID booking = book(a, 10).id();
        processor.processDue();
        UUID nid = jdbc.queryForObject("select id from notifications where booking_id = ?", UUID.class, booking);
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/notifications", a.businessId).status());
        assertEquals(404, post(b.ownerToken, "/api/v1/businesses/%s/notifications/%s/read", null, b.businessId, nid).status()); // own tenant, foreign id
        assertEquals(0, get(b.ownerToken, "/api/v1/businesses/%s/notifications", b.businessId).body().size());
    }

    @Test void failingDeliveryNeverRollsBackTheBookingAndEndsInDeadLetter() {
        Fixture f = Fixture.create(this, 1, false);
        FAIL_FOR.add(f.businessId);
        try {
            Res b = book(f, 10);
            assertEquals(201, b.status());          // booking committed regardless of delivery
            for (int round = 1; round <= 5; round++) {
                processor.processDue();
                var row = jdbc.queryForMap("select status, attempts, last_error from outbox_events where business_id = ?", f.businessId);
                assertEquals(round, ((Number) row.get("attempts")).intValue());
                assertEquals(round < 5 ? "PENDING" : "DEAD", row.get("status"));
                assertTrue(row.get("last_error").toString().contains("provider down"));
                // backoff: not due again immediately
                assertEquals(0, processor.processDue());
                jdbc.update("update outbox_events set next_attempt_at = now() - interval '1 second' where business_id = ?", f.businessId);
            }
            assertEquals("CONFIRMED", get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s", f.businessId, b.id()).text("status"));
            assertEquals(0, count("select count(*) from notifications where business_id = ?", f.businessId));
        } finally {
            FAIL_FOR.remove(f.businessId);
        }
    }

    @Test void recoversAfterTransientFailure() {
        Fixture f = Fixture.create(this, 1, false);
        FAIL_FOR.add(f.businessId);
        book(f, 10);
        processor.processDue();
        FAIL_FOR.remove(f.businessId);
        jdbc.update("update outbox_events set next_attempt_at = now() - interval '1 second' where business_id = ?", f.businessId);
        assertEquals(1, processor.processDue());
        assertEquals(1, count("select count(*) from notifications where business_id = ?", f.businessId));
        assertEquals(2, count("select attempts from outbox_events where business_id = ?", f.businessId));
    }
}
