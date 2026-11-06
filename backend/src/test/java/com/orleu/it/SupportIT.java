package com.orleu.it;

import com.orleu.notifications.OutboxProcessor;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class SupportIT extends AbstractIT {
    @org.springframework.beans.factory.annotation.Autowired OutboxProcessor processor;

    private String platformUser(String role) {
        String token = newUser(role.toLowerCase());
        jdbc.update("update users set platform_role = ? where lower(email) = lower(?)", role, get(token, "/api/v1/me").text("email"));
        return token;
    }

    private Res open(Fixture f, String subject, String body) {
        return post(f.ownerToken, "/api/v1/businesses/%s/support/tickets", Map.of("subject", subject, "category", "BILLING", "body", body), f.businessId);
    }

    @Test void conversationBetweenBusinessAndPlatformTeam() {
        Fixture f = Fixture.create(this, 1, false);
        String support = platformUser("PLATFORM_SUPPORT");
        Res t = open(f, "Cannot upgrade", "How do I move to PRO?");
        assertEquals(201, t.status(), t.body().toString());
        UUID id = UUID.fromString(t.body().path("ticket").path("id").asText());
        assertEquals("OPEN", t.body().path("ticket").path("status").asText());
        assertEquals(1, t.body().path("messages").size());
        assertFalse(t.body().path("messages").get(0).path("fromPlatform").asBoolean());

        // platform team sees it and answers
        Res list = get(support, "/api/v1/admin/support/tickets?status=OPEN");
        assertTrue(list.body().toString().contains(id.toString()));
        Res reply = post(support, "/api/v1/admin/support/tickets/%s/reply", Map.of("body", "We upgraded you manually."), id);
        assertEquals(200, reply.status());
        assertEquals("ANSWERED", reply.body().path("ticket").path("status").asText());
        assertTrue(reply.body().path("messages").get(1).path("fromPlatform").asBoolean());

        // business sees the answer; replying reopens it
        Res seen = get(f.ownerToken, "/api/v1/businesses/%s/support/tickets/%s", f.businessId, id);
        assertEquals(2, seen.body().path("messages").size());
        Res again = post(f.ownerToken, "/api/v1/businesses/%s/support/tickets/%s/messages", Map.of("body", "Thanks, one more thing"), f.businessId, id);
        assertEquals("OPEN", again.body().path("ticket").path("status").asText());

        // closing blocks further messages from both sides until the platform reopens it
        assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/support/tickets/%s/close", null, f.businessId, id).status());
        assertEquals(409, post(f.ownerToken, "/api/v1/businesses/%s/support/tickets/%s/messages", Map.of("body", "hello?"), f.businessId, id).status());
        assertEquals(409, post(support, "/api/v1/admin/support/tickets/%s/reply", Map.of("body", "late"), id).status());
        assertEquals(200, post(support, "/api/v1/admin/support/tickets/%s/status", Map.of("status", "OPEN"), id).status());
        assertEquals(200, post(support, "/api/v1/admin/support/tickets/%s/reply", Map.of("body", "reopened"), id).status());

        assertTrue(jdbc.queryForObject("select count(*) from audit_logs where entity_id = ? and action like 'SUPPORT_TICKET%'", Integer.class, id) >= 3, "support actions are audited");
    }

    @Test void ticketsAreTenantIsolatedAndRoleChecked() {
        Fixture a = Fixture.create(this, 1, false), b = Fixture.create(this, 1, false);
        UUID id = UUID.fromString(open(a, "Private", "secret details").body().path("ticket").path("id").asText());
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/support/tickets/%s", a.businessId, id).status(), "other tenant cannot reach it");
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/support/tickets/%s", b.businessId, id).status(), "nor through its own business id");
        assertEquals(404, post(b.ownerToken, "/api/v1/businesses/%s/support/tickets/%s/messages", Map.of("body", "x"), b.businessId, id).status());
        assertEquals(0, get(b.ownerToken, "/api/v1/businesses/%s/support/tickets", b.businessId).body().size());
        assertEquals(403, get(a.ownerToken, "/api/v1/admin/support/tickets").status(), "business owners are not platform staff");
        assertEquals(403, get(platformUser("PLATFORM_ANALYST"), "/api/v1/admin/support/tickets").status(), "analysts cannot read ticket text");
        assertEquals(403, post(platformUser("PLATFORM_ANALYST"), "/api/v1/admin/support/tickets/%s/reply", Map.of("body", "x"), id).status());
        assertEquals(401, get(null, "/api/v1/admin/support/tickets").status());
    }

    @Test void validationAndOpenTicketLimit() {
        Fixture f = Fixture.create(this, 1, false);
        assertEquals(400, open(f, "", "body").status());
        assertEquals(400, open(f, "Subject", "   ").status());
        assertEquals(400, post(f.ownerToken, "/api/v1/businesses/%s/support/tickets", Map.of("subject", "S", "category", "NOPE", "body", "b"), f.businessId).status());
        assertEquals(400, open(f, "S", "x".repeat(4001)).status());
        for (int i = 0; i < 20; i++) assertEquals(201, open(f, "Ticket " + i, "details").status());
        Res over = open(f, "One too many", "details");
        assertEquals(409, over.status());
        assertEquals("TOO_MANY_OPEN_TICKETS", over.text("code"));
    }

    @Test void adminUsersListAndDisable() {
        String root = platformUser("SUPER_ADMIN"), support = platformUser("PLATFORM_SUPPORT"), analyst = platformUser("PLATFORM_ANALYST");
        Fixture f = Fixture.create(this, 0, false);
        String email = get(f.ownerToken, "/api/v1/me").text("email");
        Res found = get(support, "/api/v1/admin/users?q=" + email);
        assertEquals(200, found.status());
        assertEquals(1, found.body().path("items").size());
        assertEquals(1, found.body().path("items").get(0).path("businesses").asInt());
        assertEquals(403, get(analyst, "/api/v1/admin/users").status(), "analysts do not see e-mail addresses");
        assertEquals(403, get(f.ownerToken, "/api/v1/admin/users").status());

        UUID userId = UUID.fromString(found.body().path("items").get(0).path("id").asText());
        assertEquals(403, post(support, "/api/v1/admin/users/%s/disable", null, userId).status(), "only super admins can disable");
        Res off = post(root, "/api/v1/admin/users/%s/disable", null, userId);
        assertEquals(200, off.status(), off.body().toString());
        assertEquals("DISABLED", off.text("status"));
        assertEquals(401, post(null, "/api/v1/auth/login", Map.of("email", email, "password", "correct-horse-battery"), new Object[0]).status(), "disabled user cannot sign in");
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where entity_id = ? and action = 'ADMIN_USER_DISABLED'", Integer.class, userId));
        assertEquals("ACTIVE", post(root, "/api/v1/admin/users/%s/enable", null, userId).text("status"));
        assertEquals(200, post(null, "/api/v1/auth/login", Map.of("email", email, "password", "correct-horse-battery"), new Object[0]).status(), "the same credentials work again once enabled");

        UUID self = UUID.fromString(get(root, "/api/v1/me").text("id"));
        assertEquals(400, post(root, "/api/v1/admin/users/%s/disable", null, self).status(), "cannot lock yourself out");
        assertEquals(404, post(root, "/api/v1/admin/users/%s/disable", null, UUID.randomUUID()).status());
    }

    @Test void aSupportReplyNotifiesTheBusinessOwnersButNotOtherStaffRoles() {
        jdbc.update("delete from outbox_events where status = 'PENDING'");
        Fixture f = Fixture.create(this, 1, false);
        String support = platformUser("PLATFORM_SUPPORT");
        UUID id = UUID.fromString(open(f, "Help", "details").body().path("ticket").path("id").asText());
        assertEquals(0, get(f.ownerToken, "/api/v1/businesses/%s/notifications", f.businessId).body().size(), "creating a ticket notifies nobody");
        post(support, "/api/v1/admin/support/tickets/%s/reply", Map.of("body", "Done"), id);
        processor.processDue();
        Res owner = get(f.ownerToken, "/api/v1/businesses/%s/notifications", f.businessId);
        assertEquals(1, owner.body().size());
        assertEquals("SUPPORT_REPLIED", owner.body().get(0).path("eventType").asText());
        assertTrue(owner.body().get(0).path("bookingId").isNull() || owner.body().get(0).path("bookingId").isMissingNode());

        String receptionist = newUser("recep");
        String email = get(receptionist, "/api/v1/me").text("email");
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", email, "role", "RECEPTIONIST"), f.businessId).status());
        assertEquals(0, get(receptionist, "/api/v1/businesses/%s/notifications", f.businessId).body().size(), "receptionists do not see support notifications");
    }
}
