package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class PromoCodesIT extends AbstractIT {
    private static BigDecimal d(String s) { return new BigDecimal(s); }

    private Map<String, Object> req(Fixture f, int h, String phone, String promo) {
        var m = new java.util.HashMap<String, Object>(Map.of("branchId", f.branchId, "serviceId", f.serviceId, "startsAt", at(bookingDate(), h, 0).toString(),
                "customer", Map.of("fullName", "Guest", "phone", phone)));
        if (promo != null) m.put("promoCode", promo);
        return m;
    }

    private Res promo(Fixture f, Map<String, Object> body) { return post(f.ownerToken, "/api/v1/businesses/%s/promo-codes", body, f.businessId); }

    @Test void percentDiscountReducesPriceAndTheDepositIsComputedOnTheDiscountedPrice() {
        Fixture f = Fixture.create(this, 1, true);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("depositPercent", 30), f.businessId);
        assertEquals(201, promo(f, Map.of("code", "summer15", "kind", "PERCENT", "value", "15")).status());

        Res preview = get(null, "/api/v1/public/businesses/%s/promo-check?serviceId=%s&code=Summer15", f.slug, f.serviceId); // case-insensitive
        assertEquals(200, preview.status());
        assertEquals(0, d("3000.00").compareTo(preview.body().path("discount").decimalValue()));
        assertEquals(0, d("17000.00").compareTo(preview.body().path("price").decimalValue()));
        assertEquals(0, d("5100.00").compareTo(preview.body().path("depositAmount").decimalValue()));

        Res booked = post(null, "/api/v1/public/businesses/%s/bookings", req(f, 10, "+77020001001", "SUMMER15"), f.slug);
        assertEquals(201, booked.status(), booked.body().toString());
        assertEquals(0, d("17000.00").compareTo(booked.body().path("price").decimalValue()));
        assertEquals(0, d("5100.00").compareTo(booked.body().path("depositAmount").decimalValue()));
        Res view = get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s", f.businessId, booked.text("bookingId"));
        assertEquals(0, d("3000.00").compareTo(view.body().path("financials").path("discount").decimalValue()));
        assertEquals(0, d("17000.00").compareTo(view.body().path("financials").path("price").decimalValue()));
        assertEquals(1, get(f.ownerToken, "/api/v1/businesses/%s/promo-codes", f.businessId).body().get(0).path("usedCount").asInt());
    }

    @Test void fixedDiscountIsCappedAtThePriceAndRoundingIsHalfUp() {
        Fixture f = Fixture.create(this, 1, true);
        promo(f, Map.of("code", "HUGE", "kind", "FIXED", "value", "50000"));
        Res p = get(null, "/api/v1/public/businesses/%s/promo-check?serviceId=%s&code=HUGE", f.slug, f.serviceId);
        assertEquals(0, d("20000.00").compareTo(p.body().path("discount").decimalValue()));
        assertEquals(0, d("0.00").compareTo(p.body().path("price").decimalValue()));
        Res booked = post(null, "/api/v1/public/businesses/%s/bookings", req(f, 10, "+77020001002", "HUGE"), f.slug);
        assertEquals(201, booked.status());
        assertEquals("CONFIRMED", booked.text("status"), "a free booking needs no deposit hold and auto-confirms");
        promo(f, Map.of("code", "ODD", "kind", "PERCENT", "value", "33.33"));
        // 20000 * 33.33% = 6666.00
        assertEquals(0, d("6666.00").compareTo(get(null, "/api/v1/public/businesses/%s/promo-check?serviceId=%s&code=ODD", f.slug, f.serviceId).body().path("discount").decimalValue()));
    }

    @Test void invalidExpiredDisabledAndWrongServiceCodesAreRejectedWithoutBookingAnything() {
        Fixture f = Fixture.create(this, 1, true);
        var other = post(f.ownerToken, "/api/v1/businesses/%s/services", Map.of("name", "Other", "durationMinutes", 30, "price", "5000"), f.businessId);
        promo(f, Map.of("code", "OLD", "kind", "FIXED", "value", "1000", "validUntil", java.time.LocalDate.now(ALMATY).minusDays(1).toString()));
        promo(f, Map.of("code", "FUTURE", "kind", "FIXED", "value", "1000", "validFrom", java.time.LocalDate.now(ALMATY).plusDays(1).toString()));
        promo(f, Map.of("code", "ONLYOTHER", "kind", "FIXED", "value", "1000", "serviceId", other.id().toString()));
        Res off = promo(f, Map.of("code", "OFF", "kind", "FIXED", "value", "1000"));
        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/promo-codes/%s", Map.of("active", false), f.businessId, off.id()).status());
        for (String code : new String[]{"NOPE", "OLD", "FUTURE", "ONLYOTHER", "OFF"}) {
            Res r = post(null, "/api/v1/public/businesses/%s/bookings", req(f, 10, "+77020001003", code), f.slug);
            assertEquals(400, r.status(), code);
            assertEquals("PROMO_INVALID", r.text("code"), code);
        }
        assertEquals(0, get(f.ownerToken, "/api/v1/businesses/%s/bookings?from=%s&to=%s", f.businessId, at(bookingDate(), 0, 0), at(bookingDate().plusDays(1), 0, 0)).body().size());
    }

    @Test void maxUsesIsEnforcedAtomicallyUnderConcurrency() throws Exception {
        Fixture f = Fixture.create(this, 3, true);
        promo(f, Map.of("code", "LAST1", "kind", "FIXED", "value", "1000", "maxUses", 1));
        var pool = java.util.concurrent.Executors.newFixedThreadPool(3);
        var futures = new java.util.ArrayList<java.util.concurrent.Future<Integer>>();
        for (int i = 0; i < 3; i++) {
            final int n = i;
            futures.add(pool.submit(() -> post(null, "/api/v1/public/businesses/%s/bookings", req(f, 10, "+7702000200" + n, "LAST1"), f.slug).status()));
        }
        int created = 0;
        for (var fu : futures) if (fu.get() == 201) created++;
        pool.shutdown();
        assertEquals(1, created, "exactly maxUses bookings may succeed");
        assertEquals(1, get(f.ownerToken, "/api/v1/businesses/%s/promo-codes", f.businessId).body().get(0).path("usedCount").asInt());
    }

    @Test void staffCanApplyCodesAndManagementIsPermissionedAndTenantScoped() {
        Fixture f = Fixture.create(this, 1, true);
        Fixture other = Fixture.create(this, 1, true);
        promo(f, Map.of("code", "STAFF10", "kind", "PERCENT", "value", "10"));
        Res b = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "startsAt", at(bookingDate(), 11, 0).toString(),
                "customer", Map.of("fullName", "Walk-in", "phone", "+77020003001"), "promoCode", "staff10"), f.businessId);
        assertEquals(201, b.status(), b.body().toString());
        assertEquals(0, d("18000.00").compareTo(b.body().path("financials").path("price").decimalValue()));
        // another tenant can neither use nor see the code
        assertEquals(400, post(null, "/api/v1/public/businesses/%s/bookings", req(other, 10, "+77020003002", "STAFF10"), other.slug).status());
        assertEquals(404, get(other.ownerToken, "/api/v1/businesses/%s/promo-codes", f.businessId).status());
        // validation + uniqueness
        assertEquals(409, promo(f, Map.of("code", "staff10", "kind", "FIXED", "value", "1")).status());
        assertEquals(400, promo(f, Map.of("code", "x", "kind", "FIXED", "value", "1")).status());
        assertEquals(400, promo(f, Map.of("code", "OVER", "kind", "PERCENT", "value", "101")).status());
        assertEquals(400, promo(f, Map.of("code", "NEG", "kind", "FIXED", "value", "-5")).status());
    }
}
