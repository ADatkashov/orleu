package com.orleu.analytics;

import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/analytics")
public class AnalyticsController {
    private final AnalyticsService service;
    public AnalyticsController(AnalyticsService service) { this.service = service; }

    @GetMapping("/summary")
    public AnalyticsService.Summary summary(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to) {
        return service.summary(businessId, from, to);
    }
}
