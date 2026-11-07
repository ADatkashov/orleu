package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

class CashClosingIT extends AbstractIT {
    private UUID booking(Fixture f, String phone, int hour) {
        Res b = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Cash Customer", "phone", phone)), f.businessId);
        assertEquals(201, b.status(), b.body().toString());
        return b.id();
    }

    private void money(Fixture f, UUID booking, String kind, String method, String amount) {
        Res r = call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + booking + "/" + kind), f.ownerToken,
                Map.of("amount", amount, "method", method), "Idempotency-Key", kind + "-" + UUID.randomUUID());
        assertEquals(201, r.status(), r.body().toString());
    }

    private Res close(String token, Fixture f, Object expected, Object counted, String note) {
        var body = new java.util.HashMap<String, Object>();
        body.put("expectedCash", expected); body.put("countedCash", counted);
        if (note != null) body.put("note", note);
        return post(token, "/api/v1/businesses/%s/finance/closings", body, f.businessId);
    }

    private BigDecimal dec(Res r, String... path) {
        var n = r.body();
        for (String p : path) n = n.path(p);
        return n.decimalValue();
    }

    @Test void expectedCashIsDerivedFromTheLedgerByMethodAndRefundsAreSubtracted() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b1 = booking(f, "+77010012001", 10), b2 = booking(f, "+77010012002", 11);
        money(f, b1, "payments", "CASH", "10000");
        money(f, b1, "refunds", "CASH", "2000");
        money(f, b2, "payments", "CASH", "5000");
        money(f, b2, "payments", "BANK_TRANSFER", "7000");
        money(f, b2, "payments", "CARD_MANUAL", "3000");
        Res p = get(f.ownerToken, "/api/v1/businesses/%s/finance/closing-preview", f.businessId);
        assertEquals(200, p.status(), p.body().toString());
        assertEquals(0, new BigDecimal("13000").compareTo(dec(p, "cash", "net")));
        assertEquals(0, new BigDecimal("15000").compareTo(dec(p, "cash", "payments")));
        assertEquals(0, new BigDecimal("2000").compareTo(dec(p, "cash", "refunds")));
        assertEquals(0, new BigDecimal("7000").compareTo(dec(p, "bank", "net")));
        assertEquals(0, new BigDecimal("3000").compareTo(dec(p, "card", "net")));
        assertTrue(p.body().path("firstClosing").asBoolean());
    }

    @Test void closingRecordsTheDifferenceAndTheNextPeriodStartsWhereItEnded() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = booking(f, "+77010012003", 10);
        money(f, b, "payments", "CASH", "10000");
        Res c = close(f.ownerToken, f, 10000, 9500, "missing 500 - change given wrongly");
        assertEquals(201, c.status(), c.body().toString());
        assertEquals(0, new BigDecimal("-500").compareTo(dec(c, "difference")), "negative = shortage");
        assertEquals(0, new BigDecimal("10000").compareTo(dec(c, "expectedCash")));
        assertEquals("missing 500 - change given wrongly", c.body().path("note").asText());

        // the closed period is no longer open
        Res p = get(f.ownerToken, "/api/v1/businesses/%s/finance/closing-preview", f.businessId);
        assertEquals(0, BigDecimal.ZERO.compareTo(dec(p, "cash", "net")));
        assertFalse(p.body().path("firstClosing").asBoolean());
        money(f, b, "payments", "CASH", "1000");
        assertEquals(0, new BigDecimal("1000").compareTo(dec(get(f.ownerToken, "/api/v1/businesses/%s/finance/closing-preview", f.businessId), "cash", "net")));
        Res c2 = close(f.ownerToken, f, 1000, 1000, null);
        assertEquals(201, c2.status());
        assertEquals(0, BigDecimal.ZERO.compareTo(dec(c2, "difference")));
        Res h = get(f.ownerToken, "/api/v1/businesses/%s/finance/closings", f.businessId);
        assertEquals(2, h.body().size());
        assertEquals(c2.id().toString(), h.body().get(0).path("id").asText(), "newest first");
        // periods are contiguous: the second starts exactly where the first ended
        assertEquals(h.body().get(1).path("periodEnd").asText(), h.body().get(0).path("periodStart").asText());
    }

    @Test void staleExpectedAmountIsRefusedAndNothingIsRecorded() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = booking(f, "+77010012004", 10);
        money(f, b, "payments", "CASH", "4000");
        // the user opened the preview when it said 4000; meanwhile another 1000 arrives
        money(f, b, "payments", "CASH", "1000");
        Res r = close(f.ownerToken, f, 4000, 4000, null);
        assertEquals(409, r.status());
        assertEquals("EXPECTED_CHANGED", r.body().path("code").asText());
        assertEquals(0, jdbc.queryForObject("select count(*) from cash_closings where business_id = ?", Integer.class, f.businessId));
        assertEquals(201, close(f.ownerToken, f, 5000, 5000, null).status());
    }

    @Test void closingsAreAppendOnlyValidatedAndConcurrentClosesRecordOnce() throws Exception {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = booking(f, "+77010012005", 10);
        money(f, b, "payments", "CASH", "3000");
        assertEquals(400, close(f.ownerToken, f, 3000, -1, null).status());
        assertEquals(400, close(f.ownerToken, f, 3000, 3000, "x".repeat(501)).status());
        ExecutorService pool = Executors.newFixedThreadPool(4);
        CountDownLatch go = new CountDownLatch(1);
        var futures = new java.util.ArrayList<Future<Integer>>();
        for (int i = 0; i < 4; i++) futures.add(pool.submit(() -> { go.await(); return close(f.ownerToken, f, 3000, 3000, null).status(); }));
        go.countDown();
        int created = 0;
        for (var fu : futures) if (fu.get(30, TimeUnit.SECONDS) == 201) created++;
        pool.shutdown();
        assertEquals(1, created, "the other three see the already-closed period (expected 0 now) and are refused");
        assertEquals(1, jdbc.queryForObject("select count(*) from cash_closings where business_id = ?", Integer.class, f.businessId));
        assertThrows(Exception.class, () -> jdbc.update("update cash_closings set counted_cash = 1 where business_id = ?", f.businessId));
        assertThrows(Exception.class, () -> jdbc.update("delete from cash_closings where business_id = ?", f.businessId));
    }

    @Test void permissionsAndTenantIsolation() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        UUID b = booking(f, "+77010012006", 10);
        money(f, b, "payments", "CASH", "2000");
        String staff = newUser("staffclose");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(staff, "/api/v1/me").text("email"), "role", "STAFF"), f.businessId);
        assertEquals(403, get(staff, "/api/v1/businesses/%s/finance/closing-preview", f.businessId).status());
        assertEquals(403, close(staff, f, 2000, 2000, null).status());
        String acc = newUser("accclose");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(acc, "/api/v1/me").text("email"), "role", "ACCOUNTANT"), f.businessId);
        assertEquals(201, close(acc, f, 2000, 2000, null).status(), "an accountant may close");
        assertEquals(404, get(other.ownerToken, "/api/v1/businesses/%s/finance/closings", f.businessId).status());
        assertEquals(0, get(other.ownerToken, "/api/v1/businesses/%s/finance/closings", other.businessId).body().size());
        assertEquals(401, get(null, "/api/v1/businesses/%s/finance/closings", f.businessId).status());
    }

    @Test void sinceIsOnlyAllowedBeforeTheFirstClosing() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = booking(f, "+77010012007", 10);
        money(f, b, "payments", "CASH", "1500");
        Res p = get(f.ownerToken, "/api/v1/businesses/%s/finance/closing-preview?since=%s", f.businessId, java.time.LocalDate.now().minusDays(3));
        assertEquals(200, p.status(), p.body().toString());
        assertEquals(0, new BigDecimal("1500").compareTo(dec(p, "cash", "net")));
        assertEquals(400, get(f.ownerToken, "/api/v1/businesses/%s/finance/closing-preview?since=%s", f.businessId, java.time.LocalDate.now().plusDays(2)).status());
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/finance/closings", Map.of("expectedCash", 1500, "countedCash", 1500, "since", java.time.LocalDate.now().minusDays(3).toString()), f.businessId).status());
        assertEquals(400, get(f.ownerToken, "/api/v1/businesses/%s/finance/closing-preview?since=%s", f.businessId, java.time.LocalDate.now().minusDays(3)).status(), "not after a closing exists");
    }
}
