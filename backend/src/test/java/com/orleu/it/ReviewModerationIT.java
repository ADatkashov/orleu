package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class ReviewModerationIT extends AbstractIT {
    private String platformUser(String role) {
        String token = newUser("modr" + role.substring(0, 3).toLowerCase());
        jdbc.update("update users set platform_role = ? where lower(email) = lower(?)", role, get(token, "/api/v1/me").text("email"));
        return token;
    }

    /** A completed, reviewed visit; returns {manageToken, reviewId}. */
    private String[] reviewed(Fixture f, int hour, String phone, int rating, String comment) {
        Res r = post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Guest " + phone, "phone", phone)), f.slug);
        assertEquals(201, r.status(), r.body().toString());
        for (String s : new String[]{"CHECKED_IN", "IN_PROGRESS", "COMPLETED"})
            assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", s), f.businessId, UUID.fromString(r.text("bookingId"))).status());
        assertEquals(201, post(null, "/api/v1/public/manage/%s/review", Map.of("rating", rating, "comment", comment), r.text("manageToken")).status());
        String id = get(f.ownerToken, "/api/v1/businesses/%s/reviews", f.businessId).body().get(0).path("id").asText();
        return new String[]{r.text("manageToken"), id};
    }

    private Res reply(String token, Fixture f, String id, String text) {
        return call(MockMvcRequestBuilders.put("/api/v1/businesses/" + f.businessId + "/reviews/" + id + "/reply"), token, Map.of("text", text));
    }

    @Test void theBusinessReplyReachesTheGuestAndCanBeRemoved() {
        Fixture f = Fixture.create(this, 1, true);
        String[] rv = reviewed(f, 10, "+77010013001", 2, "waited too long");
        assertTrue(get(null, "/api/v1/public/manage/%s", rv[0]).body().path("businessReply").isMissingNode() || get(null, "/api/v1/public/manage/%s", rv[0]).body().path("businessReply").isNull());
        Res r = reply(f.ownerToken, f, rv[1], "  We are sorry - we have changed our schedule.  ");
        assertEquals(200, r.status(), r.body().toString());
        assertEquals("We are sorry - we have changed our schedule.", r.body().path("reply").asText());
        assertEquals("We are sorry - we have changed our schedule.", get(null, "/api/v1/public/manage/%s", rv[0]).body().path("businessReply").asText());
        Res del = call(MockMvcRequestBuilders.delete("/api/v1/businesses/" + f.businessId + "/reviews/" + rv[1] + "/reply"), f.ownerToken, null);
        assertEquals(200, del.status());
        var g = get(null, "/api/v1/public/manage/%s", rv[0]).body().path("businessReply");
        assertTrue(g.isMissingNode() || g.isNull());
    }

    @Test void replyValidationPermissionsAndIsolation() {
        Fixture f = Fixture.create(this, 1, true), other = Fixture.create(this, 1, true);
        String[] rv = reviewed(f, 10, "+77010013002", 4, "ok");
        assertEquals(400, reply(f.ownerToken, f, rv[1], "   ").status());
        assertEquals(400, reply(f.ownerToken, f, rv[1], "x".repeat(1001)).status());
        String recep = newUser("receprv");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(recep, "/api/v1/me").text("email"), "role", "RECEPTIONIST"), f.businessId);
        assertEquals(403, reply(recep, f, rv[1], "hello").status(), "replying speaks for the business: owner/admin only");
        assertEquals(404, reply(other.ownerToken, other, rv[1], "hello").status(), "a review of another business");
        assertEquals(404, reply(other.ownerToken, f, rv[1], "hello").status());
        assertEquals(401, reply(null, f, rv[1], "hello").status());
    }

    @Test void platformSupportHidesAReviewWithAReasonAndTheAverageAndGuestReplyFollow() {
        Fixture f = Fixture.create(this, 1, true);
        String[] good = reviewed(f, 10, "+77010013003", 5, "great");
        String[] abuse = reviewed(f, 11, "+77010013004", 1, "spam spam http://bad.example");
        // list is newest first; find the abusive review id
        String abuseId = null;
        for (var n : get(f.ownerToken, "/api/v1/businesses/%s/reviews", f.businessId).body()) if (n.path("rating").asInt() == 1) abuseId = n.path("id").asText();
        assertNotNull(abuseId);
        assertEquals(0, new java.math.BigDecimal("3").compareTo(get(f.ownerToken, "/api/v1/businesses/%s/reviews/summary", f.businessId).body().path("average").decimalValue()));
        assertEquals(200, reply(f.ownerToken, f, abuseId, "This is not true").status());

        String support = platformUser("PLATFORM_SUPPORT");
        assertEquals(400, post(support, "/api/v1/admin/reviews/%s/hide", Map.of("reason", "no"), abuseId).status(), "a real reason is required");
        assertEquals(204, post(support, "/api/v1/admin/reviews/%s/hide", Map.of("reason", "Spam with a link, not a customer experience"), abuseId).status());

        var sum = get(f.ownerToken, "/api/v1/businesses/%s/reviews/summary", f.businessId).body();
        assertEquals(1, sum.path("count").asInt());
        assertEquals(0, new java.math.BigDecimal("5").compareTo(sum.path("average").decimalValue()), "hidden reviews do not count");
        final String hiddenId = abuseId;
        var row = get(f.ownerToken, "/api/v1/businesses/%s/reviews", f.businessId).body();
        boolean seen = false;
        for (var n : row) if (n.path("id").asText().equals(hiddenId)) { seen = true; assertTrue(n.path("hidden").asBoolean()); assertFalse(n.path("hiddenReason").asText().isEmpty()); }
        assertTrue(seen, "the business still sees it, marked as hidden, with the reason");
        assertEquals(409, reply(f.ownerToken, f, abuseId, "again").status(), "no new replies on a hidden review");
        var g = get(null, "/api/v1/public/manage/%s", abuse[0]).body().path("businessReply");
        assertTrue(g.isMissingNode() || g.isNull(), "the guest page no longer shows the business reply of a hidden review");
        assertEquals(1, get(support, "/api/v1/admin/reviews?hidden=true").body().size());
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where action = 'REVIEW_HIDDEN' and business_id = ?", Integer.class, f.businessId));

        assertEquals(204, post(support, "/api/v1/admin/reviews/%s/unhide", Map.of(), abuseId).status());
        assertEquals(2, get(f.ownerToken, "/api/v1/businesses/%s/reviews/summary", f.businessId).body().path("count").asInt());
    }

    @Test void onlySupportStaffModerateAndBusinessesCannotHide() {
        Fixture f = Fixture.create(this, 1, true);
        String[] rv = reviewed(f, 10, "+77010013005", 1, "bad");
        assertEquals(403, post(f.ownerToken, "/api/v1/admin/reviews/%s/hide", Map.of("reason", "I do not like it"), rv[1]).status(), "a business cannot hide its own bad reviews");
        assertEquals(403, post(platformUser("PLATFORM_ANALYST"), "/api/v1/admin/reviews/%s/hide", Map.of("reason", "analyst tries"), rv[1]).status());
        assertEquals(403, get(platformUser("PLATFORM_ANALYST"), "/api/v1/admin/reviews").status(), "comments are personal data");
        assertEquals(404, post(platformUser("PLATFORM_SUPPORT"), "/api/v1/admin/reviews/%s/hide", Map.of("reason", "unknown review id"), UUID.randomUUID()).status());
        assertEquals(401, get(null, "/api/v1/admin/reviews").status());
        assertEquals(0, jdbc.queryForObject("select count(*) from reviews where hidden and business_id = ?", Integer.class, f.businessId), "nothing was hidden by the refused attempts");
    }
}
