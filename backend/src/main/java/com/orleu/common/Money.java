package com.orleu.common;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Decimal-safe monetary helpers. All amounts are scale 2, HALF_UP. Never use double for money. */
public final class Money {
    private static final BigDecimal HUNDRED = new BigDecimal("100");
    private Money() {}

    public static BigDecimal scale(BigDecimal v) {
        return v.setScale(2, RoundingMode.HALF_UP);
    }

    /** percent in [0,100]. Example: 20000 KZT at 30% -> 6000.00 */
    public static BigDecimal percentOf(BigDecimal amount, BigDecimal percent) {
        if (percent.signum() < 0 || percent.compareTo(HUNDRED) > 0) {
            throw new IllegalArgumentException("percent must be within 0..100");
        }
        return scale(amount.multiply(percent).divide(HUNDRED, 2, RoundingMode.HALF_UP));
    }
}
