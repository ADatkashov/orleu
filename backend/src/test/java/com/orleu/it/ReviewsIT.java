package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class ReviewsIT extends AbstractIT {
    /** Guest books online; returns {bookingId, manageToken}. */
    private String[] guestBooking(Fixture f, int hour, String phone) {
        Res r = post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Aigerim Guest", "phone", phone)), f.slug);
        assertEquals(201, r.status(), r.body().toString());
        return new String[]{r.text("bookingId"), r.text("manageToken")};
    }

    private void complete(Fixture f, String bookingId) {
        for (String s : new String[]{"CHECKED_IN", "IN_PROGRESS", "COMPLETED"})
            assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", s), f.businessId, UUID.fromString(bookingId)).status());
    }

    private Res review(String token, int rating, String comment) {
        return post(null, "/api/v1/public/manage/%s/review", Map.of("rating", rating, "comment", comment), token);
    }

    @Test void onlyCompletedVisitsCanBeReviewedAndOnlyOnce() {
        Fixture f = Fixture.create(this, 1, true);
        String[] b = guestBooking(f, 10, "+77010007001");
        assertFalse(get(null, "/api/v1/public/manage/%s", b[1]).body().path("canReview").asBoolean());
        assertEquals(409, review(b[1], 5, "great").status(), "an upcoming visit cannot be reviewed");
        assertEquals("REVIEW_NOT_ALLOWED", review(b[1], 5, "great").text("code"));

        complete(f, b[0]);
        assertTrue(get(null, "/api/v1/public/manage/%s", b[1]).body().path("canReview").asBoolean());
        assertEquals(201, review(b[1], 5, "Great haircut").status());
        Res again = review(b[1], 1, "changed my mind");
        assertEquals(409, again.status());
        assertEquals("ALREADY_REVIEWED", again.text("code"));
        var view = get(null, "/api/v1/public/manage/%s", b[1]).body();
        assertFalse(view.path("canReview").asBoolean());
        assertEquals(5, view.path("reviewRating").asInt());
    }

    @Test void invalidInputAndUnknownTokensAreRejected() {
        Fixture f = Fixture.create(this, 1, true);
        String[] b = guestBooking(f, 10, "+77010007002");
        complete(f, b[0]);
        assertEquals(400, review(b[1], 0, "x").status());
        assertEquals(400, review(b[1], 6, "x").status());
        assertEquals(400, review(b[1], 5, "x".repeat(1001)).status());
        assertEquals(404, review("a".repeat(43), 5, "x").status());
        assertEquals(404, review("short", 5, "x").status());
        assertEquals(0, get(f.ownerToken, "/api/v1/businesses/%s/reviews", f.businessId).body().size());
    }

    @Test void staffSeeReviewsAndMeasuredSummaryAndTheBookingPageShowsTheAverage() {
        Fixture f = Fixture.create(this, 1, true);
        assertEquals(0, get(null, "/api/v1/public/businesses/%s", f.slug).body().path("reviewCount").asInt());
        assertFalse(get(null, "/api/v1/public/businesses/%s", f.slug).body().path("averageRating").isNumber(), "no reviews = no average");
        String[] a = guestBooking(f, 10, "+77010007003"), c = guestBooking(f, 12, "+77010007004");
        complete(f, a[0]); complete(f, c[0]);
        assertEquals(201, review(a[1], 5, "<b>Great</b>").status());
        assertEquals(201, review(c[1], 4, "").status());

        Res list = get(f.ownerToken, "/api/v1/businesses/%s/reviews", f.businessId);
        assertEquals(200, list.status());
        assertEquals(2, list.body().size());
        boolean sawComment = false;
        for (var r : list.body()) {
            assertEquals("Aigerim Guest", r.path("customerName").asText());
            if (r.path("rating").asInt() == 5) { assertEquals("<b>Great</b>", r.path("comment").asText()); sawComment = true; }
            else assertFalse(r.path("comment").isTextual(), "an empty comment is stored as null");
        }
        assertTrue(sawComment);
        var sum = get(f.ownerToken, "/api/v1/businesses/%s/reviews/summary", f.businessId).body();
        assertEquals(2, sum.path("count").asInt());
        assertEquals(4.5, sum.path("average").asDouble(), 0.0001);
        assertEquals(1, sum.path("distribution").get(4).asInt());
        assertEquals(1, sum.path("distribution").get(3).asInt());
        var pub = get(null, "/api/v1/public/businesses/%s", f.slug).body();
        assertEquals(2, pub.path("reviewCount").asInt());
        assertEquals(4.5, pub.path("averageRating").asDouble(), 0.0001);
    }

    @Test void reviewsAreTenantIsolated() {
        Fixture a = Fixture.create(this, 1, true), b = Fixture.create(this, 1, true);
        String[] g = guestBooking(a, 10, "+77010007005");
        complete(a, g[0]);
        review(g[1], 5, "ok");
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/reviews", a.businessId).status());
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/reviews/summary", a.businessId).status());
        assertEquals(0, get(b.ownerToken, "/api/v1/businesses/%s/reviews", b.businessId).body().size());
        assertEquals(0, get(null, "/api/v1/public/businesses/%s", b.slug).body().path("reviewCount").asInt());
    }
}
