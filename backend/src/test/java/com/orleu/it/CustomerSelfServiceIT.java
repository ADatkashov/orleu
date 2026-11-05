package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class CustomerSelfServiceIT extends AbstractIT {
    private Res guestBook(Fixture f, int hour, String phone) {
        return post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Dana", "phone", phone)), f.slug);
    }

    @Test void guestViewsAndCancelsViaSecretLinkAndSlotIsFreed() {
        Fixture f = Fixture.create(this, 1, true);
        Res b = guestBook(f, 10, "+77010004001");
        assertEquals(201, b.status());
        String token = b.text("manageToken");
        assertTrue(token.length() >= 40);

        Res view = get(null, "/api/v1/public/manage/%s", token);
        assertEquals(200, view.status());
        assertTrue(view.body().path("canCancel").asBoolean());
        assertEquals("Haircut", view.text("serviceName"));
        assertFalse(view.body().toString().contains("Dana") || view.body().toString().contains("+7701"), "no customer PII");

        assertEquals(200, post(null, "/api/v1/public/manage/%s/cancel", null, token).status());
        assertEquals("CANCELLED", get(null, "/api/v1/public/manage/%s", token).text("status"));
        assertEquals(200, post(null, "/api/v1/public/manage/%s/cancel", null, token).status()); // idempotent
        assertEquals(201, guestBook(f, 10, "+77010004002").status());                          // slot is free again
        // the business sees the cancellation as a notification event
        assertEquals(1, jdbc.queryForObject("select count(*) from outbox_events where business_id = ? and event_type = 'BOOKING_CANCELLED'", Integer.class, f.businessId));
    }

    @Test void tokenIsNotStoredInPlainTextAndGuessingFails() {
        Fixture f = Fixture.create(this, 1, true);
        String token = guestBook(f, 10, "+77010004003").text("manageToken");
        assertEquals(0, jdbc.queryForObject("select count(*) from bookings where manage_token_hash = ?", Integer.class, token));
        assertEquals(404, get(null, "/api/v1/public/manage/%s", token.substring(0, token.length() - 1) + (token.endsWith("A") ? "B" : "A")).status());
        assertEquals(404, get(null, "/api/v1/public/manage/%s", "short").status());
        assertEquals(404, post(null, "/api/v1/public/manage/%s/cancel", null, "x".repeat(50)).status());
    }

    @Test void cancellationDeadlineIsEnforcedForConfirmedBookings() {
        Fixture f = Fixture.create(this, 1, true);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("cancellationDeadlineHours", 720), f.businessId); // 30 days: booking in 3 days is too late
        String token = guestBook(f, 10, "+77010004004").text("manageToken");
        Res view = get(null, "/api/v1/public/manage/%s", token);
        assertFalse(view.body().path("canCancel").asBoolean());
        Res cancel = post(null, "/api/v1/public/manage/%s/cancel", null, token);
        assertEquals(409, cancel.status());
        assertEquals("CANCELLATION_NOT_ALLOWED", cancel.text("code"));
        assertEquals("CONFIRMED", get(null, "/api/v1/public/manage/%s", token).text("status"));
    }

    @Test void unpaidDepositBookingCanAlwaysBeAbandoned() {
        Fixture f = Fixture.create(this, 1, true);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("depositPercent", 30, "cancellationDeadlineHours", 720), f.businessId);
        String token = guestBook(f, 10, "+77010004005").text("manageToken");
        assertEquals("AWAITING_PAYMENT", get(null, "/api/v1/public/manage/%s", token).text("status"));
        assertEquals(200, post(null, "/api/v1/public/manage/%s/cancel", null, token).status());
    }

    @Test void completedBookingCannotBeCancelledByCustomer() {
        Fixture f = Fixture.create(this, 1, true);
        Res b = guestBook(f, 10, "+77010004006");
        java.util.UUID id = java.util.UUID.fromString(b.text("bookingId"));
        for (String st : new String[]{"CHECKED_IN", "IN_PROGRESS", "COMPLETED"})
            post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", st), f.businessId, id);
        assertEquals(409, post(null, "/api/v1/public/manage/%s/cancel", null, b.text("manageToken")).status());
    }
}
