package com.orleu.analytics;

import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/analytics")
public class AnalyticsController {
    private final AnalyticsService service;
    private final AnalyticsReports reports;
    public AnalyticsController(AnalyticsService service, AnalyticsReports reports) { this.service = service; this.reports = reports; }

    @GetMapping("/breakdown")
    public java.util.List<AnalyticsReports.BreakdownRow> breakdown(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to,
                                                                   @RequestParam AnalyticsReports.Dimension by) {
        return reports.breakdown(businessId, from, to, by);
    }

    @GetMapping("/timeseries")
    public java.util.List<AnalyticsReports.DayPoint> timeseries(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to) {
        return reports.timeseries(businessId, from, to);
    }

    @GetMapping("/peak-hours")
    public int[] peakHours(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to) { return reports.peakHours(businessId, from, to); }

    @GetMapping("/customers")
    public AnalyticsReports.CustomerMix customers(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to) {
        return reports.customerMix(businessId, from, to);
    }

    @GetMapping("/summary")
    public AnalyticsService.Summary summary(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to) {
        return service.summary(businessId, from, to);
    }
}
