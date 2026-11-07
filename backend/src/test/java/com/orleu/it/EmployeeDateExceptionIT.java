package com.orleu.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class EmployeeDateExceptionIT extends AbstractIT {
    private static final ZoneId ALMATY = ZoneId.of("Asia/Almaty");

    private Fixture fixture() {
        Fixture f = Fixture.create(this, 2, true);
        List<Map<String, Object>> hours = new ArrayList<>();
        for (int i = 1; i <= 7; i++) hours.add(Map.of("dayOfWeek", i, "open", "00:00", "close", "23:59"));
        put(f.ownerToken, "/api/v1/businesses/%s/branches/%s/hours", Map.of("hours", hours), f.businessId, f.branchId);
        return f;
    }

    private Set<String> offered(Fixture f, UUID emp, LocalDate d) {
        Res res = get(f.ownerToken, "/api/v1/businesses/%s/availability?branchId=%s&serviceId=%s&employeeId=%s&date=%s", f.businessId, f.branchId, f.serviceId, emp, d);
        assertEquals(200, res.status(), res.body().toString());
        Set<String> out = new TreeSet<>();
        for (JsonNode s : res.body()) out.add(Instant.parse(s.path("start").asText()).atZone(ALMATY).toLocalTime().toString());
        return out;
    }

    private Res setException(Fixture f, UUID emp, LocalDate d, boolean dayOff, List<Map<String, String>> ranges) {
        return put(f.ownerToken, "/api/v1/businesses/%s/employees/%s/exceptions/%s", Map.of("dayOff", dayOff, "ranges", ranges), f.businessId, emp, d);
    }

    @Test void dayOffRemovesTheSlotsOfThatDateOnlyAndDeletingRestoresThem() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0), ali = f.employeeIds.get(1);
        assertTrue(offered(f, dana, d).contains("13:00"));
        Res set = setException(f, dana, d, true, List.of());
        assertEquals(200, set.status(), set.body().toString());
        assertTrue(offered(f, dana, d).isEmpty());
        assertTrue(offered(f, dana, d.plusDays(1)).contains("13:00"), "other dates are unaffected");
        assertTrue(offered(f, ali, d).contains("13:00"), "colleagues are unaffected");
        var sched = get(f.ownerToken, "/api/v1/businesses/%s/employees/%s/schedule", f.businessId, dana).body();
        assertEquals(1, sched.path("exceptions").size());
        assertTrue(sched.path("exceptions").get(0).path("dayOff").asBoolean());
        assertEquals(204, call(MockMvcRequestBuilders.delete("/api/v1/businesses/" + f.businessId + "/employees/" + dana + "/exceptions/" + d), f.ownerToken, null).status());
        assertTrue(offered(f, dana, d).contains("13:00"));
        assertEquals(404, call(MockMvcRequestBuilders.delete("/api/v1/businesses/" + f.businessId + "/employees/" + dana + "/exceptions/" + d), f.ownerToken, null).status());
    }

    @Test void specialHoursReplaceTheWeeklyRangesForThatDate() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0);
        // weekly: only 09-13 on this weekday; the exception opens 15-19 that one date instead
        put(f.ownerToken, "/api/v1/businesses/%s/employees/%s/hours", Map.of("hours", List.of(Map.of("dayOfWeek", d.getDayOfWeek().getValue(), "start", "09:00", "end", "13:00"))), f.businessId, dana);
        assertTrue(offered(f, dana, d).contains("09:00"));
        assertEquals(200, setException(f, dana, d, false, List.of(Map.of("start", "15:00", "end", "19:00"))).status());
        Set<String> slots = offered(f, dana, d);
        assertTrue(slots.contains("15:00") && slots.contains("18:00"));
        assertFalse(slots.contains("09:00") || slots.contains("14:45") || slots.contains("18:15"), slots.toString());
        assertTrue(offered(f, dana, d.plusDays(7)).contains("09:00"), "next week the weekly schedule applies again");
        // booking outside the special hours is refused
        assertEquals(409, post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", dana,
                "startsAt", at(d, 9, 0).toString(), "customer", Map.of("fullName", "X", "phone", "+77010010001")), f.businessId).status());
    }

    @Test void anExceptionAlsoWorksForASpecialistWithoutAWeeklyScheduleAndReportsAffectedBookings() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0);
        Res booking = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", dana,
                "startsAt", at(d, 10, 0).toString(), "customer", Map.of("fullName", "Booked", "phone", "+77010010002")), f.businessId);
        assertEquals(201, booking.status());
        Res set = setException(f, dana, d, true, List.of());
        assertEquals(1, set.body().path("affectedBookings").asInt());
        assertEquals("CONFIRMED", get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s", f.businessId, booking.id()).text("status"), "never cancelled automatically");
        assertEquals(0, setException(f, dana, d, false, List.of(Map.of("start", "09:00", "end", "12:00"))).body().path("affectedBookings").asInt(), "10:00 fits 09-12");
    }

    @Test void validationPastDatesAndTenantIsolation() {
        Fixture f = fixture(), other = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0);
        assertEquals(400, setException(f, dana, d, false, List.of()).status(), "neither day off nor ranges");
        assertEquals(400, setException(f, dana, d, true, List.of(Map.of("start", "09:00", "end", "10:00"))).status(), "day off with ranges");
        assertEquals(400, setException(f, dana, d, false, List.of(Map.of("start", "10:00", "end", "10:00"))).status());
        assertEquals(400, setException(f, dana, d, false, List.of(Map.of("start", "09:00", "end", "13:00"), Map.of("start", "12:00", "end", "15:00"))).status(), "overlap");
        assertEquals(400, setException(f, dana, LocalDate.now().minusDays(10), true, List.of()).status(), "past");
        assertEquals(404, put(other.ownerToken, "/api/v1/businesses/%s/employees/%s/exceptions/%s", Map.of("dayOff", true, "ranges", List.of()), other.businessId, dana, d).status());
        String recep = newUser("recepexc");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(recep, "/api/v1/me").text("email"), "role", "RECEPTIONIST"), f.businessId);
        assertEquals(403, put(recep, "/api/v1/businesses/%s/employees/%s/exceptions/%s", Map.of("dayOff", true, "ranges", List.of()), f.businessId, dana, d).status());
    }
}
