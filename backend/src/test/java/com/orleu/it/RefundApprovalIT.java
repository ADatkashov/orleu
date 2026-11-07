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

class RefundApprovalIT extends AbstractIT {
    private UUID paidBooking(Fixture f, String phone, String paid) {
        Res b = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", Map.of("fullName", "Refund Customer", "phone", phone)), f.businessId);
        assertEquals(201, b.status(), b.body().toString());
        Res p = call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b.id() + "/payments"), f.ownerToken,
                Map.of("amount", paid, "method", "CASH"), "Idempotency-Key", "pay-" + UUID.randomUUID());
        assertEquals(201, p.status(), p.body().toString());
        return b.id();
    }

    private Res refund(String token, Fixture f, UUID booking, String amount, String key) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + booking + "/refunds"), token,
                Map.of("amount", amount, "method", "CASH"), "Idempotency-Key", key);
    }

    private Res decide(String token, Fixture f, UUID request, String action) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/refund-requests/" + request + "/" + action), token, Map.of());
    }

    private String receptionist(Fixture f) {
        String recep = newUser("recepref");
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(recep, "/api/v1/me").text("email"), "role", "RECEPTIONIST"), f.businessId).status());
        return recep;
    }

    private void policy(Fixture f, Object threshold) {
        var body = new java.util.HashMap<String, Object>();
        body.put("threshold", threshold);
        assertEquals(200, put(f.ownerToken, "/api/v1/businesses/%s/refund-policy", body, f.businessId).status());
    }

    private BigDecimal netPaid(Fixture f, UUID booking) {
        return jdbc.queryForObject("select coalesce(sum(case when entry_type = 'PAYMENT' then amount else -amount end), 0) from ledger_entries where booking_id = ?", BigDecimal.class, booking);
    }

    @Test void withoutAPolicyEveryRefundIsRecordedImmediatelyAsBefore() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = paidBooking(f, "+77010011001", "10000");
        String recep = receptionist(f);
        assertEquals(201, refund(recep, f, b, "9000", "r1").status());
        assertEquals(0, new BigDecimal("1000").compareTo(netPaid(f, b)));
    }

    @Test void aLargeRefundByAReceptionistWaitsForAnApproverAndTheLedgerStaysUntouched() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = paidBooking(f, "+77010011002", "10000");
        String recep = receptionist(f);
        policy(f, 3000);

        assertEquals(201, refund(recep, f, b, "3000", "small").status(), "at the threshold is allowed");
        Res big = refund(recep, f, b, "5000", "big");
        assertEquals(202, big.status(), big.body().toString());
        assertEquals("PENDING", big.body().path("status").asText());
        assertEquals(0, new BigDecimal("7000").compareTo(netPaid(f, b)), "nothing refunded yet beyond the small one");
        UUID req = UUID.fromString(big.body().path("id").asText());

        // idempotent: same key and amount returns the same request, a different amount is refused
        assertEquals(req.toString(), refund(recep, f, b, "5000", "big").body().path("id").asText());
        assertEquals(409, refund(recep, f, b, "6000", "big").status());

        // a receptionist cannot decide
        assertEquals(403, decide(recep, f, req, "approve").status());
        assertEquals(1, get(f.ownerToken, "/api/v1/businesses/%s/refund-requests?status=PENDING", f.businessId).body().size());

        Res ok = decide(f.ownerToken, f, req, "approve");
        assertEquals(200, ok.status(), ok.body().toString());
        assertEquals("APPROVED", ok.body().path("status").asText());
        assertEquals(0, new BigDecimal("2000").compareTo(netPaid(f, b)), "ledger now holds the approved refund");
        assertEquals(409, decide(f.ownerToken, f, req, "approve").status(), "a decided request cannot be decided again");
        assertEquals(0, new BigDecimal("2000").compareTo(netPaid(f, b)), "and nothing was refunded twice");
        assertEquals(0, get(f.ownerToken, "/api/v1/businesses/%s/refund-requests?status=PENDING", f.businessId).body().size());
    }

    @Test void rejectionRecordsNoMoneyAndOwnersAreNeverHeldBack() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = paidBooking(f, "+77010011003", "10000");
        String recep = receptionist(f);
        policy(f, 1000);
        UUID req = UUID.fromString(refund(recep, f, b, "4000", "rj1").body().path("id").asText());
        Res rej = call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/refund-requests/" + req + "/reject"), f.ownerToken, Map.of("note", "customer agreed to a voucher"));
        assertEquals(200, rej.status(), rej.body().toString());
        assertEquals("REJECTED", rej.body().path("status").asText());
        assertEquals("customer agreed to a voucher", rej.body().path("decisionNote").asText());
        assertEquals(0, new BigDecimal("10000").compareTo(netPaid(f, b)));
        assertEquals(409, decide(f.ownerToken, f, req, "approve").status());
        assertEquals(201, refund(f.ownerToken, f, b, "4000", "owner-direct").status(), "the owner holds REFUND_APPROVE: no second pair of eyes needed");
    }

    @Test void approvalRevalidatesAgainstWhatIsPaidAtThatMoment() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = paidBooking(f, "+77010011004", "10000");
        String recep = receptionist(f);
        policy(f, 1000);
        UUID req = UUID.fromString(refund(recep, f, b, "8000", "rv1").body().path("id").asText());
        assertEquals(201, refund(f.ownerToken, f, b, "5000", "owner-first").status()); // paid drops to 5000 while the request waits
        Res ok = decide(f.ownerToken, f, req, "approve");
        assertEquals(409, ok.status(), "8000 can no longer be refunded");
        assertEquals("REFUND_EXCEEDS_PAID", ok.body().path("code").asText());
        assertEquals("PENDING", get(f.ownerToken, "/api/v1/businesses/%s/refund-requests", f.businessId).body().get(0).path("status").asText(), "still pending, nothing lost");
    }

    @Test void concurrentApprovalsRefundExactlyOnce() throws Exception {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = paidBooking(f, "+77010011005", "10000");
        String recep = receptionist(f);
        policy(f, 1000);
        UUID req = UUID.fromString(refund(recep, f, b, "6000", "cc1").body().path("id").asText());
        ExecutorService pool = Executors.newFixedThreadPool(4);
        CountDownLatch go = new CountDownLatch(1);
        var futures = new java.util.ArrayList<Future<Integer>>();
        for (int i = 0; i < 4; i++) futures.add(pool.submit(() -> { go.await(); return decide(f.ownerToken, f, req, "approve").status(); }));
        go.countDown();
        int ok = 0;
        for (var fu : futures) if (fu.get(30, TimeUnit.SECONDS) == 200) ok++;
        pool.shutdown();
        assertEquals(1, ok);
        assertEquals(0, new BigDecimal("4000").compareTo(netPaid(f, b)));
    }

    @Test void policyValidationPermissionsAndTenantIsolation() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        UUID b = paidBooking(f, "+77010011006", "10000");
        String recep = receptionist(f);
        assertEquals(400, put(f.ownerToken, "/api/v1/businesses/%s/refund-policy", Map.of("threshold", -1), f.businessId).status());
        assertEquals(403, put(recep, "/api/v1/businesses/%s/refund-policy", Map.of("threshold", 100), f.businessId).status(), "only business managers set the policy");
        assertEquals(200, get(recep, "/api/v1/businesses/%s/refund-policy", f.businessId).status());
        policy(f, 1000);
        UUID req = UUID.fromString(refund(recep, f, b, "4000", "iso1").body().path("id").asText());
        assertEquals(404, decide(other.ownerToken, f, req, "approve").status(), "another business's owner cannot even see the business");
        assertEquals(404, decide(other.ownerToken, other, req, "approve").status(), "nor reach the request through their own business");
        assertEquals(0, get(other.ownerToken, "/api/v1/businesses/%s/refund-requests", other.businessId).body().size());
        policy(f, null);
        var t = get(f.ownerToken, "/api/v1/businesses/%s/refund-policy", f.businessId).body().path("threshold");
        assertTrue(t.isNull() || t.isMissingNode(), "approval is off again: " + t);
    }
}
