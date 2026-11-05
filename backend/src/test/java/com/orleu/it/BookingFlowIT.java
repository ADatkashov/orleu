package com.orleu.it;

import com.orleu.bookings.BookingService;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class BookingFlowIT extends AbstractIT {
    @Autowired BookingService bookingService;

    private Res book(Fixture f, int hour, int min, UUID employee, String phone) {
        java.util.HashMap<String, Object> m = new java.util.HashMap<>(Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, min).toString(), "customer", f.customer(phone)));
        if (employee != null) m.put("employeeId", employee);
        return post(f.ownerToken, "/api/v1/businesses/%s/bookings", m, f.businessId);
    }

    private Res pay(Fixture f, UUID booking, String amount, String key) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + booking + "/payments"),
                f.ownerToken, Map.of("amount", amount, "method", "CASH"), "Idempotency-Key", key);
    }

    private Res transition(Fixture f, UUID booking, String status) {
        return post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", status), f.businessId, booking);
    }

    @Test void availabilityRespectsHoursDurationAndExistingBookings() {
        Fixture f = Fixture.create(this, 1, false);
        Res slots = get(f.ownerToken, "/api/v1/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s", f.businessId, f.branchId, f.serviceId, bookingDate());
        assertEquals(200, slots.status());
        // 09:00-18:00, 60 min, 15-min step: last start is 17:00 -> 33 slots
        assertEquals(33, slots.body().size());
        assertEquals(at(bookingDate(), 9, 0).toString(), slots.body().get(0).path("start").asText());
        assertEquals(at(bookingDate(), 17, 0).toString(), slots.body().get(32).path("start").asText());
        assertEquals(201, book(f, 12, 0, null, "+77010000010").status());
        Res after = get(f.ownerToken, "/api/v1/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s", f.businessId, f.branchId, f.serviceId, bookingDate());
        // 11:15..12:45 (starts that overlap 12:00-13:00) disappear: 7 slots
        assertEquals(26, after.body().size());
    }

    @Test void doubleBookingIsRejectedButOtherEmployeeOrAdjacentSlotWorks() {
        Fixture f = Fixture.create(this, 2, false);
        assertEquals(201, book(f, 10, 0, f.employeeIds.get(0), "+77010000011").status());
        assertEquals(409, book(f, 10, 0, f.employeeIds.get(0), "+77010000012").status());
        assertEquals(409, book(f, 10, 30, f.employeeIds.get(0), "+77010000012").status()); // overlap
        assertEquals(201, book(f, 10, 0, f.employeeIds.get(1), "+77010000012").status());  // other master
        assertEquals(201, book(f, 11, 0, f.employeeIds.get(0), "+77010000013").status());  // back-to-back is fine
        // "any employee" picks whoever is free: both busy at 10:00 now
        assertEquals(409, book(f, 10, 0, null, "+77010000014").status());
    }

    @Test void cancelledBookingFreesTheSlot() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 10, 0, null, "+77010000015").id();
        assertEquals(409, book(f, 10, 0, null, "+77010000016").status());
        assertEquals(200, transition(f, id, "CANCELLED").status());
        assertEquals(201, book(f, 10, 0, null, "+77010000016").status());
    }

    @Test void serviceBufferBlocksFollowingSlot() {
        Fixture f = Fixture.create(this, 1, false);
        Res svc = post(f.ownerToken, "/api/v1/businesses/%s/services", Map.of("name", "Color", "durationMinutes", 60, "bufferMinutes", 30, "price", "10000"), f.businessId);
        put(f.ownerToken, "/api/v1/businesses/%s/employees/%s/assignments", Map.of("branchIds", java.util.List.of(f.branchId),
                "serviceIds", java.util.List.of(f.serviceId, svc.id())), f.businessId, f.employeeId);
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", svc.id(),
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010000017")), f.businessId).status());
        assertEquals(409, book(f, 11, 0, null, "+77010000018").status()); // 11:00-11:30 is cleanup buffer
        assertEquals(201, book(f, 11, 30, null, "+77010000018").status());
    }

    @Test void stateMachineIsEnforcedOnTheBackend() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 10, 0, null, "+77010000020").id(); // auto-confirmed, no deposit
        assertEquals(409, transition(f, id, "COMPLETED").status());   // cannot skip
        assertEquals(409, transition(f, id, "PENDING").status());     // cannot go back
        assertEquals(400, transition(f, id, "EXPIRED").status());     // system only
        assertEquals(200, transition(f, id, "CHECKED_IN").status());
        assertEquals(200, transition(f, id, "IN_PROGRESS").status());
        assertEquals(200, transition(f, id, "COMPLETED").status());
        assertEquals(409, transition(f, id, "CANCELLED").status());   // terminal
        assertEquals(400, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "BOGUS"), f.businessId, id).status());
        Integer hist = jdbc.queryForObject("select count(*) from booking_status_history where booking_id = ?", Integer.class, id);
        assertEquals(4, hist); // created + 3 transitions
    }

    @Test void depositFlowWithLedgerRemainingBalanceAndIdempotency() {
        Fixture f = Fixture.create(this, 1, false);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("depositPercent", 30), f.businessId);
        Res b = book(f, 10, 0, null, "+77010000021");
        assertEquals(201, b.status());
        assertEquals("AWAITING_PAYMENT", b.text("status"));
        assertEquals(0, new BigDecimal("6000.00").compareTo(b.body().path("financials").path("depositAmount").decimalValue()));
        assertEquals(0, new BigDecimal("20000.00").compareTo(b.body().path("financials").path("remaining").decimalValue()));
        UUID id = b.id();
        assertEquals(409, transition(f, id, "CONFIRMED").status()); // must pay, cannot just confirm

        Res p1 = pay(f, id, "5000.00", "k1");
        assertEquals(201, p1.status());
        assertEquals("AWAITING_PAYMENT", p1.text("status")); // below deposit
        assertEquals("PARTIALLY_PAID", p1.body().path("financials").path("paymentStatus").asText());

        Res p2 = pay(f, id, "1000.00", "k2");
        assertEquals("CONFIRMED", p2.text("status"));
        assertEquals("DEPOSIT_PAID", p2.body().path("financials").path("paymentStatus").asText());
        assertEquals(0, new BigDecimal("14000.00").compareTo(p2.body().path("financials").path("remaining").decimalValue()));

        // retry of the same request must not charge twice
        Res replay = pay(f, id, "1000.00", "k2");
        assertEquals(201, replay.status());
        assertEquals(0, new BigDecimal("14000.00").compareTo(replay.body().path("financials").path("remaining").decimalValue()));
        assertEquals(2, jdbc.queryForObject("select count(*) from ledger_entries where booking_id = ?", Integer.class, id));
        // same key with a different amount is a client bug
        assertEquals(409, pay(f, id, "2000.00", "k2").status());
        // overpayment is rejected
        assertEquals(409, pay(f, id, "14000.01", "k3").status());
        assertEquals(400, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + id + "/payments"),
                f.ownerToken, Map.of("amount", "1", "method", "CASH")).status()); // missing Idempotency-Key
        assertEquals(400, pay(f, id, "-5", "k4").status());

        Res full = pay(f, id, "14000.00", "k5");
        assertEquals("PAID", full.body().path("financials").path("paymentStatus").asText());
        assertEquals(0, BigDecimal.ZERO.compareTo(full.body().path("financials").path("remaining").decimalValue()));

        // refunds: partial, bounded by what was paid, idempotent
        Res ref = call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + id + "/refunds"),
                f.ownerToken, Map.of("amount", "6000", "method", "CASH"), "Idempotency-Key", "rf1");
        assertEquals(201, ref.status());
        assertEquals(0, new BigDecimal("14000.00").compareTo(ref.body().path("financials").path("netPaid").decimalValue()));
        assertEquals(409, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + id + "/refunds"),
                f.ownerToken, Map.of("amount", "14000.01", "method", "CASH"), "Idempotency-Key", "rf2").status());
    }

    @Test void unpaidHoldExpiresAndReleasesTheSlot() {
        Fixture f = Fixture.create(this, 1, false);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("depositPercent", 50), f.businessId);
        UUID id = book(f, 10, 0, null, "+77010000022").id();
        assertEquals(409, book(f, 10, 0, null, "+77010000023").status());
        jdbc.update("update bookings set hold_expires_at = now() - interval '1 minute' where id = ?", id);
        assertTrue(bookingService.expireStaleHolds() >= 1);
        assertEquals("EXPIRED", get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s", f.businessId, id).text("status"));
        assertEquals(409, pay(f, id, "100", "kx").status()); // cannot pay an expired booking
        assertEquals(201, book(f, 10, 0, null, "+77010000023").status());
    }

    @Test void rescheduleMovesBookingAndRespectsConflicts() {
        Fixture f = Fixture.create(this, 1, false);
        UUID a = book(f, 10, 0, null, "+77010000024").id();
        book(f, 13, 0, null, "+77010000025");
        assertEquals(409, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/reschedule", Map.of("startsAt", at(bookingDate(), 13, 30).toString()), f.businessId, a).status());
        Res ok = post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/reschedule", Map.of("startsAt", at(bookingDate(), 10, 30).toString()), f.businessId, a); // overlaps itself only
        assertEquals(200, ok.status(), ok.body().toString());
        assertEquals(at(bookingDate(), 10, 30).toString(), ok.text("startsAt"));
        assertEquals(409, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/reschedule", Map.of("startsAt", at(bookingDate(), 19, 0).toString()), f.businessId, a).status()); // after closing
    }

    @Test void excludeBookingIdFreesOwnTimeForRescheduling() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = book(f, 12, 0, null, "+77010000030").id();
        String base = "/api/v1/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s";
        Res without = get(f.ownerToken, base, f.businessId, f.branchId, f.serviceId, bookingDate());
        Res with = get(f.ownerToken, base + "&excludeBookingId=%s", f.businessId, f.branchId, f.serviceId, bookingDate(), id);
        String own = at(bookingDate(), 12, 30).toString();
        assertFalse(without.body().findValuesAsText("start").contains(own));
        assertTrue(with.body().findValuesAsText("start").contains(own));
        assertEquals(33, with.body().size());
    }

    @Test void timeOffRemovesAvailability() {
        Fixture f = Fixture.create(this, 1, false);
        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/employees/%s/time-off", Map.of(
                "startsAt", at(bookingDate(), 9, 0).toString(), "endsAt", at(bookingDate(), 13, 0).toString(), "reason", "sick"), f.businessId, f.employeeId).status());
        assertEquals(409, book(f, 11, 0, null, "+77010000026").status());
        assertEquals(201, book(f, 13, 0, null, "+77010000026").status());
    }

    @Test void branchListIncludesWorkingHoursButPublicProfileDoesNot() {
        Fixture f = Fixture.create(this, 1, true);
        Res list = get(f.ownerToken, "/api/v1/businesses/%s/branches", f.businessId);
        assertEquals(7, list.body().get(0).path("hours").size());
        assertEquals("09:00:00", list.body().get(0).path("hours").get(0).path("open").asText());
        assertTrue(get(null, "/api/v1/public/businesses/%s", f.slug).body().path("branches").get(0).path("hours").isMissingNode());
    }

    @Test void blockedCustomerCannotBook() {
        Fixture f = Fixture.create(this, 1, true);
        Res c = post(f.ownerToken, "/api/v1/businesses/%s/customers", f.customer("+77010000027"), f.businessId);
        post(f.ownerToken, "/api/v1/businesses/%s/customers/%s/block", null, f.businessId, c.id());
        assertEquals(403, book(f, 10, 0, null, "+77010000027").status());
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'CUSTOMER_BLOCKED'", Integer.class, f.businessId));
    }
}
