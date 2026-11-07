package com.orleu.payments;

import com.orleu.bookings.BookingDtos.BookingView;
import com.orleu.payments.PaymentDtos.MoneyRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/bookings/{bookingId}")
public class PaymentController {
    private final PaymentService service;
    private final RefundRequestService refunds;
    public PaymentController(PaymentService service, RefundRequestService refunds) { this.service = service; this.refunds = refunds; }

    @PostMapping("/payments") @ResponseStatus(HttpStatus.CREATED)
    public BookingView pay(@PathVariable UUID businessId, @PathVariable UUID bookingId,
                           @RequestHeader("Idempotency-Key") String key, @Valid @RequestBody MoneyRequest r) {
        return service.recordPayment(businessId, bookingId, key, r);
    }

    /** 201 + booking when recorded; 202 + the pending request when the business requires approval for this amount. */
    @PostMapping("/refunds")
    public org.springframework.http.ResponseEntity<Object> refund(@PathVariable UUID businessId, @PathVariable UUID bookingId,
                              @RequestHeader("Idempotency-Key") String key, @Valid @RequestBody MoneyRequest r) {
        var out = refunds.submit(businessId, bookingId, key, r);
        return out.request() == null ? org.springframework.http.ResponseEntity.status(HttpStatus.CREATED).body(out.booking())
                : org.springframework.http.ResponseEntity.status(HttpStatus.ACCEPTED).body(out.request());
    }
}
