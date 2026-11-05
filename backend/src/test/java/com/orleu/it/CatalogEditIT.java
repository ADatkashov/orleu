package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CatalogEditIT extends AbstractIT {
    private static final String AVAIL = "/api/v1/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s";

    private Res book(Fixture f, UUID service, int hour, String phone) {
        return post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", service,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", f.customer(phone)), f.businessId);
    }

    @Test void serviceEditAppliesToNewBookingsOnly() {
        Fixture f = Fixture.create(this, 1, true);
        Res old = book(f, f.serviceId, 10, "+77010007001");
        assertEquals(0, new BigDecimal("20000").compareTo(old.body().path("financials").path("price").decimalValue()));

        Res up = patch(f.ownerToken, "/api/v1/businesses/%s/services/%s", Map.of("price", "25000.50", "name", "Premium haircut", "durationMinutes", 45,
                "depositPercent", 20), f.businessId, f.serviceId);
        assertEquals(200, up.status(), up.body().toString());
        assertEquals("Premium haircut", up.text("name"));
        assertEquals(45, up.body().path("durationMinutes").asInt());
        assertEquals(0, new BigDecimal("25000.50").compareTo(up.body().path("price").decimalValue()));

        Res fresh = book(f, f.serviceId, 12, "+77010007002");
        assertEquals(0, new BigDecimal("25000.50").compareTo(fresh.body().path("financials").path("price").decimalValue()));
        assertEquals(0, new BigDecimal("5000.10").compareTo(fresh.body().path("financials").path("depositAmount").decimalValue())); // 20% of 25000.50
        assertEquals(0, new BigDecimal("20000").compareTo(get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s", f.businessId, old.id()).body()
                .path("financials").path("price").decimalValue()), "an existing booking keeps its original price");

        // clearing the override falls back to the business default (0%)
        patch(f.ownerToken, "/api/v1/businesses/%s/services/%s", Map.of("useBusinessDeposit", true), f.businessId, f.serviceId);
        Res third = book(f, f.serviceId, 14, "+77010007003");
        assertEquals(0, BigDecimal.ZERO.compareTo(third.body().path("financials").path("depositAmount").decimalValue()));
    }

    @Test void serviceValidation() {
        Fixture f = Fixture.create(this, 1, false);
        String p = "/api/v1/businesses/%s/services/%s";
        assertEquals(400, patch(f.ownerToken, p, Map.of("price", "-1"), f.businessId, f.serviceId).status());
        assertEquals(400, patch(f.ownerToken, p, Map.of("durationMinutes", 1), f.businessId, f.serviceId).status());
        assertEquals(400, patch(f.ownerToken, p, Map.of("depositPercent", 101), f.businessId, f.serviceId).status());
        assertEquals(400, patch(f.ownerToken, p, Map.of("name", "   "), f.businessId, f.serviceId).status());
        assertEquals(404, patch(f.ownerToken, p, Map.of("name", "x"), f.businessId, UUID.randomUUID()).status());
    }

    @Test void deactivatedServiceDisappearsEverywhereAndCanComeBack() throws Exception {
        Fixture f = Fixture.create(this, 1, true);
        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/services/%s", Map.of("active", false), f.businessId, f.serviceId).status());
        assertEquals(404, get(f.ownerToken, AVAIL, f.businessId, f.branchId, f.serviceId, bookingDate()).status());
        assertEquals(404, book(f, f.serviceId, 10, "+77010007004").status());
        assertEquals(0, get(null, "/api/v1/public/businesses/%s", f.slug).body().path("services").size());
        assertEquals(404, get(null, "/api/v1/public/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s", f.slug, f.branchId, f.serviceId, bookingDate()).status());
        assertEquals(1, get(f.ownerToken, "/api/v1/businesses/%s/services", f.businessId).body().size(), "still listed for staff (history is kept)");
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'SERVICE_DEACTIVATED'", Integer.class, f.businessId));

        patch(f.ownerToken, "/api/v1/businesses/%s/services/%s", Map.of("active", true), f.businessId, f.serviceId);
        assertEquals(201, book(f, f.serviceId, 10, "+77010007004").status());
    }

    @Test void deactivatedEmployeeIsNoLongerOfferedAndReactivationRespectsThePlan() {
        Fixture f = Fixture.create(this, 3, true);   // FREE plan: 3 employees allowed
        UUID first = f.employeeIds.get(0);
        assertEquals("Master 0", patch(f.ownerToken, "/api/v1/businesses/%s/employees/%s", Map.of("displayName", " Master 0 "), f.businessId, first).text("displayName"));

        // deactivate all three specialists: nobody is left to offer
        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/employees/%s", Map.of("active", false), f.businessId, first).status());
        for (int i = 1; i < 3; i++) patch(f.ownerToken, "/api/v1/businesses/%s/employees/%s", Map.of("active", false), f.businessId, f.employeeIds.get(i));
        assertEquals(0, get(f.ownerToken, AVAIL, f.businessId, f.branchId, f.serviceId, bookingDate()).body().size());
        assertEquals(0, get(null, "/api/v1/public/businesses/%s", f.slug).body().path("employees").size());

        // the three freed seats are taken by new hires, so bringing the old specialists back must be refused
        for (int i = 0; i < 3; i++) assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "New " + i), f.businessId).status());
        Res back = patch(f.ownerToken, "/api/v1/businesses/%s/employees/%s", Map.of("active", true), f.businessId, first);
        assertEquals(402, back.status());
        assertEquals("EMPLOYEE_LIMIT_REACHED", back.text("code"));
        assertEquals(3, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'EMPLOYEE_DEACTIVATED'", Integer.class, f.businessId));
    }

    @Test void deactivatedBranchIsHiddenAndReactivationRespectsThePlan() {
        Fixture f = Fixture.create(this, 1, true);   // FREE plan: 1 active branch
        assertEquals("New name", patch(f.ownerToken, "/api/v1/businesses/%s/branches/%s", Map.of("name", "New name", "address", "Abay 5"), f.businessId, f.branchId).text("name"));
        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/branches/%s", Map.of("active", false), f.businessId, f.branchId).status());
        assertEquals(404, get(f.ownerToken, AVAIL, f.businessId, f.branchId, f.serviceId, bookingDate()).status());
        assertEquals(0, get(null, "/api/v1/public/businesses/%s", f.slug).body().path("branches").size());
        assertEquals(404, book(f, f.serviceId, 10, "+77010007005").status());

        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/branches", Map.of("name", "Second"), f.businessId).status()); // takes the one allowed seat
        Res back = patch(f.ownerToken, "/api/v1/businesses/%s/branches/%s", Map.of("active", true), f.businessId, f.branchId);
        assertEquals(402, back.status());
        assertEquals("BRANCH_LIMIT_REACHED", back.text("code"));
        assertEquals(400, patch(f.ownerToken, "/api/v1/businesses/%s/branches/%s", Map.of("phone", "8701"), f.businessId, f.branchId).status());
    }

    @Test void foreignCatalogItemsAreNotFoundAndRolesAreEnforced() {
        Fixture a = Fixture.create(this, 1, false), b = Fixture.create(this, 1, false);
        assertEquals(404, patch(b.ownerToken, "/api/v1/businesses/%s/services/%s", Map.of("price", "1"), a.businessId, a.serviceId).status());
        assertEquals(404, patch(b.ownerToken, "/api/v1/businesses/%s/services/%s", Map.of("price", "1"), b.businessId, a.serviceId).status());
        assertEquals(404, patch(b.ownerToken, "/api/v1/businesses/%s/employees/%s", Map.of("active", false), b.businessId, a.employeeId).status());
        assertEquals(404, patch(b.ownerToken, "/api/v1/businesses/%s/branches/%s", Map.of("active", false), b.businessId, a.branchId).status());
        assertEquals("true", String.valueOf(get(a.ownerToken, "/api/v1/businesses/%s/branches", a.businessId).body().get(0).path("active").asBoolean()));

        String recep = newUser("rec"), mgr = newUser("mgr");
        post(a.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(recep, "/api/v1/me").text("email"), "role", "RECEPTIONIST"), a.businessId);
        post(a.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(mgr, "/api/v1/me").text("email"), "role", "BRANCH_MANAGER"), a.businessId);
        assertEquals(403, patch(recep, "/api/v1/businesses/%s/services/%s", Map.of("price", "1"), a.businessId, a.serviceId).status());
        assertEquals(200, patch(mgr, "/api/v1/businesses/%s/services/%s", Map.of("price", "9000"), a.businessId, a.serviceId).status());   // catalog manager
        assertEquals(403, patch(mgr, "/api/v1/businesses/%s/employees/%s", Map.of("active", false), a.businessId, a.employeeId).status()); // staff management is owner/admin only
    }
}
