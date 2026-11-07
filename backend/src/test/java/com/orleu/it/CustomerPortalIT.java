package com.orleu.it;

import com.orleu.auth.SystemMessageTemplates;
import com.orleu.notifications.MessageDispatcher;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;

class CustomerPortalIT extends AbstractIT {
    @Autowired MessageDispatcher dispatcher;

    private static final java.util.Map<String, String> PHONES = new java.util.concurrent.ConcurrentHashMap<>();
    private static final java.util.concurrent.atomic.AtomicLong SEQ = new java.util.concurrent.atomic.AtomicLong(System.nanoTime() % 10_000_000L);

    /** A phone number that is unique per test run (the local test database keeps rows between runs); stable for one label within the run. */
    private static String p(String label) { return PHONES.computeIfAbsent(label, k -> "+7701" + String.format("%07d", SEQ.incrementAndGet() % 10_000_000L)); }

    private Res requestCode(Fixture f, String phone) { return post(null, "/api/v1/public/businesses/%s/portal/code", Map.of("phone", phone), f.slug); }
    private Res verify(Fixture f, String phone, String code) { return post(null, "/api/v1/public/businesses/%s/portal/verify", Map.of("phone", phone, "code", code), f.slug); }
    private Res me(Fixture f, String token) { return call(MockMvcRequestBuilders.get("/api/v1/public/businesses/" + f.slug + "/portal/me"), null, null, "X-Portal-Token", token == null ? "" : token); }

    private UUID guestBooking(Fixture f, String phone, int hour) {
        Res r = post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Portal Guest", "phone", phone)), f.slug);
        assertEquals(201, r.status(), r.body().toString());
        return UUID.fromString(r.text("bookingId"));
    }

    /** The newest SMS code queued for the phone (read straight from the queued message body). */
    private String queuedCode(String phone) {
        String body = jdbc.queryForObject("select body from system_messages where recipient = ? and purpose = 'PORTAL_CODE' and body is not null order by created_at desc limit 1", String.class, phone);
        Matcher m = Pattern.compile("\\b(\\d{6})\\b").matcher(body);
        assertTrue(m.find(), body);
        return m.group(1);
    }

    private String signIn(Fixture f, String phone) {
        assertEquals(202, requestCode(f, phone).status());
        Res v = verify(f, phone, queuedCode(phone));
        assertEquals(200, v.status(), v.body().toString());
        return v.text("token");
    }

    @Test void signInShowsOnlyMyBookingsAndCancelFollowsTheFreeCancellationRule() {
        Fixture f = Fixture.create(this, 1, true);
        String phone = p("+77010030001");
        UUID mine = guestBooking(f, phone, 10);
        guestBooking(f, p("+77010030002"), 11); // somebody else's booking in the same business
        String token = signIn(f, phone);

        var body = me(f, token).body();
        assertEquals("Portal Guest", body.path("fullName").asText());
        assertEquals(1, body.path("bookings").size(), "only this customer's booking");
        assertEquals(mine.toString(), body.path("bookings").get(0).path("id").asText());
        assertTrue(body.path("bookings").get(0).path("canCancel").asBoolean());
        assertFalse(body.toString().contains("77010030002"), "no other customer's data");

        Res c = call(MockMvcRequestBuilders.post("/api/v1/public/businesses/" + f.slug + "/portal/bookings/" + mine + "/cancel"), null, null, "X-Portal-Token", token);
        assertEquals(200, c.status(), c.body().toString());
        assertEquals("CANCELLED", c.text("status"));
        assertEquals("CANCELLED", jdbc.queryForObject("select status from bookings where id = ?", String.class, mine));
    }

    @Test void theCodeIsSentBySmsInTheBusinessLanguageAndWipedOnceDelivered() {
        Fixture f = Fixture.create(this, 1, true);
        String phone = p("+77010030003");
        guestBooking(f, phone, 10);
        assertEquals(202, requestCode(f, phone).status());
        var m = jdbc.queryForMap("select channel, body, subject from system_messages where recipient = ? and purpose = 'PORTAL_CODE'", phone);
        assertEquals("SMS", m.get("channel"));
        assertTrue(((String) m.get("body")).contains("код входа"), "default customer language is Russian");
        dispatcher.dispatchSystemDue(1000);
        assertNull(jdbc.queryForObject("select body from system_messages where recipient = ? and purpose = 'PORTAL_CODE'", String.class, phone), "the code is gone after delivery");
    }

    @Test void unknownBlockedAndAnonymousNumbersLookExactlyLikeKnownOnes() {
        Fixture f = Fixture.create(this, 1, true);
        guestBooking(f, p("+77010030004"), 10);
        Res known = requestCode(f, p("+77010030004")), unknown = requestCode(f, p("+77010039999"));
        assertEquals(known.status(), unknown.status());
        assertEquals(known.body().toString(), unknown.body().toString());
        assertEquals(0, jdbc.queryForObject("select count(*) from system_messages where recipient = ?", Integer.class, p("+77010039999")), "nothing sent to an unknown number");
        assertEquals(400, verify(f, p("+77010039999"), "123456").status());

        UUID cid = jdbc.queryForObject("select id from customers where business_id = ? and phone = ?", UUID.class, f.businessId, p("+77010030004"));
        jdbc.update("update customers set blocked = true where id = ?", cid);
        int before = jdbc.queryForObject("select count(*) from system_messages where recipient = ?", Integer.class, p("+77010030004"));
        assertEquals(202, requestCode(f, p("+77010030004")).status());
        assertEquals(before, jdbc.queryForObject("select count(*) from system_messages where recipient = ?", Integer.class, p("+77010030004")), "a blocked customer gets no code");
        assertEquals(202, requestCode(f, "garbage").status(), "even malformed input answers the same way");
    }

