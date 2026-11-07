package com.orleu.scheduling;

import com.orleu.scheduling.EmployeeScheduleService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/employees/{employeeId}")
public class EmployeeScheduleController {
    public record RangeInput(int dayOfWeek, @NotNull LocalTime start, @NotNull LocalTime end) {}
    public record DateRangeInput(@NotNull LocalTime start, @NotNull LocalTime end) {}
    public record ExceptionRequest(boolean dayOff, @Valid List<DateRangeInput> ranges) {}
    public record HoursRequest(@NotNull @Valid List<RangeInput> hours) {}

    private final EmployeeScheduleService schedule;

    public EmployeeScheduleController(EmployeeScheduleService schedule) { this.schedule = schedule; }

    @GetMapping("/schedule")
    public Schedule get(@PathVariable UUID businessId, @PathVariable UUID employeeId) { return schedule.get(businessId, employeeId); }

    /** Replaces the weekly schedule; an empty list means "follow the branch hours". Reports how many upcoming bookings no longer fit. */
    @PutMapping("/hours")
    public HoursResult setHours(@PathVariable UUID businessId, @PathVariable UUID employeeId, @Valid @RequestBody HoursRequest r) {
        return schedule.setHours(businessId, employeeId, r.hours().stream().map(x -> new Range(x.dayOfWeek(), x.start(), x.end())).toList());
    }

    /** One date differs from the weekly schedule: a day off, or other working ranges. Reports bookings that no longer fit. */
    @PutMapping("/exceptions/{date}")
    public ExceptionResult setException(@PathVariable UUID businessId, @PathVariable UUID employeeId, @PathVariable java.time.LocalDate date, @Valid @RequestBody ExceptionRequest r) {
        return schedule.setException(businessId, employeeId, date, r.dayOff(), r.ranges() == null ? List.of() : r.ranges().stream().map(x -> new DateRange(x.start(), x.end())).toList());
    }

    @DeleteMapping("/exceptions/{date}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteException(@PathVariable UUID businessId, @PathVariable UUID employeeId, @PathVariable java.time.LocalDate date) { schedule.deleteException(businessId, employeeId, date); }

    @DeleteMapping("/time-off/{timeOffId}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteTimeOff(@PathVariable UUID businessId, @PathVariable UUID employeeId, @PathVariable UUID timeOffId) { schedule.deleteTimeOff(businessId, employeeId, timeOffId); }
}
