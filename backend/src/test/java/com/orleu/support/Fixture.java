package com.orleu.support;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/** A ready-to-book business: owner, branch open 09:00-18:00 every day, one 60-min 20,000 KZT service, N employees. */
public class Fixture {
    public String ownerToken;
    public UUID businessId;
    public String slug;
    public UUID branchId;
    public UUID serviceId;
    public UUID employeeId;
    public List<UUID> employeeIds;

    public static Fixture create(AbstractIT t, int employees, boolean publish) {
        Fixture f = new Fixture();
        f.ownerToken = t.newUser("owner");
        f.slug = t.unique("shop").toLowerCase().replaceAll("[^a-z0-9]", "");
        var biz = t.post(f.ownerToken, "/api/v1/businesses", Map.of("name", "Test Salon", "slug", f.slug, "businessType", "BARBERSHOP"));
        if (biz.status() != 201) throw new IllegalStateException("business: " + biz.body());
        f.businessId = biz.id();
        var br = t.post(f.ownerToken, "/api/v1/businesses/%s/branches", Map.of("name", "Main"), f.businessId);
        f.branchId = br.id();
        List<Map<String, Object>> hours = new java.util.ArrayList<>();
        for (int d = 1; d <= 7; d++) hours.add(Map.of("dayOfWeek", d, "open", "09:00", "close", "18:00"));
        t.put(f.ownerToken, "/api/v1/businesses/%s/branches/%s/hours", Map.of("hours", hours), f.businessId, f.branchId);
        var svc = t.post(f.ownerToken, "/api/v1/businesses/%s/services",
                Map.of("name", "Haircut", "durationMinutes", 60, "price", "20000.00"), f.businessId);
        f.serviceId = svc.id();
        f.employeeIds = new java.util.ArrayList<>();
        for (int i = 0; i < employees; i++) {
            var e = t.post(f.ownerToken, "/api/v1/businesses/%s/employees", Map.of("displayName", "Master " + i), f.businessId);
            UUID id = e.id();
            t.put(f.ownerToken, "/api/v1/businesses/%s/employees/%s/assignments",
                    Map.of("branchIds", List.of(f.branchId), "serviceIds", List.of(f.serviceId)), f.businessId, id);
            f.employeeIds.add(id);
        }
        f.employeeId = employees > 0 ? f.employeeIds.get(0) : null;
        if (publish) {
            var p = t.post(f.ownerToken, "/api/v1/businesses/%s/publish", null, f.businessId);
            if (p.status() != 200) throw new IllegalStateException("publish: " + p.body());
        }
        return f;
    }

    public Map<String, Object> customer(String phone) { return Map.of("fullName", "Aigerim", "phone", phone); }
}
