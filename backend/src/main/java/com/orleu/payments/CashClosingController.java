package com.orleu.payments;

import com.orleu.payments.CashClosingService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/finance")
public class CashClosingController {
    public record CloseRequest(@NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal expectedCash,
                               @NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal countedCash,
                               @Size(max = 500) String note, LocalDate since) {}

    private final CashClosingService service;
    public CashClosingController(CashClosingService service) { this.service = service; }

    /** What the system expects for the open period (since the last closing). {@code since} (a date) is allowed only before the first closing. */
    @GetMapping("/closing-preview")
    public Preview preview(@PathVariable UUID businessId, @RequestParam(required = false) LocalDate since) { return service.preview(businessId, since); }

    @PostMapping("/closings") @ResponseStatus(HttpStatus.CREATED)
    public Closing close(@PathVariable UUID businessId, @Valid @RequestBody CloseRequest r) { return service.close(businessId, r.expectedCash(), r.countedCash(), r.note(), r.since()); }

    @GetMapping("/closings")
    public List<Closing> history(@PathVariable UUID businessId) { return service.history(businessId); }
}
