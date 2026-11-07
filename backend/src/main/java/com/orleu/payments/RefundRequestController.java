package com.orleu.payments;

import com.orleu.payments.RefundRequestService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}")
public class RefundRequestController {
    public record PolicyRequest(@DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal threshold) {}
    public record RejectRequest(@Size(max = 500) String note) {}

    private final RefundRequestService service;
    public RefundRequestController(RefundRequestService service) { this.service = service; }

    @GetMapping("/refund-policy")
    public Policy policy(@PathVariable UUID businessId) { return service.policy(businessId); }

    /** threshold = null switches approval off; a number requires approval for refunds above it. */
    @PutMapping("/refund-policy")
    public Policy setPolicy(@PathVariable UUID businessId, @Valid @RequestBody PolicyRequest r) { return service.setPolicy(businessId, r.threshold()); }

    @GetMapping("/refund-requests")
    public List<RefundRequestView> list(@PathVariable UUID businessId, @RequestParam(required = false) String status) { return service.list(businessId, status); }

    @PostMapping("/refund-requests/{id}/approve")
    public RefundRequestView approve(@PathVariable UUID businessId, @PathVariable UUID id) { return service.approve(businessId, id); }

    @PostMapping("/refund-requests/{id}/reject")
    public RefundRequestView reject(@PathVariable UUID businessId, @PathVariable UUID id, @Valid @RequestBody(required = false) RejectRequest r) { return service.reject(businessId, id, r == null ? null : r.note()); }
}
