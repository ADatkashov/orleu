package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/** Proves that one business cannot read or modify another business's data. */
class TenantIsolationIT extends AbstractIT {
    private Fixture a, b;
    private UUID aBooking, aCustomer;

    private void setup() {
        a = Fixture.create(this, 1, true);
        b = Fixture.create(this, 1, true);
        Res bk = post(a.ownerToken, "/api/v1/businesses/%s/bookings", Map.of(
                "branchId", a.branchId, "serviceId", a.serviceId, "startsAt", at(bookingDate(), 10, 0).toString(),
                "customer", a.customer("+77010000001")), a.businessId);
        assertEquals(201, bk.status(), bk.body().toString());
        aBooking = bk.id();
        aCustomer = UUID.fromString(bk.text("customerId"));
    }

    @Test void foreignBusinessEndpointsAreInvisibleToOtherTenantOwner() {
        setup();
        String tb = b.ownerToken;
        UUID biz = a.businessId;
        for (String path : List.of("", "/branches", "/services", "/employees", "/subscription",
                "/customers", "/customers/" + aCustomer, "/bookings/" + aBooking,
                "/availability?branchId=" + a.branchId + "&serviceId=" + a.serviceId + "&date=" + bookingDate(),
                "/bookings?from=" + Instant.now() + "&to=" + Instant.now().plusSeconds(86400),
                "/analytics/summary?from=" + Instant.now().minusSeconds(86400) + "&to=" + Instant.now())) {
            Res r = get(tb, "/api/v1/businesses/" + biz + path.replace("%", "%%"));
            assertEquals(404, r.status(), "GET " + path + " leaked: " + r.body());
        }
    }

    @Test void foreignTenantCannotWrite() {
        setup();
        String tb = b.ownerToken;
        assertEquals(404, post(tb, "/api/v1/businesses/%s/branches", Map.of("name", "Evil"), a.businessId).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/services", Map.of("name", "X", "durationMinutes", 30, "price", "1"), a.businessId).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/employees", Map.of("displayName", "X"), a.businessId).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/customers", a.customer("+77010000009"), a.businessId).status());
        assertEquals(404, patch(tb, "/api/v1/businesses/%s/settings", Map.of("name", "Hacked"), a.businessId).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/unpublish", null, a.businessId).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), a.businessId, aBooking).status());
        assertEquals(404, call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/businesses/" + a.businessId + "/bookings/" + aBooking + "/payments"),
                tb, Map.of("amount", "1", "method", "CASH"), "Idempotency-Key", "k-" + aBooking).status());
        assertEquals(404, call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/businesses/" + a.businessId + "/bookings/" + aBooking + "/refunds"),
                tb, Map.of("amount", "1", "method", "CASH"), "Idempotency-Key", "r-" + aBooking).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/members", Map.of("email", "x@example.com", "role", "STAFF"), a.businessId).status());
        assertEquals("Test Salon", get(a.ownerToken, "/api/v1/businesses/%s", a.businessId).text("name"));
    }

    @Test void businessIdInUrlDoesNotGrantAccessToForeignIdsInsideOwnBusiness() {
        setup();
        String tb = b.ownerToken;
        // B's own business, but A's service/branch/customer/employee ids
        assertEquals(404, post(tb, "/api/v1/businesses/%s/bookings", Map.of(
                "branchId", a.branchId, "serviceId", a.serviceId, "startsAt", at(bookingDate(), 12, 0).toString(),
                "customer", b.customer("+77010000002")), b.businessId).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/bookings", Map.of(
                "branchId", b.branchId, "serviceId", b.serviceId, "startsAt", at(bookingDate(), 12, 0).toString(),
                "customerId", aCustomer), b.businessId).status());
        assertEquals(404, put(tb, "/api/v1/businesses/%s/employees/%s/assignments",
                Map.of("branchIds", List.of(a.branchId), "serviceIds", List.of()), b.businessId, b.employeeId).status());
        assertEquals(404, put(tb, "/api/v1/businesses/%s/employees/%s/assignments",
                Map.of("branchIds", List.of(), "serviceIds", List.of(a.serviceId)), b.businessId, b.employeeId).status());
        assertEquals(404, get(tb, "/api/v1/businesses/%s/bookings/%s", b.businessId, aBooking).status());
        assertEquals(404, get(tb, "/api/v1/businesses/%s/customers/%s", b.businessId, aCustomer).status());
        assertEquals(404, post(tb, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), b.businessId, aBooking).status());
        assertEquals(404, put(tb, "/api/v1/businesses/%s/branches/%s/hours", Map.of("hours", List.of()), b.businessId, a.branchId).status());
        assertEquals(404, get(tb, "/api/v1/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s", b.businessId, a.branchId, b.serviceId, bookingDate()).status());
        // A's data is untouched
        assertEquals("CONFIRMED", get(a.ownerToken, "/api/v1/businesses/%s/bookings/%s", a.businessId, aBooking).text("status"));
    }

    @Test void customersAreScopedPerBusinessEvenWithSamePhone() {
        setup();
        post(b.ownerToken, "/api/v1/businesses/%s/customers", Map.of("fullName", "Other", "phone", "+77010000001"), b.businessId);
        Res listA = get(a.ownerToken, "/api/v1/businesses/%s/customers?q=0000001", a.businessId);
        Res listB = get(b.ownerToken, "/api/v1/businesses/%s/customers?q=0000001", b.businessId);
        assertEquals(1, listA.body().path("total").asInt());
        assertEquals("Aigerim", listA.body().path("items").get(0).path("fullName").asText());
        assertEquals(1, listB.body().path("total").asInt());
        assertEquals("Other", listB.body().path("items").get(0).path("fullName").asText());
    }

    @Test void databaseRefusesCrossTenantRelations() {
        setup();
        // composite foreign keys: a booking in A cannot reference B's employee/service/customer even via raw SQL
        assertThrows(DataIntegrityViolationException.class, () -> jdbc.update("""
            insert into bookings (business_id, branch_id, service_id, employee_id, customer_id, starts_at, ends_at, blocked_until, status, price, deposit_amount, currency)
            values (?, ?, ?, ?, ?, now() + interval '30 days', now() + interval '30 days 1 hour', now() + interval '30 days 1 hour', 'CONFIRMED', 1, 0, 'KZT')
            """, a.businessId, a.branchId, a.serviceId, b.employeeId, aCustomer));
        assertThrows(DataIntegrityViolationException.class, () -> jdbc.update(
                "insert into employee_services (employee_id, service_id, business_id) values (?, ?, ?)", b.employeeId, a.serviceId, a.businessId));
    }

    @Test void userWithMembershipInTwoBusinessesHasIndependentRoles() {
        setup();
        String staffToken = newUser("multi");
        String email = (String) get(staffToken, "/api/v1/me").body().path("email").asText();
        assertEquals(201, post(a.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", email, "role", "STAFF"), a.businessId).status());
        assertEquals(201, post(b.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", email, "role", "BUSINESS_ADMIN"), b.businessId).status());
        assertEquals(200, get(staffToken, "/api/v1/businesses/%s/bookings/%s", a.businessId, aBooking).status());
        assertEquals(403, post(staffToken, "/api/v1/businesses/%s/branches", Map.of("name", "Nope"), a.businessId).status()); // STAFF in A
        assertEquals(201, post(staffToken, "/api/v1/businesses/%s/services", Map.of("name", "Ok", "durationMinutes", 30, "price", "1000"), b.businessId).status()); // ADMIN in B
    }
}
