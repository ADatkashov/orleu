package com.orleu.it;

import com.orleu.customers.CustomerRetentionJob;
import com.orleu.notifications.OutboxProcessor;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CustomerPrivacyIT extends AbstractIT {
    @Autowired OutboxProcessor processor;
    @Autowired CustomerRetentionJob retention;

    @BeforeEach void clearBacklog() { jdbc.update("delete from outbox_events where status = 'PENDING'"); }

    private Res book(Fixture f, int daysAhead, int hour, String phone, String name, String notes) {
        Map<String, Object> body = new java.util.HashMap<>(Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate().plusDays(daysAhead), hour, 0).toString(), "customer", Map.of("fullName", name, "phone", phone)));
        if (notes != null) body.put("notes", notes);
        Res r = post(f.ownerToken, "/api/v1/businesses/%s/bookings", body, f.businessId);
        assertEquals(201, r.status(), r.body().toString());
        return r;
    }

    private UUID customerId(Fixture f, String phone) {
        return jdbc.queryForObject("select id from customers where business_id = ? and phone = ?", UUID.class, f.businessId, phone);
    }

    private void pay(Fixture f, UUID booking, String amount, String key) {
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + booking + "/payments"), f.ownerToken, Map.of("amount", amount, "method", "CASH"), "Idempotency-Key", key).status());
    }

    @Test void exportContainsEverythingHeldAboutTheCustomerAndIsAuditedAndProtected() {
        Fixture f = Fixture.create(this, 1, false);
        Res b = book(f, 0, 10, "+77010004001", "Aigerim Secret", "allergic to X");
        pay(f, b.id(), "5000", "pr-1");
        processor.processDue();
        UUID cid = customerId(f, "+77010004001");
        var r = call(MockMvcRequestBuilders.get("/api/v1/businesses/" + f.businessId + "/customers/" + cid + "/export"), f.ownerToken, null);
        assertEquals(200, r.status());
        assertEquals("Aigerim Secret", r.body().path("customer").path("fullName").asText());
        assertEquals("+77010004001", r.body().path("customer").path("phone").asText());
        assertEquals(1, r.body().path("bookings").size());
        assertEquals("allergic to X", r.body().path("bookings").get(0).path("notes").asText());
        assertEquals(5000, r.body().path("bookings").get(0).path("netPaid").asDouble(), 0.001);
        assertTrue(r.body().path("messages").size() >= 1, "prepared customer messages are part of the export");
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'CUSTOMER_DATA_EXPORTED'", Integer.class, f.businessId));

        String staff = newUser("staffx");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(staff, "/api/v1/me").text("email"), "role", "STAFF"), f.businessId);
        assertEquals(403, call(MockMvcRequestBuilders.get("/api/v1/businesses/" + f.businessId + "/customers/" + cid + "/export"), staff, null).status());
        Fixture other = Fixture.create(this, 1, false);
        assertEquals(404, call(MockMvcRequestBuilders.get("/api/v1/businesses/" + f.businessId + "/customers/" + cid + "/export"), other.ownerToken, null).status());
        assertEquals(404, call(MockMvcRequestBuilders.get("/api/v1/businesses/" + other.businessId + "/customers/" + cid + "/export"), other.ownerToken, null).status());
    }

    @Test void anonymisationRemovesPersonalDataKeepsAccountingAndKillsTheGuestLink() {
        Fixture f = Fixture.create(this, 1, true);
        // a guest booking gives a manage token and, once completed and reviewed, a review comment
        Res g = post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "startsAt", at(bookingDate(), 12, 0).toString(),
                "customer", Map.of("fullName", "Dana Private", "phone", "+77010004002", "email", "dana@example.com", "marketingOptIn", true)), f.slug);
        assertEquals(201, g.status());
        String token = g.text("manageToken");
        UUID booking = UUID.fromString(g.text("bookingId"));
        pay(f, booking, "7000", "pr-2");
        for (String s : new String[]{"CHECKED_IN", "IN_PROGRESS", "COMPLETED"}) post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", s), f.businessId, booking);
        assertEquals(201, post(null, "/api/v1/public/manage/%s/review", Map.of("rating", 4, "comment", "Dana's phone is +7701..."), token).status());
        jdbc.update("update bookings set notes = 'call her mother' where id = ?", booking);
        processor.processDue();
        UUID cid = customerId(f, "+77010004002");
        int ledgerBefore = jdbc.queryForObject("select count(*) from ledger_entries where business_id = ?", Integer.class, f.businessId);

        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/customers/%s/anonymize", null, f.businessId, cid).status());
        var row = jdbc.queryForMap("select full_name, phone, email, notes, marketing_opt_in, anonymized_at from customers where id = ?", cid);
        assertEquals("Deleted customer", row.get("full_name"));
        assertTrue(((String) row.get("phone")).startsWith("+999"));
        assertNull(row.get("email"));
        assertNull(row.get("notes"));
        assertEquals(false, row.get("marketing_opt_in"));
        assertNotNull(row.get("anonymized_at"));
        assertNull(jdbc.queryForObject("select notes from bookings where id = ?", String.class, booking));
        assertNull(jdbc.queryForObject("select manage_token_hash from bookings where id = ?", String.class, booking));
        assertEquals(404, get(null, "/api/v1/public/manage/%s", token).status(), "the guest's secret link stops working");
        assertEquals(0, jdbc.queryForObject("select count(*) from customer_messages where business_id = ?", Integer.class, f.businessId), "message bodies (they contain the name) are gone");
        assertNull(jdbc.queryForObject("select comment from reviews where booking_id = ?", String.class, booking));
        assertEquals(4, jdbc.queryForObject("select rating from reviews where booking_id = ?", Integer.class, booking), "the rating itself stays for the business's statistics");
        assertEquals(ledgerBefore, jdbc.queryForObject("select count(*) from ledger_entries where business_id = ?", Integer.class, f.businessId), "accounting records are kept");
        assertEquals(1, jdbc.queryForObject("select count(*) from bookings where id = ?", Integer.class, booking));
        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/customers/%s/anonymize", null, f.businessId, cid).status(), "idempotent");
        assertTrue(jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'CUSTOMER_ANONYMIZED'", Integer.class, f.businessId) >= 1);

        // the same person booking again is a brand-new record, not the old one
        assertEquals(201, post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "startsAt", at(bookingDate(), 15, 0).toString(),
                "customer", Map.of("fullName", "Dana Private", "phone", "+77010004002")), f.slug).status());
        assertNotEquals(cid, customerId(f, "+77010004002"));
    }

    @Test void anonymisationIsRefusedWithUpcomingBookingsAndForRolesBelowOwnerAdmin() {
        Fixture f = Fixture.create(this, 1, false);
        Res b = book(f, 3, 10, "+77010004003", "Upcoming Person", null);
        UUID cid = customerId(f, "+77010004003");
        Res refused = post(f.ownerToken, "/api/v1/businesses/%s/customers/%s/anonymize", null, f.businessId, cid);
        assertEquals(409, refused.status());
        assertEquals("HAS_UPCOMING_BOOKINGS", refused.text("code"));
        String recep = newUser("recepx");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(recep, "/api/v1/me").text("email"), "role", "RECEPTIONIST"), f.businessId);
        post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), f.businessId, b.id());
        assertEquals(403, post(recep, "/api/v1/businesses/%s/customers/%s/anonymize", null, f.businessId, cid).status(), "receptionists can export but not erase");
        Fixture other = Fixture.create(this, 1, false);
        assertEquals(404, post(other.ownerToken, "/api/v1/businesses/%s/customers/%s/anonymize", null, f.businessId, cid).status());
        assertEquals("Upcoming Person", jdbc.queryForObject("select full_name from customers where id = ?", String.class, cid), "nothing happened");
    }

    @Test void retentionAnonymisesOnlyInactiveCustomersOfBusinessesThatOptedIn() {
        Fixture f = Fixture.create(this, 1, false), off = Fixture.create(this, 1, false);
        assertEquals(400, patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("customerRetentionMonths", 5), f.businessId).status());
        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("customerRetentionMonths", 12), f.businessId).status());
        assertEquals(12, get(f.ownerToken, "/api/v1/businesses/%s", f.businessId).body().path("customerRetentionMonths").asInt());

        book(f, 0, 10, "+77010004004", "Old Customer", null);      // will be made old
        book(f, 0, 11, "+77010004005", "Recent Customer", null);   // stays recent
        book(f, 5, 12, "+77010004006", "Upcoming Customer", null); // old customer record but an upcoming booking
        book(off, 0, 10, "+77010004004", "Old But Other Tenant", null);
        UUID old = customerId(f, "+77010004004"), upcoming = customerId(f, "+77010004006"), foreign = customerId(off, "+77010004004");
        jdbc.update("update bookings set starts_at = starts_at - interval '500 days', ends_at = ends_at - interval '500 days', blocked_until = blocked_until - interval '500 days' where customer_id in (?, ?)", old, foreign);
        jdbc.update("update customers set created_at = now() - interval '600 days' where id in (?, ?, ?)", old, upcoming, foreign);

        assertEquals(1, retention.runOnce());
        assertEquals("Deleted customer", jdbc.queryForObject("select full_name from customers where id = ?", String.class, old));
        assertEquals("Recent Customer", jdbc.queryForObject("select full_name from customers where business_id = ? and phone = '+77010004005'", String.class, f.businessId));
        assertEquals("Upcoming Customer", jdbc.queryForObject("select full_name from customers where id = ?", String.class, upcoming), "an upcoming booking protects the customer");
        assertEquals("Old But Other Tenant", jdbc.queryForObject("select full_name from customers where id = ?", String.class, foreign), "a business that did not opt in is never touched");
        assertEquals(0, retention.runOnce(), "idempotent");
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'CUSTOMERS_ANONYMIZED_BY_RETENTION'", Integer.class, f.businessId));

        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("customerRetentionMonths", 0), f.businessId).status());
        assertTrue(get(f.ownerToken, "/api/v1/businesses/%s", f.businessId).body().path("customerRetentionMonths").isMissingNode()
                || get(f.ownerToken, "/api/v1/businesses/%s", f.businessId).body().path("customerRetentionMonths").isNull(), "0 switches it off");
    }
}
