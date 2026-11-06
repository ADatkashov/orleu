package com.orleu.it;

import com.orleu.notifications.OutboxProcessor;
import com.orleu.notifications.ReminderService;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CustomerMessagesIT extends AbstractIT {
    @Autowired OutboxProcessor processor;
    @Autowired ReminderService reminders;

    @BeforeEach void clearForeignBacklog() { jdbc.update("delete from outbox_events where status = 'PENDING'"); }

    private UUID book(Fixture f, int h, String phone) {
        Res r = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), h, 0).toString(), "customer", Map.of("fullName", "Aigerim", "phone", phone)), f.businessId);
        assertEquals(201, r.status(), r.body().toString());
        return r.id();
    }

    private int messages(Fixture f, String type) {
        return jdbc.queryForObject("select count(*) from customer_messages where business_id = ? and message_type = ?", Integer.class, f.businessId, type);
    }

    @Test void bookingEventsBecomeLocalizedUnsentCustomerMessagesAndRedeliveryDoesNotDuplicate() {
        Fixture f = Fixture.create(this, 1, false);
        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("customerLocale", "kk"), f.businessId).status());
        UUID id = book(f, 10, "+77010009001");
        processor.processDue();
        processor.processDue();
        assertEquals(1, messages(f, "BOOKING_CONFIRMED")); // auto-confirmed booking: BOOKING_CREATED is the confirmation
        post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), f.businessId, id);
        processor.processDue();
        assertEquals(1, messages(f, "BOOKING_CANCELLED"));

        Res list = get(f.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages", f.businessId);
        assertEquals(200, list.status());
        assertEquals(2, list.body().size());
        for (var m : list.body()) {
            assertEquals("NOT_SENT", m.path("status").asText(), "no provider is configured, so nothing may claim to be sent");
            assertEquals("kk", m.path("locale").asText());
            assertEquals("+77010009001", m.path("recipientPhone").asText());
            assertTrue(m.path("body").asText().contains("Сәлеметсіз бе"), m.path("body").asText());
        }
    }

    @Test void reminderIsScheduledOncePerStartTimeAndAgainAfterReschedule() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 10, "+77010009002");
        processor.processDue(); // drain creation event
        jdbc.update("update businesses set reminder_hours = 168 where id = ?", f.businessId);
        reminders.scheduleDue();
        reminders.scheduleDue();
        processor.processDue();
        assertEquals(1, messages(f, "BOOKING_REMINDER"));
        assertTrue(jdbc.queryForObject("select body from customer_messages where business_id = ? and message_type = 'BOOKING_REMINDER'", String.class, f.businessId).contains("10:00"));

        assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/reschedule", Map.of("startsAt", at(bookingDate(), 12, 0).toString()), f.businessId, id).status());
        reminders.scheduleDue();
        processor.processDue();
        assertEquals(2, messages(f, "BOOKING_REMINDER"));
    }

    @Test void noReminderWhenDisabledOutsideWindowOrNotConfirmed() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 10, "+77010009003");
        processor.processDue();
        jdbc.update("update businesses set reminder_hours = 0 where id = ?", f.businessId);
        reminders.scheduleDue();
        jdbc.update("update businesses set reminder_hours = 1 where id = ?", f.businessId); // booking is days away
        reminders.scheduleDue();
        jdbc.update("update businesses set reminder_hours = 168 where id = ?", f.businessId);
        post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), f.businessId, id);
        reminders.scheduleDue();
        processor.processDue();
        assertEquals(0, messages(f, "BOOKING_REMINDER"));
    }

    @Test void aReminderQueuedBeforeCancellationIsNotSent() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 10, "+77010009004");
        processor.processDue();
        jdbc.update("update businesses set reminder_hours = 168 where id = ?", f.businessId);
        reminders.scheduleDue(); // reminder event is queued...
        post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), f.businessId, id);
        processor.processDue();   // ...but the booking is cancelled before delivery
        assertEquals(0, messages(f, "BOOKING_REMINDER"));
        assertEquals(1, messages(f, "BOOKING_CANCELLED"));
    }

    @Test void messagesAreTenantIsolatedAndCustomerViewRequired() {
        Fixture a = Fixture.create(this, 1, false), b = Fixture.create(this, 1, false);
        book(a, 10, "+77010009005");
        processor.processDue();
        assertEquals(1, get(a.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages", a.businessId).body().size());
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages", a.businessId).status());
        assertEquals(0, get(b.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages", b.businessId).body().size());
        assertEquals(400, patch(a.ownerToken, "/api/v1/businesses/%s/settings", Map.of("customerLocale", "fr"), a.businessId).status());
        assertEquals(400, patch(a.ownerToken, "/api/v1/businesses/%s/settings", Map.of("reminderHours", 500), a.businessId).status());
    }
}
