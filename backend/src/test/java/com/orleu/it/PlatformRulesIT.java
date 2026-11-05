package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessException;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class PlatformRulesIT extends AbstractIT {
    @Test void freePlanLimitsAreEnforcedByTheBackendAndLiftedByPlanChange() {
        Fixture f = Fixture.create(this, 3, false); // FREE allows 3 employees, 1 branch
        Res e4 = post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "Fourth"), f.businessId);
        assertEquals(402, e4.status());
        assertEquals("EMPLOYEE_LIMIT_REACHED", e4.text("code"));
        Res b2 = post(f.ownerToken, "/api/v1/businesses/%s/branches", Map.of("name", "Second"), f.businessId);
        assertEquals(402, b2.status());
        assertEquals("BRANCH_LIMIT_REACHED", b2.text("code"));
        Res usage = get(f.ownerToken, "/api/v1/businesses/%s/subscription", f.businessId);
        assertEquals("FREE", usage.text("planCode"));
        assertEquals(3, usage.body().path("employees").asInt());
        // limits live in data: switching the plan (platform admin action) lifts them without code changes
        jdbc.update("update businesses set plan_code = 'PRO' where id = ?", f.businessId);
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "Fourth"), f.businessId).status());
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/branches", Map.of("name", "Second"), f.businessId).status());
    }

    @Test void ledgerIsAppendOnly() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010002001")), f.businessId).id();
        call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/payments"),
                f.ownerToken, Map.of("amount", "100", "method", "CASH"), "Idempotency-Key", "led-1");
        assertThrows(DataAccessException.class, () -> jdbc.update("update ledger_entries set amount = 1 where booking_id = ?", b));
        assertThrows(DataAccessException.class, () -> jdbc.update("delete from ledger_entries where booking_id = ?", b));
        assertEquals(0, new BigDecimal("100.00").compareTo(jdbc.queryForObject("select amount from ledger_entries where booking_id = ?", BigDecimal.class, b)));
    }

    @Test void databaseItselfRejectsOverlappingActiveBookings() {
        Fixture f = Fixture.create(this, 1, false);
        post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010002002")), f.businessId);
        UUID cust = jdbc.queryForObject("select id from customers where business_id = ? limit 1", UUID.class, f.businessId);
        // bypassing the application entirely still cannot create an overlap
        assertThrows(DataAccessException.class, () -> jdbc.update("""
            insert into bookings (business_id, branch_id, service_id, employee_id, customer_id, starts_at, ends_at, blocked_until, status, price, deposit_amount, currency)
            values (?, ?, ?, ?, ?, ?::timestamptz, ?::timestamptz, ?::timestamptz, 'CONFIRMED', 1, 0, 'KZT')
            """, f.businessId, f.branchId, f.serviceId, f.employeeId, cust,
                at(bookingDate(), 10, 30).toString(), at(bookingDate(), 11, 30).toString(), at(bookingDate(), 11, 30).toString()));
    }

    @Test void rolesGrantOnlyTheirPermissions() {
        Fixture f = Fixture.create(this, 1, false);
        String staff = newUser("staff"), acct = newUser("acct");
        String staffEmail = get(staff, "/api/v1/me").text("email"), acctEmail = get(acct, "/api/v1/me").text("email");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", staffEmail, "role", "STAFF"), f.businessId);
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", acctEmail, "role", "ACCOUNTANT"), f.businessId);
        Instant now = Instant.now();
        String range = "from=" + now.minusSeconds(3600) + "&to=" + now.plusSeconds(86400);

        assertEquals(200, get(staff, "/api/v1/businesses/%s/bookings?" + range, f.businessId).status());
        assertEquals(403, post(staff, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010002003")), f.businessId).status());
        assertEquals(403, get(staff, "/api/v1/businesses/%s/analytics/summary?" + range, f.businessId).status());
        assertEquals(403, patch(staff, "/api/v1/businesses/%s/settings", Map.of("name", "x"), f.businessId).status());
        assertEquals(403, post(staff, "/api/v1/businesses/%s/members", Map.of("email", acctEmail, "role", "BUSINESS_ADMIN"), f.businessId).status());

        assertEquals(200, get(acct, "/api/v1/businesses/%s/analytics/summary?" + range, f.businessId).status());
        assertEquals(403, post(acct, "/api/v1/businesses/%s/services", Map.of("name", "x", "durationMinutes", 30, "price", "1"), f.businessId).status());
        // nobody can mint a second owner through the API
        assertEquals(400, post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", staffEmail, "role", "BUSINESS_OWNER"), f.businessId).status());
    }

    @Test void deactivatedMemberLosesAccessImmediately() {
        Fixture f = Fixture.create(this, 1, false);
        String staff = newUser("gone");
        Res me = get(staff, "/api/v1/me");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", me.text("email"), "role", "RECEPTIONIST"), f.businessId);
        assertEquals(200, get(staff, "/api/v1/businesses/%s", f.businessId).status());
        assertEquals(204, call(MockMvcRequestBuilders.delete("/api/v1/businesses/" + f.businessId + "/members/" + me.text("id")), f.ownerToken, null).status());
        assertEquals(404, get(staff, "/api/v1/businesses/%s", f.businessId).status());
        // the owner cannot be removed
        UUID owner = UUID.fromString(get(f.ownerToken, "/api/v1/me").text("id"));
        assertEquals(400, call(MockMvcRequestBuilders.delete("/api/v1/businesses/" + f.businessId + "/members/" + owner), f.ownerToken, null).status());
    }

    @Test void analyticsKeepBookedValueCollectedCashAndOutstandingApart() {
        Fixture f = Fixture.create(this, 2, false);
        UUID a = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", f.employeeIds.get(0),
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010003001")), f.businessId).id();
        UUID b = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", f.employeeIds.get(1),
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010003002")), f.businessId).id();
        UUID c = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", f.employeeIds.get(0),
                "startsAt", at(bookingDate(), 12, 0).toString(), "customer", f.customer("+77010003003")), f.businessId).id();
        post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", "CANCELLED"), f.businessId, c);
        call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + a + "/payments"), f.ownerToken, Map.of("amount", "20000", "method", "CASH"), "Idempotency-Key", "an-1");
        call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/payments"), f.ownerToken, Map.of("amount", "5000", "method", "CARD_MANUAL"), "Idempotency-Key", "an-2");
        call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/refunds"), f.ownerToken, Map.of("amount", "1000", "method", "CARD_MANUAL"), "Idempotency-Key", "an-3");

        Res r = get(f.ownerToken, "/api/v1/businesses/%s/analytics/summary?from=%s&to=%s", f.businessId,
                Instant.now().minusSeconds(3600), at(bookingDate().plusDays(1), 0, 0)); // covers payment time (now) and visit date
        assertEquals(200, r.status(), r.body().toString());
        assertEquals(3, r.body().path("totalBookings").asInt());
        assertEquals(1, r.body().path("bookingsByStatus").path("CANCELLED").asInt());
        assertEquals(0, new BigDecimal("40000").compareTo(r.body().path("bookedValue").decimalValue()), r.body().toString());   // cancelled excluded
        assertEquals(0, new BigDecimal("25000").compareTo(r.body().path("collected").decimalValue()));
        assertEquals(0, new BigDecimal("1000").compareTo(r.body().path("refunded").decimalValue()));
        assertEquals(0, new BigDecimal("24000").compareTo(r.body().path("netCollected").decimalValue()));
        assertEquals(0, new BigDecimal("16000").compareTo(r.body().path("outstanding").decimalValue())); // b: 20000-4000
        assertEquals(0.3333, r.body().path("cancellationRate").asDouble(), 0.0001);
        assertEquals(400, get(f.ownerToken, "/api/v1/businesses/%s/analytics/summary?from=%s&to=%s", f.businessId, Instant.now(), Instant.now().minusSeconds(5)).status());
    }
}
