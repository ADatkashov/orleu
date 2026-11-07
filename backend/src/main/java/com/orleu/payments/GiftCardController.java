package com.orleu.payments;

import com.orleu.bookings.BookingDtos.BookingView;
import com.orleu.payments.GiftCardService.*;
import com.orleu.payments.PaymentDtos.Method;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}")
public class GiftCardController {
    public record SellRequest(@NotNull @DecimalMin("0.01") @Digits(integer = 12, fraction = 2) BigDecimal amount, @NotNull Method method,
                              @Size(max = 200) String buyerName, @Size(max = 300) String note, LocalDate expiresOn) {}
    public record CodeRequest(@NotBlank @Size(max = 40) String code) {}
    public record RedeemRequest(@NotBlank @Size(max = 40) String code, @NotNull @DecimalMin("0.01") @Digits(integer = 12, fraction = 2) BigDecimal amount) {}

    private final GiftCardService service;
    public GiftCardController(GiftCardService service) { this.service = service; }

    /** The response carries the code ONCE (codeShown=false on a replay of the same Idempotency-Key). */
    @PostMapping("/gift-cards") @ResponseStatus(HttpStatus.CREATED)
    public Sold sell(@PathVariable UUID businessId, @RequestHeader("Idempotency-Key") String key, @Valid @RequestBody SellRequest r) {
        return service.sell(businessId, key, r.amount(), r.method(), r.buyerName(), r.note(), r.expiresOn());
    }

    @GetMapping("/gift-cards")
    public List<CardView> list(@PathVariable UUID businessId) { return service.list(businessId); }

    @PostMapping("/gift-cards/lookup")
    public CardView lookup(@PathVariable UUID businessId, @Valid @RequestBody CodeRequest r) { return service.lookup(businessId, r.code()); }

    @PostMapping("/gift-cards/{id}/void")
    public CardView voidCard(@PathVariable UUID businessId, @PathVariable UUID id) { return service.voidCard(businessId, id); }

    @PostMapping("/bookings/{bookingId}/gift-card-payments") @ResponseStatus(HttpStatus.CREATED)
    public BookingView redeem(@PathVariable UUID businessId, @PathVariable UUID bookingId, @RequestHeader("Idempotency-Key") String key, @Valid @RequestBody RedeemRequest r) {
        return service.redeem(businessId, bookingId, key, r.code(), r.amount());
    }
}
