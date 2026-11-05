package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class PublicBookingIT extends AbstractIT {
    private Map<String, Object> req(Fixture f, int h, int m, String phone) {
        return Map.of("branchId", f.branchId, "serviceId", f.serviceId, "startsAt", at(bookingDate(), h, m).toString(),
                "customer", Map.of("fullName", "Guest", "phone", phone));
    }

    @Test void unpublishedAndUnknownBusinessesAreIndistinguishable() {
        Fixture f = Fixture.create(this, 1, false);
        Res hidden = get(null, "/api/v1/public/businesses/%s", f.slug);
        Res unknown = get(null, "/api/v1/public/businesses/%s", "does-not-exist-xyz");
        assertEquals(404, hidden.status());
        assertEquals(404, unknown.status());
        assertEquals(hidden.text("code"), unknown.text("code"));
        assertEquals(hidden.text("message"), unknown.text("message"));
        assertEquals(404, post(null, "/api/v1/public/businesses/%s/bookings", req(f, 10, 0, "+77010001001"), f.slug).status());
    }

    @Test void publishRequiresBookableSetup() {
        String t = newUser("pub");
        String slug = unique("empty").toLowerCase();
        Res b = post(t, "/api/v1/businesses", Map.of("name", "Empty", "slug", slug, "businessType", "SPA"));
        assertEquals(409, post(t, "/api/v1/businesses/%s/publish", null, b.id()).status());
    }

    @Test void guestCanSeeProfileSlotsAndBookWithoutAccount() {
        Fixture f = Fixture.create(this, 1, true);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("depositPercent", 30), f.businessId);
        Res profile = get(null, "/api/v1/public/businesses/%s", f.slug);
        assertEquals(200, profile.status());
        assertEquals(1, profile.body().path("services").size());
        assertEquals(1, profile.body().path("employees").size());
        String txt = profile.body().toString();
        assertFalse(txt.contains("ownerToken") || txt.contains("email") || txt.contains("phone\":\"+7"), "profile must not leak private data");

        Res slots = get(null, "/api/v1/public/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s", f.slug, f.branchId, f.serviceId, bookingDate());
        assertEquals(200, slots.status());
        assertTrue(slots.body().size() > 0);

        Res booked = post(null, "/api/v1/public/businesses/%s/bookings", req(f, 10, 0, "+77010001002"), f.slug);
        assertEquals(201, booked.status(), booked.body().toString());
        assertEquals("AWAITING_PAYMENT", booked.text("status"));
        assertEquals(0, new java.math.BigDecimal("6000.00").compareTo(booked.body().path("depositAmount").decimalValue()));
        assertEquals(0, new java.math.BigDecimal("20000.00").compareTo(booked.body().path("remainingBalance").decimalValue()));
        assertFalse(booked.body().toString().contains("Guest"), "confirmation must not echo personal data");

        // slot no longer offered; staff sees the booking with the customer
        Res after = get(null, "/api/v1/public/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s", f.slug, f.branchId, f.serviceId, bookingDate());
        assertTrue(after.body().size() < slots.body().size());
        assertEquals("Guest", get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s", f.businessId, booked.text("bookingId")).text("customerName"));
    }

    @Test void publicInputIsValidated() {
        Fixture f = Fixture.create(this, 1, true);
        assertEquals(400, post(null, "/api/v1/public/businesses/%s/bookings", req(f, 10, 0, "87011234567"), f.slug).status());
        assertEquals(404, post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", java.util.UUID.randomUUID(), "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", Map.of("fullName", "G", "phone", "+77010001003")), f.slug).status());
    }

    @Test void onlineRulesMinNoticeAndMaxAdvanceApply() {
        Fixture f = Fixture.create(this, 1, true);
        // far beyond max advance (60 days by default): not offered, not bookable
        var far = java.time.LocalDate.now(ALMATY).plusDays(120);
        Res slots = get(null, "/api/v1/public/businesses/%s/availability?branchId=%s&serviceId=%s&date=%s", f.slug, f.branchId, f.serviceId, far);
        assertEquals(0, slots.body().size());
        assertEquals(409, post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(far, 10, 0).toString(), "customer", Map.of("fullName", "G", "phone", "+77010001004")), f.slug).status());
    }

    @Test void existingCustomerRecordIsNotOverwrittenByPublicInput() {
        Fixture f = Fixture.create(this, 1, true);
        post(f.ownerToken, "/api/v1/businesses/%s/customers", Map.of("fullName", "Real Name", "phone", "+77010001005", "notes", "VIP"), f.businessId);
        post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", Map.of("fullName", "Attacker", "phone", "+77010001005")), f.slug);
        Res list = get(f.ownerToken, "/api/v1/businesses/%s/customers?q=1005", f.businessId);
        assertEquals("Real Name", list.body().path("items").get(0).path("fullName").asText());
    }
}
