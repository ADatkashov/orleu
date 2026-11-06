package com.orleu.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class AnalyticsReportsIT extends AbstractIT {
    private Fixture f;
    private UUID serviceB;
    private LocalDate d, today;
    private Instant from, to;

    /** Two specialists, two services (A 20,000 / B 10,000), open all day; six bookings plus cash movements. */
    private void scenario() {
        f = Fixture.create(this, 2, true);
        List<Map<String, Object>> hours = new ArrayList<>();
        for (int i = 1; i <= 7; i++) hours.add(Map.of("dayOfWeek", i, "open", "00:00", "close", "23:59"));
        put(f.ownerToken, "/api/v1/businesses/%s/branches/%s/hours", Map.of("hours", hours), f.businessId, f.branchId);
        serviceB = post(f.ownerToken, "/api/v1/businesses/%s/services", Map.of("name", "Beard", "durationMinutes", 60, "price", "10000"), f.businessId).id();
        for (UUID e : f.employeeIds) put(f.ownerToken, "/api/v1/businesses/%s/employees/%s/assignments",
                Map.of("branchIds", List.of(f.branchId), "serviceIds", List.of(f.serviceId, serviceB)), f.businessId, e);
        d = bookingDate();
        today = LocalDate.now(ALMATY);
        from = at(today, 0, 0);
        to = at(d.plusDays(2), 0, 0);

        UUID e0 = f.employeeIds.get(0), e1 = f.employeeIds.get(1);
        UUID b1 = book(f.serviceId, e0, d, 10, 0, "+77010008001");   // completed, fully paid
        UUID b2 = book(f.serviceId, e1, d, 10, 0, "+77010008002");   // completed, paid then partly refunded
        UUID b3 = book(serviceB, e0, d, 14, 0, "+77010008001");      // cancelled
        UUID b4 = book(serviceB, e1, d.plusDays(1), 10, 0, "+77010008003"); // no-show
        UUID b5 = book(f.serviceId, e0, d.plusDays(1), 10, 0, "+77010008001"); // upcoming, deposit paid
        book(f.serviceId, e0, d, 22, 30, "+77010008004");            // 22:30 business time
        book(f.serviceId, e0, d.plusDays(1), 0, 30, "+77010008004"); // 00:30 next business day (same UTC date as the one above)
        for (UUID id : List.of(b1, b2)) transition(id, "CHECKED_IN", "IN_PROGRESS", "COMPLETED");
        transition(b3, "CANCELLED");
        transition(b4, "NO_SHOW");
        money(b1, "payments", "20000", "an-1");
        money(b2, "payments", "20000", "an-2");
        money(b2, "refunds", "5000", "an-3");
        money(b5, "payments", "5000", "an-4");
    }

    private UUID book(UUID service, UUID employee, LocalDate day, int h, int m, String phone) {
        Res r = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", service, "employeeId", employee,
                "startsAt", at(day, h, m).toString(), "customer", Map.of("fullName", "C " + phone, "phone", phone)), f.businessId);
        assertEquals(201, r.status(), r.body().toString());
        return r.id();
    }

    private void transition(UUID id, String... statuses) {
        for (String s : statuses) assertEquals(200, post(f.ownerToken, "/api/v1/businesses/%s/bookings/%s/transition", Map.of("status", s), f.businessId, id).status());
    }

    private void money(UUID id, String kind, String amount, String key) {
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + id + "/" + kind),
                f.ownerToken, Map.of("amount", amount, "method", "CASH"), "Idempotency-Key", key).status());
    }

    private Res report(String token, String what, Instant a, Instant b, String extra) {
        return get(token, "/api/v1/businesses/%s/analytics/" + what + "?from=" + a + "&to=" + b + extra, f.businessId);
    }

    private static JsonNode row(Res r, String name) {
        for (JsonNode n : r.body()) if (n.path("name").asText().equals(name)) return n;
        fail("no row " + name + " in " + r.body());
        return null;
    }

    private static void assertMoney(String expected, JsonNode n) { assertEquals(0, new BigDecimal(expected).compareTo(n.decimalValue()), n.toString()); }

    @Test void breakdownByServiceKeepsBookedValueAndCashApart() {
        scenario();
        Res r = report(f.ownerToken, "breakdown", from, to, "&by=SERVICE");
        assertEquals(200, r.status(), r.body().toString());
        JsonNode a = row(r, "Haircut"), b = row(r, "Beard");
        assertEquals(5, a.path("bookings").asInt());
        assertEquals(2, a.path("completed").asInt());
        assertMoney("100000", a.path("bookedValue"));
        assertMoney("45000", a.path("collected"));
        assertMoney("5000", a.path("refunded"));
        assertMoney("40000", a.path("netCollected"));
        assertEquals(1, b.path("bookings").asInt());     // the no-show counts as demand, the cancelled one does not
        assertEquals(1, b.path("cancelled").asInt());
        assertEquals(1, b.path("noShows").asInt());
        assertMoney("0", b.path("bookedValue"));          // neither a no-show nor a cancellation is booked value
        assertMoney("0", b.path("netCollected"));
        assertEquals("Haircut", r.body().get(0).path("name").asText(), "sorted by cash collected");
    }

    @Test void breakdownByEmployeeAndBranch() {
        scenario();
        Res emp = report(f.ownerToken, "breakdown", from, to, "&by=EMPLOYEE");
        JsonNode m0 = row(emp, "Master 0"), m1 = row(emp, "Master 1");
        assertEquals(4, m0.path("bookings").asInt());
        assertEquals(1, m0.path("completed").asInt());
        assertEquals(1, m0.path("cancelled").asInt());
        assertMoney("80000", m0.path("bookedValue"));
        assertMoney("25000", m0.path("netCollected"));
        assertEquals(2, m1.path("bookings").asInt());
        assertEquals(1, m1.path("noShows").asInt());
        assertMoney("20000", m1.path("bookedValue"));
        assertMoney("15000", m1.path("netCollected"));
        Res br = report(f.ownerToken, "breakdown", from, to, "&by=BRANCH");
        assertEquals(1, br.body().size());
        assertEquals(6, br.body().get(0).path("bookings").asInt());
        assertMoney("40000", br.body().get(0).path("netCollected"));
    }

    @Test void timeseriesBucketsDaysInTheBusinessTimezoneAndZeroFills() {
        scenario();
        Res r = report(f.ownerToken, "timeseries", from, to, "");
        assertEquals(200, r.status(), r.body().toString());
        assertEquals(5, r.body().size());                        // today .. d+1, one point per day, no gaps
        Map<String, JsonNode> byDate = new HashMap<>();
        for (JsonNode n : r.body()) byDate.put(n.path("date").asText(), n);
        assertMoney("40000", byDate.get(today.toString()).path("netCollected"));    // cash is attributed to the day it was recorded
        assertEquals(0, byDate.get(today.toString()).path("bookings").asInt());
        // 22:30 and 00:30 business time share a UTC date but are different business days
        assertEquals(3, byDate.get(d.toString()).path("bookings").asInt());
        assertEquals(2, byDate.get(d.toString()).path("completed").asInt());
        assertMoney("60000", byDate.get(d.toString()).path("bookedValue"));
        assertEquals(2, byDate.get(d.plusDays(1).toString()).path("bookings").asInt());
        assertMoney("40000", byDate.get(d.plusDays(1).toString()).path("bookedValue"));
        assertEquals(0, byDate.get(today.plusDays(1).toString()).path("bookings").asInt());
        assertMoney("0", byDate.get(today.plusDays(1).toString()).path("bookedValue"));
    }

    @Test void peakHoursUseBusinessTimeAndIgnoreCancellations() {
        scenario();
        Res r = report(f.ownerToken, "peak-hours", from, to, "");
        assertEquals(24, r.body().size());
        assertEquals(4, r.body().get(10).asInt());   // b1, b2, b4 (no-show) and b5
        assertEquals(1, r.body().get(22).asInt());
        assertEquals(1, r.body().get(0).asInt());
        assertEquals(0, r.body().get(14).asInt());   // the 14:00 booking was cancelled
    }

    @Test void newAndReturningCustomers() {
        scenario();
        Res day1 = report(f.ownerToken, "customers", at(d.plusDays(1), 0, 0), at(d.plusDays(2), 0, 0), "");
        assertEquals(1, day1.body().path("newCustomers").asInt());        // +77010008003 first seen that day
        assertEquals(2, day1.body().path("returningCustomers").asInt());  // ...0001 and ...0004 came before
        assertEquals(0.6667, day1.body().path("returningShare").asDouble(), 0.0001);
        Res day0 = report(f.ownerToken, "customers", at(d, 0, 0), at(d.plusDays(1), 0, 0), "");
        assertEquals(3, day0.body().path("newCustomers").asInt());
        assertEquals(0, day0.body().path("returningCustomers").asInt());
        Res none = report(f.ownerToken, "customers", at(d.plusDays(20), 0, 0), at(d.plusDays(21), 0, 0), "");
        assertEquals(0, none.body().path("returningShare").asDouble());
    }

    @Test void reportsAreTenantIsolatedRoleCheckedAndValidated() {
        scenario();
        Fixture other = Fixture.create(this, 1, false);
        for (String what : new String[]{"breakdown", "timeseries", "peak-hours", "customers"}) {
            assertEquals(404, get(other.ownerToken, "/api/v1/businesses/%s/analytics/" + what + "?from=" + from + "&to=" + to + "&by=SERVICE", f.businessId).status(), what);
        }
        Res mine = get(other.ownerToken, "/api/v1/businesses/%s/analytics/breakdown?from=" + from + "&to=" + to + "&by=SERVICE", other.businessId);
        assertEquals(200, mine.status());
        assertEquals(0, mine.body().size());

        String staff = newUser("stf"), acct = newUser("acc");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(staff, "/api/v1/me").text("email"), "role", "STAFF"), f.businessId);
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(acct, "/api/v1/me").text("email"), "role", "ACCOUNTANT"), f.businessId);
        assertEquals(403, report(staff, "breakdown", from, to, "&by=SERVICE").status());
        assertEquals(200, report(acct, "breakdown", from, to, "&by=SERVICE").status());

        assertEquals(400, report(f.ownerToken, "breakdown", to, from, "&by=SERVICE").status());                          // inverted range
        assertEquals(400, report(f.ownerToken, "timeseries", from, from.plusSeconds(400L * 86400), "").status());         // longer than a year
        assertEquals(400, report(f.ownerToken, "breakdown", from, to, "&by=PASSWORD").status());                         // closed set of dimensions
        assertEquals(400, report(f.ownerToken, "breakdown", from, to, "&by=service;drop table bookings").status());
    }
}
