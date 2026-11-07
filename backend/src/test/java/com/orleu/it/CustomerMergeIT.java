package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CustomerMergeIT extends AbstractIT {
    private UUID customer(Fixture f, String phone, Map<String, Object> extra) {
        var body = new java.util.HashMap<String, Object>(Map.of("fullName", "Dup", "phone", phone));
        body.putAll(extra);
        Res r = post(f.ownerToken, "/api/v1/businesses/%s/customers", body, f.businessId);
        assertEquals(201, r.status(), r.body().toString());
        return r.id();
    }

    private void book(Fixture f, String phone, int hour) {
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Dup", "phone", phone)), f.businessId).status());
    }

    private Res merge(String token, UUID biz, UUID target, UUID source) {
        return call(MockMvcRequestBuilders.post("/api/v1/businesses/" + biz + "/customers/" + target + "/merge"), token, Map.of("sourceId", source.toString()));
    }

    private void tag(Fixture f, UUID id, String... tags) {
        assertEquals(200, call(MockMvcRequestBuilders.put("/api/v1/businesses/" + f.businessId + "/customers/" + id + "/tags"), f.ownerToken, Map.of("tags", List.of(tags))).status());
    }

    @Test void mergeMovesBookingsAndTagsAndKeepsTargetIdentityAndConsent() {
        Fixture f = Fixture.create(this, 1, false);
        UUID target = customer(f, "+77010008001", Map.of("notes", "keep"));
        UUID source = customer(f, "+77010008002", Map.of("email", "dup@example.com", "notes", "extra", "marketingOptIn", true));
        book(f, "+77010008001", 10);
        book(f, "+77010008002", 11);
        tag(f, target, "vip");
        tag(f, source, "vip", "allergy");

        Res r = merge(f.ownerToken, f.businessId, target, source);
        assertEquals(200, r.status(), r.body().toString());
        assertEquals("+77010008001", r.body().path("phone").asText());
        assertEquals("dup@example.com", r.body().path("email").asText());       // filled from the duplicate
        assertEquals("keep\n\nextra", r.body().path("notes").asText());
        assertFalse(r.body().path("marketingOptIn").asBoolean());               // consent of the removed record does not transfer
        assertEquals(2, r.body().path("tags").size());
        assertEquals(2, jdbc.queryForObject("select count(*) from bookings where customer_id = ?", Integer.class, target));
        assertEquals(0, jdbc.queryForObject("select count(*) from customers where id = ?", Integer.class, source));
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where action = 'CUSTOMER_MERGED' and business_id = ?", Integer.class, f.businessId));
    }

    @Test void blockIsKeptAndInvalidMergesAreRejected() {
        Fixture f = Fixture.create(this, 1, false);
        UUID target = customer(f, "+77010008003", Map.of()), source = customer(f, "+77010008004", Map.of());
        assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/customers/%s/block", Map.of(), f.businessId, source).status());
        assertEquals(400, merge(f.ownerToken, f.businessId, target, target).status());
        assertEquals(404, merge(f.ownerToken, f.businessId, target, UUID.randomUUID()).status());
        assertEquals(200, merge(f.ownerToken, f.businessId, target, source).status());
        assertTrue(get(f.ownerToken, "/api/v1/businesses/%s/customers/%s", f.businessId, target).body().path("blocked").asBoolean());
    }

    @Test void anonymisedAndForeignCustomersCannotBeMerged() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        UUID a = customer(f, "+77010008005", Map.of()), b = customer(f, "+77010008006", Map.of()), foreign = customer(other, "+77010008007", Map.of());
        assertEquals(404, merge(f.ownerToken, f.businessId, a, foreign).status());   // never reaches another tenant's record
        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/customers/%s/anonymize", Map.of(), f.businessId, b).status());
        assertEquals(409, merge(f.ownerToken, f.businessId, a, b).status());
        assertEquals(1, jdbc.queryForObject("select count(*) from customers where id = ?", Integer.class, foreign));
    }
}
