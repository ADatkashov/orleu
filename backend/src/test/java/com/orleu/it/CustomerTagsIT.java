package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CustomerTagsIT extends AbstractIT {
    private UUID customer(Fixture f, String phone) {
        Res r = post(f.ownerToken, "/api/v1/businesses/%s/customers", Map.of("fullName", "Tag Tester", "phone", phone), f.businessId);
        assertEquals(201, r.status(), r.body().toString());
        return r.id();
    }

    private Res put(String token, UUID biz, UUID id, List<String> tags) {
        return call(MockMvcRequestBuilders.put("/api/v1/businesses/" + biz + "/customers/" + id + "/tags"), token, Map.of("tags", tags));
    }

    @Test void tagsAreNormalisedFilteredAndCounted() {
        Fixture f = Fixture.create(this, 1, false);
        UUID a = customer(f, "+77010007001"), b = customer(f, "+77010007002");
        Res r = put(f.ownerToken, f.businessId, a, List.of(" VIP ", "vip", "Allergy"));
        assertEquals(200, r.status(), r.body().toString());
        assertEquals(List.of("allergy", "vip"), List.of(r.body().path("tags").get(0).asText(), r.body().path("tags").get(1).asText()));
        assertEquals(200, put(f.ownerToken, f.businessId, b, List.of("vip")).status());

        Res vip = get(f.ownerToken, "/api/v1/businesses/%s/customers?tag=VIP", f.businessId);
        assertEquals(2, vip.body().path("total").asInt());
        Res allergy = get(f.ownerToken, "/api/v1/businesses/%s/customers?tag=allergy", f.businessId);
        assertEquals(1, allergy.body().path("total").asInt());
        assertEquals(2, allergy.body().path("items").get(0).path("tags").size());

        Res counts = get(f.ownerToken, "/api/v1/businesses/%s/customers/tags", f.businessId);
        assertEquals("vip", counts.body().get(0).path("tag").asText());
        assertEquals(2, counts.body().get(0).path("customers").asInt());

        // replace: removes tags no longer listed
        assertEquals(200, put(f.ownerToken, f.businessId, a, List.of()).status());
        assertEquals(1, get(f.ownerToken, "/api/v1/businesses/%s/customers?tag=vip", f.businessId).body().path("total").asInt());
    }

    @Test void limitsAndValidation() {
        Fixture f = Fixture.create(this, 1, false);
        UUID a = customer(f, "+77010007003");
        assertEquals(400, put(f.ownerToken, f.businessId, a, List.of("x".repeat(31))).status());
        assertEquals(400, put(f.ownerToken, f.businessId, a, List.of("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k")).status());
    }

    @Test void tagsAreTenantIsolatedAndAnonymisationRemovesThem() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        UUID a = customer(f, "+77010007004");
        assertEquals(200, put(f.ownerToken, f.businessId, a, List.of("vip")).status());
        // another business cannot tag or see this customer's tags
        assertEquals(404, put(other.ownerToken, other.businessId, a, List.of("x")).status());
        assertEquals(0, get(other.ownerToken, "/api/v1/businesses/%s/customers?tag=vip", other.businessId).body().path("total").asInt());
        assertEquals(0, get(other.ownerToken, "/api/v1/businesses/%s/customers/tags", other.businessId).body().size());
        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/customers/%s/anonymize", Map.of(), f.businessId, a).status());
        assertEquals(0, jdbc.queryForObject("select count(*) from customer_tags where customer_id = ?", Integer.class, a));
    }
}
