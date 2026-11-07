package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

class GiftCardIT extends AbstractIT {
    private Res sell(String token, Fixture f, Object amount, String method, String key) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/gift-cards"), token, Map.of("amount", amount, "method", method, "buyerName", "Buyer"), "Idempotency-Key", key);
    }

    private Res redeem(String token, Fixture f, UUID booking, String code, Object amount, String key) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + booking + "/gift-card-payments"), token, Map.of("code", code, "amount", amount), "Idempotency-Key", key);
    }

    private UUID booking(Fixture f, String phone, int hour) {
        Res b = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Gift Customer", "phone", phone)), f.businessId);
        assertEquals(201, b.status(), b.body().toString());
        return b.id();
    }

    private BigDecimal balance(String code, Fixture f) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/gift-cards/lookup"), f.ownerToken, Map.of("code", code)).body().path("balance").decimalValue();
    }

    @Test void theCodeIsShownOnceStoredOnlyAsAHashAndAReplayNeverCreatesASecondCard() {
        Fixture f = Fixture.create(this, 1, false);
        Res s = sell(f.ownerToken, f, 15000, "CASH", "sale-1");
        assertEquals(201, s.status(), s.body().toString());
        String code = s.body().path("code").asText();
        assertTrue(code.matches("[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}"), code);
        assertTrue(s.body().path("codeShown").asBoolean());
        assertEquals(code.replace("-", "").substring(8), s.body().path("card").path("codeLast4").asText());
        assertEquals(0, jdbc.queryForObject("select count(*) from gift_cards where business_id = ? and code_hash = ?", Integer.class, f.businessId, code), "the plain code is not stored");
        assertEquals(0, jdbc.queryForObject("select count(*) from gift_cards where business_id = ? and code_hash like '%' || ? || '%'", Integer.class, f.businessId, code.replace("-", "")));

        Res replay = sell(f.ownerToken, f, 15000, "CASH", "sale-1");
        assertEquals(201, replay.status());
        assertFalse(replay.body().path("codeShown").asBoolean());
        assertTrue(replay.body().path("code").isNull() || replay.body().path("code").isMissingNode());
        assertEquals(1, jdbc.queryForObject("select count(*) from gift_cards where business_id = ?", Integer.class, f.businessId));
        assertEquals(409, sell(f.ownerToken, f, 9999, "CASH", "sale-1").status(), "same key, different amount");
        // lookup works with lower case and spaces
        assertEquals(0, new BigDecimal("15000").compareTo(balance(code.toLowerCase().replace("-", " "), f)));
        assertEquals(1, get(f.ownerToken, "/api/v1/businesses/%s/gift-cards", f.businessId).body().size());
    }

    @Test void redeemingPaysTheBookingThroughTheLedgerAndNeverOverspendsTheCard() {
        Fixture f = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 8000, "CARD_MANUAL", "sale-2").body().path("code").asText();
        UUID b = booking(f, "+77010014001", 10);

        Res r = redeem(f.ownerToken, f, b, code, 5000, "red-1");
        assertEquals(201, r.status(), r.body().toString());
        assertEquals(0, new BigDecimal("5000").compareTo(r.body().path("financials").path("netPaid").decimalValue()));
        assertEquals(0, new BigDecimal("3000").compareTo(balance(code, f)));
        assertEquals("GIFT_CARD", jdbc.queryForObject("select method from ledger_entries where booking_id = ?", String.class, b));
        // idempotent replay: same key, same booking and amount -> same result, nothing spent twice
        assertEquals(201, redeem(f.ownerToken, f, b, code, 5000, "red-1").status());
        assertEquals(0, new BigDecimal("3000").compareTo(balance(code, f)));
        assertEquals(409, redeem(f.ownerToken, f, b, code, 4000, "red-1").status());

        Res over = redeem(f.ownerToken, f, b, code, 3001, "red-2");
        assertEquals(409, over.status());
        assertEquals("GIFT_CARD_INSUFFICIENT", over.body().path("code").asText());
        assertEquals(0, new BigDecimal("3000").compareTo(balance(code, f)), "a refused redemption spends nothing");
        // the exact remaining balance can be spent, leaving zero
        assertEquals(201, redeem(f.ownerToken, f, b, code, 3000, "red-3").status());
        assertEquals(0, BigDecimal.ZERO.compareTo(balance(code, f)));
    }

    @Test void payingMoreThanTheBookingOwesIsRefusedAndTheCardIsUntouched() {
        Fixture f = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 1000000, "CASH", "sale-big").body().path("code").asText();
        UUID b = booking(f, "+77010014009", 10);
        Res over = redeem(f.ownerToken, f, b, code, 999999, "ov-1");
        assertEquals(409, over.status());
        assertEquals("OVERPAYMENT", over.body().path("code").asText());
        assertEquals(0, new BigDecimal("1000000").compareTo(balance(code, f)), "the deduction was rolled back with the failed payment");
        assertEquals(0, jdbc.queryForObject("select count(*) from gift_card_redemptions where business_id = ?", Integer.class, f.businessId));
    }

    @Test void giftCardValueIsNeverPaidOutAsCashRefund() {
        Fixture f = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 8000, "CASH", "sale-3").body().path("code").asText();
        UUID b = booking(f, "+77010014002", 10);
        assertEquals(201, redeem(f.ownerToken, f, b, code, 8000, "red-4").status());
        Res ref = call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/refunds"), f.ownerToken, Map.of("amount", "1000", "method", "CASH"), "Idempotency-Key", "ref-1");
        assertEquals(409, ref.status(), "gift card money cannot be cashed out");
        assertEquals("REFUND_EXCEEDS_PAID", ref.body().path("code").asText());
        // cash paid on top of the gift card remains refundable
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/payments"), f.ownerToken, Map.of("amount", "2000", "method", "CASH"), "Idempotency-Key", "pay-1").status());
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/refunds"), f.ownerToken, Map.of("amount", "2000", "method", "CASH"), "Idempotency-Key", "ref-2").status());
        assertEquals(409, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/refunds"), f.ownerToken, Map.of("amount", "1", "method", "CASH"), "Idempotency-Key", "ref-3").status());
        // the regular payment endpoint cannot be used to fake a gift card payment
        assertEquals(400, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/payments"), f.ownerToken, Map.of("amount", "1", "method", "GIFT_CARD"), "Idempotency-Key", "pay-2").status());
    }

    @Test void concurrentRedemptionsCannotOverspendOneCard() throws Exception {
        Fixture f = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 10000, "CASH", "sale-4").body().path("code").asText();
        UUID[] bookings = new UUID[5];
        for (int i = 0; i < 5; i++) bookings[i] = booking(f, "+7701001410" + i, 10 + i);
        ExecutorService pool = Executors.newFixedThreadPool(5);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        var futures = new java.util.ArrayList<Future<?>>();
        for (int i = 0; i < 5; i++) { final int n = i; futures.add(pool.submit(() -> { go.await(); if (redeem(f.ownerToken, f, bookings[n], code, 4000, "cc-" + n).status() == 201) ok.incrementAndGet(); return null; })); }
        go.countDown();
        for (var fu : futures) fu.get(30, TimeUnit.SECONDS);
        pool.shutdown();
        assertEquals(2, ok.get(), "10000 pays for two redemptions of 4000, never three");
        assertEquals(0, new BigDecimal("2000").compareTo(balance(code, f)));
        assertEquals(0, new BigDecimal("8000").compareTo(jdbc.queryForObject("select coalesce(sum(amount),0) from gift_card_redemptions where business_id = ?", BigDecimal.class, f.businessId)));
        assertThrows(Exception.class, () -> jdbc.update("update gift_card_redemptions set amount = 1 where business_id = ?", f.businessId));
    }

    @Test void voidedAndExpiredCardsCannotBeUsedAndOnlyOwnersVoid() {
        Fixture f = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 5000, "CASH", "sale-5").body().path("code").asText();
        UUID id = UUID.fromString(get(f.ownerToken, "/api/v1/businesses/%s/gift-cards", f.businessId).body().get(0).path("id").asText());
        UUID b = booking(f, "+77010014003", 10);
        String recep = newUser("recepgc");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(recep, "/api/v1/me").text("email"), "role", "RECEPTIONIST"), f.businessId);
        assertEquals(403, post(recep, "/api/v1/businesses/%s/gift-cards/%s/void", Map.of(), f.businessId, id).status());
        assertEquals(201, redeem(recep, f, b, code, 1000, "v-1").status(), "a receptionist may redeem");
        assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/gift-cards/%s/void", Map.of(), f.businessId, id).status());
        Res r = redeem(f.ownerToken, f, b, code, 1000, "v-2");
        assertEquals(409, r.status());
        assertEquals("GIFT_CARD_INVALID", r.body().path("code").asText());

        String code2 = sell(f.ownerToken, f, 5000, "CASH", "sale-6").body().path("code").asText();
        jdbc.update("update gift_cards set expires_on = current_date - 5 where business_id = ? and code_last4 = ?", f.businessId, code2.replace("-", "").substring(8));
        assertEquals("GIFT_CARD_INVALID", redeem(f.ownerToken, f, b, code2, 1000, "v-3").body().path("code").asText(), "expired");
        assertEquals(409, redeem(f.ownerToken, f, b, "AAAA-AAAA-AAAA", 1000, "v-4").status(), "an unknown code gives the same generic answer");
        assertEquals(400, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/gift-cards"), f.ownerToken, Map.of("amount", 100, "method", "CASH", "expiresOn", "2001-01-01"), "Idempotency-Key", "sale-8").status());
    }

    @Test void saleMoneyIsInTheCashRegisterButARedemptionIsNot() {
        Fixture f = Fixture.create(this, 1, false);
        UUID b = booking(f, "+77010014004", 10);
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/payments"), f.ownerToken, Map.of("amount", "2000", "method", "CASH"), "Idempotency-Key", "p-1").status());
        String code = sell(f.ownerToken, f, 7000, "CASH", "sale-9").body().path("code").asText();
        sell(f.ownerToken, f, 3000, "BANK_TRANSFER", "sale-10");
        assertEquals(201, redeem(f.ownerToken, f, b, code, 4000, "r-1").status());
        Res p = get(f.ownerToken, "/api/v1/businesses/%s/finance/closing-preview", f.businessId);
        assertEquals(0, new BigDecimal("9000").compareTo(p.body().path("cash").path("net").decimalValue()), "2000 booking cash + 7000 gift card sold for cash; the 4000 redemption is not cash");
        assertEquals(0, new BigDecimal("3000").compareTo(p.body().path("bank").path("net").decimalValue()));
    }

    @Test void tenantIsolationAndPermissions() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 5000, "CASH", "sale-11").body().path("code").asText();
        UUID bOther = booking(other, "+77010014005", 10);
        assertEquals(409, redeem(other.ownerToken, other, bOther, code, 1000, "x-1").status(), "a card of another business is just an unknown code");
        assertEquals(404, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + other.businessId + "/gift-cards/lookup"), other.ownerToken, Map.of("code", code)).status());
        assertEquals(404, get(other.ownerToken, "/api/v1/businesses/%s/gift-cards", f.businessId).status());
        String staff = newUser("staffgc");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(staff, "/api/v1/me").text("email"), "role", "STAFF"), f.businessId);
        assertEquals(403, sell(staff, f, 100, "CASH", "s-1").status());
        assertEquals(403, get(staff, "/api/v1/businesses/%s/gift-cards", f.businessId).status());
        assertEquals(401, get(null, "/api/v1/businesses/%s/gift-cards", f.businessId).status());
    }

    private Res restore(Fixture f, UUID booking, Object amount, String key) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + booking + "/gift-card-refunds"), f.ownerToken, Map.of("amount", amount), "Idempotency-Key", key);
    }

    private BigDecimal restorable(Fixture f, UUID booking) {
        return get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/gift-card-restorable", f.businessId, booking).body().path("total").decimalValue();
    }

    @Test void valuePaidWithAGiftCardGoesBackToTheCardNotOutAsCash() {
        Fixture f = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 8000, "CASH", "sale-r1").body().path("code").asText();
        UUID b = booking(f, "+77010015001", 10);
        assertEquals(201, redeem(f.ownerToken, f, b, code, 5000, "rr-1").status());
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/payments"), f.ownerToken, Map.of("amount", "1000", "method", "CASH"), "Idempotency-Key", "rp-1").status());
        assertEquals(0, new BigDecimal("5000").compareTo(restorable(f, b)));
        assertEquals(0, new BigDecimal("3000").compareTo(balance(code, f)));

        Res r = restore(f, b, 3000, "rs-1");
        assertEquals(201, r.status(), r.body().toString());
        assertEquals(0, new BigDecimal("6000").compareTo(balance(code, f)), "3000 left + 3000 returned");
        assertEquals(0, new BigDecimal("3000").compareTo(r.body().path("financials").path("netPaid").decimalValue()), "5000 gift + 1000 cash - 3000 returned");
        assertEquals("GIFT_CARD", jdbc.queryForObject("select method from ledger_entries where booking_id = ? and entry_type = 'REFUND'", String.class, b));
        // replay: same key, same amount, nothing returned twice
        assertEquals(201, restore(f, b, 3000, "rs-1").status());
        assertEquals(0, new BigDecimal("6000").compareTo(balance(code, f)));
        assertEquals(409, restore(f, b, 2500, "rs-1").status(), "same key, different amount");

        assertEquals(0, new BigDecimal("2000").compareTo(restorable(f, b)));
        assertEquals("GIFT_CARD_NOTHING_TO_RESTORE", restore(f, b, 2001, "rs-2").body().path("code").asText());
        assertEquals(0, new BigDecimal("6000").compareTo(balance(code, f)), "a refused restore changes nothing");
        assertEquals(201, restore(f, b, 2000, "rs-3").status());
        assertEquals(0, new BigDecimal("8000").compareTo(balance(code, f)), "back to the original value, never more");
        assertEquals(409, restore(f, b, 1, "rs-4").status());
        // the cash part is still refundable in cash, and returning gift-card value did not eat into it
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/refunds"), f.ownerToken, Map.of("amount", "1000", "method", "CASH"), "Idempotency-Key", "rc-1").status());
        assertEquals(409, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/refunds"), f.ownerToken, Map.of("amount", "1", "method", "CASH"), "Idempotency-Key", "rc-2").status());
        assertThrows(Exception.class, () -> jdbc.update("update gift_card_restorations set amount = 1 where business_id = ?", f.businessId));
    }

    @Test void restoringGoesToTheNewestCardFirstAndVoidCardsAreExcluded() {
        Fixture f = Fixture.create(this, 1, false);
        String older = sell(f.ownerToken, f, 3000, "CASH", "sale-r2").body().path("code").asText();
        String newer = sell(f.ownerToken, f, 3000, "CASH", "sale-r3").body().path("code").asText();
        UUID b = booking(f, "+77010015002", 10);
        assertEquals(201, redeem(f.ownerToken, f, b, older, 3000, "rr-2").status());
        assertEquals(201, redeem(f.ownerToken, f, b, newer, 2000, "rr-3").status());
        assertEquals(201, restore(f, b, 2500, "rs-5").status());
        assertEquals(0, new BigDecimal("3000").compareTo(balance(newer, f)), "newer card got its 2000 back and is full again");
        assertEquals(0, new BigDecimal("500").compareTo(balance(older, f)), "the older card got the remaining 500");
        // void the older card: its remaining 2500 can no longer be returned
        UUID olderId = UUID.fromString(get(f.ownerToken, "/api/v1/businesses/%s/gift-cards", f.businessId).body().get(1).path("id").asText());
        assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/gift-cards/%s/void", Map.of(), f.businessId, olderId).status());
        assertEquals(0, BigDecimal.ZERO.compareTo(restorable(f, b)));
        assertEquals(409, restore(f, b, 100, "rs-6").status());
    }

    @Test void restorePermissionsAndIsolation() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        String code = sell(f.ownerToken, f, 4000, "CASH", "sale-r4").body().path("code").asText();
        UUID b = booking(f, "+77010015003", 10);
        assertEquals(201, redeem(f.ownerToken, f, b, code, 4000, "rr-4").status());
        String staff = newUser("staffrs");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(staff, "/api/v1/me").text("email"), "role", "STAFF"), f.businessId);
        assertEquals(403, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b + "/gift-card-refunds"), staff, Map.of("amount", 100), "Idempotency-Key", "x").status());
        assertEquals(404, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + other.businessId + "/bookings/" + b + "/gift-card-refunds"), other.ownerToken, Map.of("amount", 100), "Idempotency-Key", "x").status());
        assertEquals(404, get(other.ownerToken, "/api/v1/businesses/%s/bookings/%s/gift-card-restorable", other.businessId, b).status());
        assertEquals(400, restore(f, b, 0, "rs-z").status());
    }
}