    @Test void fiveWrongGuessesBurnTheCodeAndItCannotBeUsedAgainEvenIfCorrect() {
        Fixture f = Fixture.create(this, 1, true);
        String phone = p("+77010030005");
        guestBooking(f, phone, 10);
        requestCode(f, phone);
        String right = queuedCode(phone);
        String wrong = right.equals("000000") ? "000001" : "000000";
        for (int i = 0; i < 5; i++) assertEquals(400, verify(f, phone, wrong).status());
        assertEquals("INVALID_CODE", verify(f, phone, right).text("code"), "the right code no longer works after 5 failures");
        assertEquals(400, verify(f, phone, "abc").status());
    }

    @Test void aCodeWorksOnceExpiresAndAtMostThreeAreSentPer15Minutes() {
        Fixture f = Fixture.create(this, 1, true);
        String phone = p("+77010030006");
        guestBooking(f, phone, 10);
        String t1 = signIn(f, phone);
        assertNotNull(t1);
        String used = queuedCode(phone);
        assertEquals(400, verify(f, phone, used).status(), "a used code is dead");

        String phone2 = p("+77010030007");
        guestBooking(f, phone2, 11);
        requestCode(f, phone2);
        String code = queuedCode(phone2);
        jdbc.update("update portal_otps set expires_at = now() - interval '1 minute' where customer_id = (select id from customers where business_id = ? and phone = ?)", f.businessId, phone2);
        assertEquals(400, verify(f, phone2, code).status(), "expired");

        String phone3 = p("+77010030008");
        guestBooking(f, phone3, 12);
        for (int i = 0; i < 6; i++) requestCode(f, phone3);
        assertEquals(3, jdbc.queryForObject("select count(*) from system_messages where recipient = ? and purpose = 'PORTAL_CODE'", Integer.class, phone3), "capped at 3 per 15 minutes");
    }

    @Test void sessionsAreScopedToOneBusinessExpireAndLogoutRevokesThem() {
        Fixture a = Fixture.create(this, 1, true), b = Fixture.create(this, 1, true);
        String phone = p("+77010030009");
        guestBooking(a, phone, 10);
        guestBooking(b, phone, 10); // the same person is a customer of two businesses: separate records
        String tokenA = signIn(a, phone);
        assertEquals(401, me(b, tokenA).status(), "business A's session is not valid under business B's address");
        UUID bookingB = jdbc.queryForObject("select id from bookings where business_id = ? limit 1", UUID.class, b.businessId);
        String statusB = jdbc.queryForObject("select status from bookings where id = ?", String.class, bookingB);
        Res cross = call(MockMvcRequestBuilders.post("/api/v1/public/businesses/" + a.slug + "/portal/bookings/" + bookingB + "/cancel"), null, null, "X-Portal-Token", tokenA);
        assertEquals(404, cross.status(), "a booking of another business is not even visible");
        assertEquals(401, call(MockMvcRequestBuilders.post("/api/v1/public/businesses/" + b.slug + "/portal/bookings/" + bookingB + "/cancel"), null, null, "X-Portal-Token", tokenA).status(), "nor cancellable through the other address");
        assertEquals(statusB, jdbc.queryForObject("select status from bookings where id = ?", String.class, bookingB), "and it was not touched");

        assertEquals(401, me(a, null).status());
        assertEquals(401, me(a, "x".repeat(43)).status());
        jdbc.update("update portal_sessions set expires_at = now() - interval '1 minute' where token_hash is not null and business_id = ?", a.businessId);
        assertEquals(401, me(a, tokenA).status(), "expired session");

        String fresh = signIn(a, phone);
        assertEquals(200, me(a, fresh).status());
        assertEquals(204, call(MockMvcRequestBuilders.post("/api/v1/public/businesses/" + a.slug + "/portal/logout"), null, null, "X-Portal-Token", fresh).status());
        assertEquals(401, me(a, fresh).status(), "logout revokes the session");
        assertEquals(0, jdbc.queryForObject("select count(*) from portal_sessions where token_hash = ?", Integer.class, fresh), "only a hash is stored");
    }

    @Test void thePortalPageHasStrictHeadersAndAnUnknownSlugIs404() throws Exception {
        Fixture f = Fixture.create(this, 1, true);
        var ok = mvc.perform(MockMvcRequestBuilders.get("/b/" + f.slug + "/me")).andReturn().getResponse();
        assertEquals(200, ok.getStatus());
        assertTrue(ok.getHeader("Content-Security-Policy").contains("script-src 'self'"));
        assertTrue(ok.getHeader("Cache-Control").contains("no-store"));
        assertEquals("no-referrer", ok.getHeader("Referrer-Policy"));
        assertTrue(ok.getContentAsString().contains("/pub/portal.js"));
        assertEquals(404, mvc.perform(MockMvcRequestBuilders.get("/b/no-such-business-xyz/me")).andReturn().getResponse().getStatus());
    }
}
