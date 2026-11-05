package com.orleu.it;

import com.orleu.admin.AdminService;
import com.orleu.admin.PlatformJobs;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class AdminIT extends AbstractIT {
    @Autowired AdminService adminService;
    @Autowired PlatformJobs jobs;

    private String platformUser(String role) {
        String token = newUser(role.toLowerCase());
        jdbc.update("update users set platform_role = ? where lower(email) = lower(?)", role, get(token, "/api/v1/me").text("email"));
        return token;
    }

    private Res setPlan(String token, UUID biz, String plan, Instant expires, String reason) {
        java.util.HashMap<String, Object> m = new java.util.HashMap<>(Map.of("planCode", plan, "reason", reason));
        if (expires != null) m.put("expiresAt", expires.toString());
        return post(token, "/api/v1/admin/businesses/%s/plan", m, biz);
    }

    @Test void adminEndpointsRejectEveryoneWithoutAPlatformRole() {
        Fixture f = Fixture.create(this, 1, false);
        for (String path : new String[]{"/api/v1/admin/businesses", "/api/v1/admin/plans", "/api/v1/admin/audit-logs", "/api/v1/admin/businesses/" + f.businessId}) {
            assertEquals(403, get(f.ownerToken, path.replace("%", "%%")).status(), "business owner must not reach " + path);
            assertEquals(401, get(null, path.replace("%", "%%")).status());
        }
        assertEquals(403, setPlan(f.ownerToken, f.businessId, "PRO", null, "self-upgrade").status()); // no self-service upgrade
    }

    @Test void rolesAreEnforced() {
        Fixture f = Fixture.create(this, 1, false);
        String support = platformUser("PLATFORM_SUPPORT"), analyst = platformUser("PLATFORM_ANALYST"), root = platformUser("SUPER_ADMIN");
        for (String t : new String[]{support, analyst, root}) assertEquals(200, get(t, "/api/v1/admin/businesses/%s", f.businessId).status());
        for (String t : new String[]{support, analyst}) {
            assertEquals(403, setPlan(t, f.businessId, "PRO", null, "x").status());
            assertEquals(403, post(t, "/api/v1/admin/businesses/%s/suspend", Map.of("reason", "x"), f.businessId).status());
            assertEquals(403, put(t, "/api/v1/admin/plans/FREE", Map.of("maxBranches", 9, "maxEmployees", 9)).status());
        }
        assertEquals(200, setPlan(root, f.businessId, "PRO", null, "sales deal").status());
    }

    @Test void revokingAPlatformRoleTakesEffectImmediately() {
        String root = platformUser("SUPER_ADMIN");
        assertEquals(200, get(root, "/api/v1/admin/plans").status());
        jdbc.update("update users set platform_role = null where lower(email) = lower(?)", get(root, "/api/v1/me").text("email"));
        assertEquals(403, get(root, "/api/v1/admin/plans").status());
    }

    @Test void planChangeUpdatesLimitsKeepsHistoryAndAudit() {
        Fixture f = Fixture.create(this, 3, false);
        String root = platformUser("SUPER_ADMIN");
        assertEquals(402, post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "4th"), f.businessId).status());
        assertEquals(400, setPlan(root, f.businessId, "PRO", null, " ").status());                              // reason required
        assertEquals(404, setPlan(root, f.businessId, "NOPE", null, "x").status());                            // unknown plan
        assertEquals(400, setPlan(root, f.businessId, "PRO", Instant.now().minusSeconds(60), "x").status());  // expiry in the past
        Res r = setPlan(root, f.businessId, "PRO", Instant.now().plusSeconds(86400 * 30), "annual deal");
        assertEquals(200, r.status(), r.body().toString());
        assertEquals("PRO", r.body().path("business").path("planCode").asText());
        assertEquals(1, r.body().path("history").size());
        assertEquals("FREE", r.body().path("history").get(0).path("fromPlan").asText());
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "4th"), f.businessId).status());
        assertEquals("PRO", get(f.ownerToken, "/api/v1/businesses/%s/subscription", f.businessId).text("planCode"));
        Res log = get(root, "/api/v1/admin/audit-logs?businessId=%s&action=ADMIN_PLAN_CHANGED", f.businessId);
        assertEquals(1, log.body().path("items").size());
    }

    @Test void suspensionLocksTheTenantAndHidesPublicPagesUntilReactivated() throws Exception {
        Fixture f = Fixture.create(this, 1, true);
        String root = platformUser("SUPER_ADMIN");
        assertEquals(200, get(null, "/api/v1/public/businesses/%s", f.slug).status());
        assertEquals(400, post(root, "/api/v1/admin/businesses/%s/suspend", Map.of(), f.businessId).status()); // reason required
        assertEquals(200, post(root, "/api/v1/admin/businesses/%s/suspend", Map.of("reason", "chargeback fraud"), f.businessId).status());

        Res denied = get(f.ownerToken, "/api/v1/businesses/%s/bookings?from=" + Instant.now() + "&to=" + Instant.now().plusSeconds(3600), f.businessId);
        assertEquals(403, denied.status());
        assertEquals("BUSINESS_SUSPENDED", denied.text("code"));
        assertEquals(403, post(f.ownerToken, "/api/v1/businesses/%s/services", Map.of("name", "x", "durationMinutes", 30, "price", "1"), f.businessId).status());
        assertEquals(404, get(null, "/api/v1/public/businesses/%s", f.slug).status());
        assertEquals(404, post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010005001")), f.slug).status());
        assertEquals(404, mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/b/" + f.slug)).andReturn().getResponse().getStatus());
        // the admin can still read it, and the reason is visible
        assertEquals("chargeback fraud", get(root, "/api/v1/admin/businesses/%s", f.businessId).text("suspendedReason"));

        assertEquals(200, post(root, "/api/v1/admin/businesses/%s/reactivate", null, f.businessId).status());
        assertEquals(200, get(f.ownerToken, "/api/v1/businesses/%s", f.businessId).status());
        assertEquals(404, get(null, "/api/v1/public/businesses/%s", f.slug).status(), "reactivation must not silently republish");
        assertEquals(2, get(root, "/api/v1/admin/audit-logs?businessId=%s", f.businessId).body().path("items").findValues("action").stream()
                .filter(a -> a.asText().startsWith("ADMIN_BUSINESS_")).count());
    }

    @Test void planLimitsAreEditableDataNotCode() {
        Fixture f = Fixture.create(this, 3, false);
        String root = platformUser("SUPER_ADMIN");
        try {
            assertEquals(400, put(root, "/api/v1/admin/plans/FREE", Map.of("maxBranches", 0, "maxEmployees", 5)).status());
            assertEquals(200, put(root, "/api/v1/admin/plans/FREE", Map.of("maxBranches", 1, "maxEmployees", 5)).status());
            assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "4th"), f.businessId).status());
        } finally {
            put(root, "/api/v1/admin/plans/FREE", Map.of("maxBranches", 1, "maxEmployees", 3));
        }
    }

    @Test void expiredSubscriptionsFallBackToFreeWithoutDeletingData() {
        Fixture f = Fixture.create(this, 3, false);
        String root = platformUser("SUPER_ADMIN");
        setPlan(root, f.businessId, "PRO", Instant.now().plusSeconds(3600), "trial");
        post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "4th"), f.businessId); // allowed on PRO
        jdbc.update("update businesses set plan_expires_at = now() - interval '1 hour' where id = ?", f.businessId);
        assertTrue(adminService.downgradeExpiredPlans() >= 1);
        assertEquals("FREE", get(f.ownerToken, "/api/v1/businesses/%s/subscription", f.businessId).text("planCode"));
        assertEquals(4, get(f.ownerToken, "/api/v1/businesses/%s/employees", f.businessId).body().size()); // nothing deleted
        assertEquals(402, post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "5th"), f.businessId).status());
        adminService.downgradeExpiredPlans(); // idempotent: running again must not create a second event
        assertEquals(2, jdbc.queryForObject("select count(*) from subscription_events where business_id = ?", Integer.class, f.businessId)); // PRO grant + expiry
        var detail = get(root, "/api/v1/admin/businesses/%s", f.businessId);
        assertEquals("subscription period ended", detail.body().path("history").get(0).path("reason").asText());
        assertTrue(detail.body().path("history").get(0).path("actorUserId").isMissingNode(), "system actions have no actor");
    }

    @Test void bootstrapPromotesOnlyWhenNoSuperAdminExists() throws Exception {
        jdbc.update("update users set platform_role = null where platform_role = 'SUPER_ADMIN'"); // deterministic start (tests create their own admins)
        var client = org.springframework.jdbc.core.simple.JdbcClient.create(jdbc);
        String first = newUser("boot1"), second = newUser("boot2");
        String e1 = get(first, "/api/v1/me").text("email"), e2 = get(second, "/api/v1/me").text("email");

        new PlatformJobs(adminService, client, "").run(new DefaultApplicationArguments());   // not configured: no-op
        assertNull(jdbc.queryForObject("select platform_role from users where lower(email) = lower(?)", String.class, e1));
        new PlatformJobs(adminService, client, "nobody@example.com").run(new DefaultApplicationArguments()); // unknown user: no-op
        new PlatformJobs(adminService, client, e1).run(new DefaultApplicationArguments());
        assertEquals("SUPER_ADMIN", jdbc.queryForObject("select platform_role from users where lower(email) = lower(?)", String.class, e1));
        new PlatformJobs(adminService, client, e2).run(new DefaultApplicationArguments());   // a super admin already exists
        assertNull(jdbc.queryForObject("select platform_role from users where lower(email) = lower(?)", String.class, e2));
    }

    @Test void adminListingSupportsSearchAndPagination() {
        Fixture a = Fixture.create(this, 0, false);
        String root = platformUser("SUPER_ADMIN");
        Res found = get(root, "/api/v1/admin/businesses?q=%s&size=5", a.slug.substring(0, 8));
        assertEquals(200, found.status());
        assertTrue(found.body().path("items").size() >= 1);
        assertEquals(1, get(root, "/api/v1/admin/businesses?size=1").body().path("items").size());
    }
}
