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
    public PaymentController(PaymentService service) { this.service = service; }

    @PostMapping("/payments") @ResponseStatus(HttpStatus.CREATED)
    public BookingView pay(@PathVariable UUID businessId, @PathVariable UUID bookingId,
                           @RequestHeader("Idempotency-Key") String key, @Valid @RequestBody MoneyRequest r) {
        return service.recordPayment(businessId, bookingId, key, r);
    }

    @PostMapping("/refunds") @ResponseStatus(HttpStatus.CREATED)
    public BookingView refund(@PathVariable UUID businessId, @PathVariable UUID bookingId,
                              @RequestHeader("Idempotency-Key") String key, @Valid @RequestBody MoneyRequest r) {
        return service.recordRefund(businessId, bookingId, key, r);
    }
}
