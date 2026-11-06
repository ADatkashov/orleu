package com.orleu.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class EmployeeScheduleIT extends AbstractIT {
    private static final ZoneId ALMATY = ZoneId.of("Asia/Almaty");

    /** Two specialists, a one-hour service, branch open all day every day. */
    private Fixture fixture() {
        Fixture f = Fixture.create(this, 2, true);
        List<Map<String, Object>> hours = new ArrayList<>();
        for (int i = 1; i <= 7; i++) hours.add(Map.of("dayOfWeek", i, "open", "00:00", "close", "23:59"));
        put(f.ownerToken, "/api/v1/businesses/%s/branches/%s/hours", Map.of("hours", hours), f.businessId, f.branchId);
        return f;
    }

    private Map<String, Object> r(LocalDate d, String start, String end) { return Map.of("dayOfWeek", d.getDayOfWeek().getValue(), "start", start, "end", end); }

    private Res setHours(Fixture f, UUID emp, List<Map<String, Object>> ranges) {
        return put(f.ownerToken, "/api/v1/businesses/%s/employees/%s/hours", Map.of("hours", ranges), f.businessId, emp);
    }

    /** Start times (HH:mm in Almaty) offered to a specific specialist on the date. */
    private Set<String> offered(Fixture f, UUID emp, LocalDate d) {
        Res res = get(f.ownerToken, "/api/v1/businesses/%s/availability?branchId=%s&serviceId=%s&employeeId=%s&date=%s", f.businessId, f.branchId, f.serviceId, emp, d);
        assertEquals(200, res.status(), res.body().toString());
        Set<String> out = new TreeSet<>();
        for (JsonNode s : res.body()) out.add(Instant.parse(s.path("start").asText()).atZone(ALMATY).toLocalTime().toString());
        return out;
    }

    @Test void withoutAPersonalScheduleTheSpecialistFollowsTheBranch() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        Set<String> slots = offered(f, f.employeeIds.get(0), d);
        assertTrue(slots.contains("10:00") && slots.contains("13:00") && slots.contains("22:00"));
        assertEquals(0, get(f.ownerToken, "/api/v1/businesses/%s/employees/%s/schedule", f.businessId, f.employeeIds.get(0)).body().path("hours").size());
    }

    @Test void rangesLimitTheOfferedTimesAndABreakBetweenTwoRangesIsRespected() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0), ali = f.employeeIds.get(1);
        Res set = setHours(f, dana, List.of(r(d, "09:00", "13:00"), r(d, "14:00", "18:00")));
        assertEquals(200, set.status(), set.body().toString());
        assertEquals(0, set.body().path("affectedBookings").asInt());
        Set<String> slots = offered(f, dana, d);
        assertTrue(slots.contains("09:00") && slots.contains("12:00") && slots.contains("14:00") && slots.contains("17:00"));
        assertFalse(slots.contains("08:45") || slots.contains("12:15") || slots.contains("12:45") || slots.contains("13:00") || slots.contains("13:30") || slots.contains("17:15") || slots.contains("18:00"),
                "nothing before 09:00, nothing that would run into the 13:00-14:00 break, nothing after 18:00: " + slots);
        assertTrue(offered(f, ali, d).contains("13:00"), "the colleague without a personal schedule is unaffected");
        assertTrue(offered(f, dana, d.plusDays(1)).isEmpty(), "a weekday without ranges is a day off once a schedule exists");
        assertEquals(200, setHours(f, dana, List.of()).status());
        assertTrue(offered(f, dana, d.plusDays(1)).contains("13:00"), "an empty schedule means 'follow the branch' again");
    }

    @Test void bookingInsideABreakOrAfterHoursIsRefusedEvenForStaff() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0);
        setHours(f, dana, List.of(r(d, "09:00", "13:00"), r(d, "14:00", "18:00")));
        for (int[] t : new int[][]{{13, 0}, {12, 30}, {18, 0}, {8, 0}}) {
            Res res = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", dana,
                    "startsAt", at(d, t[0], t[1]).toString(), "customer", Map.of("fullName", "X", "phone", "+77010006001")), f.businessId);
            assertEquals(409, res.status(), t[0] + ":" + t[1]);
        }
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", dana,
                "startsAt", at(d, 14, 0).toString(), "customer", Map.of("fullName", "X", "phone", "+77010006001")), f.businessId).status());
    }

    @Test void invalidSchedulesAreRejectedAndExistingBookingsAreReportedNotCancelled() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0);
        assertEquals(400, setHours(f, dana, List.of(r(d, "10:00", "10:00"))).status());
        assertEquals(400, setHours(f, dana, List.of(r(d, "12:00", "09:00"))).status());
        assertEquals(400, setHours(f, dana, List.of(r(d, "09:00", "13:00"), r(d, "12:00", "15:00"))).status(), "overlap");
        assertEquals(400, setHours(f, dana, List.of(Map.of("dayOfWeek", 8, "start", "09:00", "end", "10:00"))).status());
        List<Map<String, Object>> seven = new ArrayList<>();
        for (int i = 0; i < 7; i++) seven.add(r(d, String.format("%02d:00", 6 + i * 2), String.format("%02d:30", 6 + i * 2)));
        assertEquals(400, setHours(f, dana, seven).status(), "at most six ranges a day");

        Res booking = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", dana,
                "startsAt", at(d, 10, 0).toString(), "customer", Map.of("fullName", "Booked", "phone", "+77010006002")), f.businessId);
        assertEquals(201, booking.status());
        Res set = setHours(f, dana, List.of(r(d, "14:00", "18:00")));
        assertEquals(1, set.body().path("affectedBookings").asInt(), "the 10:00 booking no longer fits the new hours");
        assertEquals("CONFIRMED", get(f.ownerToken, "/api/v1/businesses/%s/bookings/%s", f.businessId, booking.id()).text("status"), "the booking is not cancelled");
    }

    @Test void timeOffCanBeListedWithAffectedBookingsAndRemoved() {
        Fixture f = fixture();
        LocalDate d = bookingDate();
        UUID dana = f.employeeIds.get(0);
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId, "employeeId", dana,
                "startsAt", at(d, 10, 0).toString(), "customer", Map.of("fullName", "Booked", "phone", "+77010006003")), f.businessId).status());
        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/employees/%s/time-off", Map.of("startsAt", at(d, 9, 0).toString(), "endsAt", at(d, 12, 0).toString(), "reason", "dentist"), f.businessId, dana).status());
        var sched = get(f.ownerToken, "/api/v1/businesses/%s/employees/%s/schedule", f.businessId, dana).body();
        assertEquals(1, sched.path("timeOff").size());
        assertEquals("dentist", sched.path("timeOff").get(0).path("reason").asText());
        assertEquals(1, sched.path("timeOff").get(0).path("affectedBookings").asInt());
        assertFalse(offered(f, dana, d).contains("11:00"));
        UUID id = UUID.fromString(sched.path("timeOff").get(0).path("id").asText());
        assertEquals(204, call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/api/v1/businesses/" + f.businessId + "/employees/" + dana + "/time-off/" + id), f.ownerToken, null).status());
        assertEquals(0, get(f.ownerToken, "/api/v1/businesses/%s/employees/%s/schedule", f.businessId, dana).body().path("timeOff").size());
        assertTrue(offered(f, dana, d).contains("11:00"), "removing the time off frees the slots again");
    }

    @Test void schedulesAreTenantIsolatedAndNeedStaffManagement() {
        Fixture a = fixture(), b = fixture();
        UUID dana = a.employeeIds.get(0);
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/employees/%s/schedule", a.businessId, dana).status());
        assertEquals(404, get(b.ownerToken, "/api/v1/businesses/%s/employees/%s/schedule", b.businessId, dana).status(), "a foreign employee id through my own business");
        assertEquals(404, put(b.ownerToken, "/api/v1/businesses/%s/employees/%s/hours", Map.of("hours", List.of()), b.businessId, dana).status());
        String recep = newUser("recepsch");
        post(a.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(recep, "/api/v1/me").text("email"), "role", "RECEPTIONIST"), a.businessId);
        assertEquals(403, put(recep, "/api/v1/businesses/%s/employees/%s/hours", Map.of("hours", List.of()), a.businessId, dana).status());
        assertEquals(403, get(recep, "/api/v1/businesses/%s/employees/%s/schedule", a.businessId, dana).status());
        assertEquals(401, get(null, "/api/v1/businesses/%s/employees/%s/schedule", a.businessId, dana).status());
    }
}
