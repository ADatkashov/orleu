package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CustomerProfileIT extends AbstractIT {
    private static final String PHONE = "+77010006001";

    private UUID book(Fixture f, int hour) {
        Res r = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Aigerim", "phone", PHONE)), f.businessId);
        assertEquals(201, r.status(), r.body().toString());
        return r.id();
    }

    private Res money(Fixture f, UUID booking, String kind, String amount, String key) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + booking + "/" + kind),
                f.ownerToken, Map.of("amount", amount, "method", "CASH"), "Idempotency-Key", key);
    }

    private void transition(Fixture f, UUID booking, String... statuses) {
        for (String s : statuses) assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", s), f.businessId, booking).status(), s);
    }

    private UUID customerId(Fixture f) {
        return jdbc.queryForObject("select id from customers where business_id = ? and phone = ?", UUID.class, f.businessId, PHONE);
    }

    @Test void profileShowsMeasuredStatisticsAndHistory() {
        Fixture f = Fixture.create(this, 1, false);
        UUID done = book(f, 10), cancelled = book(f, 11), noShow = book(f, 12), upcoming = book(f, 13);
        transition(f, done, "CHECKED_IN", "IN_PROGRESS", "COMPLETED");
        transition(f, cancelled, "CANCELLED");
        transition(f, noShow, "NO_SHOW");
        money(f, done, "payments", "20000", "cp-1");
        money(f, done, "refunds", "5000", "cp-2");
        money(f, upcoming, "payments", "3000", "cp-3");

        Res p = get(f.ownerToken, "/api/v1/businesses/%s/customers/%s/profile", f.businessId, customerId(f));
        assertEquals(200, p.status(), p.body().toString());
        var s = p.body().path("stats");
        assertEquals(4, s.path("totalBookings").asInt());
        assertEquals(1, s.path("completedVisits").asInt());
        assertEquals(1, s.path("cancelled").asInt());
        assertEquals(1, s.path("noShows").asInt());
        assertEquals(1, s.path("upcoming").asInt());
        assertEquals(at(bookingDate(), 10, 0).toString(), s.path("lastVisit").asText());
        // cash actually collected: 20000 - 5000 refund + 3000 deposit; not the booked value of 80000
        assertEquals(0, new BigDecimal("18000").compareTo(s.path("totalSpent").decimalValue()));
        // average per COMPLETED visit counts only that visit's net cash (15000), not the unrelated deposit
        assertEquals(0, new BigDecimal("15000").compareTo(s.path("averageSpendPerVisit").decimalValue()));
        assertEquals(4, p.body().path("bookings").size());
        assertEquals(at(bookingDate(), 13, 0).toString(), p.body().path("bookings").get(0).path("startsAt").asText()); // newest first
        assertEquals("Aigerim", p.body().path("customer").path("fullName").asText());
    }

    @Test void customerWithoutVisitsHasNoAverage() {
        Fixture f = Fixture.create(this, 0, false);
        Res c = post(f.ownerToken, "/api/v1/businesses/%s/customers", f.customer("+77010006002"), f.businessId);
        Res p = get(f.ownerToken, "/api/v1/businesses/%s/customers/%s/profile", f.businessId, c.id());
        assertEquals(0, p.body().path("stats").path("totalBookings").asInt());
        assertTrue(p.body().path("stats").path("averageSpendPerVisit").isMissingNode() || p.body().path("stats").path("averageSpendPerVisit").isNull());
        assertTrue(p.body().path("stats").path("lastVisit").isMissingNode() || p.body().path("stats").path("lastVisit").isNull());
        assertEquals(0, new BigDecimal("0").compareTo(p.body().path("stats").path("totalSpent").decimalValue()));
    }

    @Test void updateChangesProfileFieldsButNeverThePhone() {
        Fixture f = Fixture.create(this, 0, false);
        UUID id = post(f.ownerToken, "/api/v1/businesses/%s/customers", f.customer("+77010006003"), f.businessId).id();
        Res u = patch(f.ownerToken, "/api/v1/businesses/%s/customers/%s", Map.of("fullName", "  Aigerim S.  ", "notes", "Prefers mornings", "email", "a@example.com",
                "marketingOptIn", true, "phone", "+77019999999"), f.businessId, id);
        assertEquals(200, u.status());
        assertEquals("Aigerim S.", u.text("fullName"));
        assertEquals("Prefers mornings", u.text("notes"));
        assertTrue(u.body().path("marketingOptIn").asBoolean());
        assertEquals("+77010006003", u.text("phone"), "phone is the identity and is not editable");
        assertEquals(400, patch(f.ownerToken, "/api/v1/businesses/%s/customers/%s", Map.of("fullName", "   "), f.businessId, id).status());
        assertEquals(400, patch(f.ownerToken, "/api/v1/businesses/%s/customers/%s", Map.of("email", "not-an-email"), f.businessId, id).status());
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'CUSTOMER_UPDATED'", Integer.class, f.businessId));
        // partial update leaves the rest alone
        patch(f.ownerToken, "/api/v1/businesses/%s/customers/%s", Map.of("notes", ""), f.businessId, id);
        assertEquals("Aigerim S.", get(f.ownerToken, "/api/v1/businesses/%s/customers/%s", f.businessId, id).text("fullName"));
    }

    @Test void profileAndUpdateAreTenantIsolatedAndRoleChecked() {
        Fixture a = Fixture.create(this, 1, false), b = Fixture.create(this, 1, false);
        UUID id = post(a.ownerToken, "/api/v1/businesses/%s/customers", a.customer("+77010006004"), a.businessId).id();
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/customers/%s/profile", a.businessId, id).status());
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/customers/%s/profile", b.businessId, id).status());   // foreign id in own tenant
        assertEquals(404, patch(b.ownerToken, "/api/v1/businesses/%s/customers/%s", Map.of("notes", "x"), b.businessId, id).status());

        String staff = newUser("stf"), acct = newUser("acc");
        post(a.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(staff, "/api/v1/me").text("email"), "role", "STAFF"), a.businessId);
        post(a.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(acct, "/api/v1/me").text("email"), "role", "ACCOUNTANT"), a.businessId);
        assertEquals(200, get(staff, "/api/v1/businesses/%s/customers/%s/profile", a.businessId, id).status());               // view allowed
        assertEquals(403, patch(staff, "/api/v1/businesses/%s/customers/%s", Map.of("notes", "x"), a.businessId, id).status()); // edit not
        assertEquals(403, get(acct, "/api/v1/businesses/%s/customers/%s/profile", a.businessId, id).status());                // accountants have no CRM access
    }
}
