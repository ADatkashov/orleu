package com.orleu.payments;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public final class PaymentDtos {
    private PaymentDtos() {}

    public enum Method { CASH, BANK_TRANSFER, CARD_MANUAL }

    public record MoneyRequest(
            @NotNull @DecimalMin(value = "0.01") @Digits(integer = 12, fraction = 2) BigDecimal amount,
            @NotNull Method method,
            @Size(max = 200) String providerRef) {}
}
