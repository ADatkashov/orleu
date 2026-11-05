package com.orleu.unit;

import com.orleu.common.Money;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

class MoneyTest {
    @Test void depositExampleFromSpec() {
        assertEquals(new BigDecimal("6000.00"), Money.percentOf(new BigDecimal("20000"), new BigDecimal("30")));
    }
    @Test void zeroAndFullDeposit() {
        assertEquals(new BigDecimal("0.00"), Money.percentOf(new BigDecimal("20000"), BigDecimal.ZERO));
        assertEquals(new BigDecimal("20000.00"), Money.percentOf(new BigDecimal("20000"), new BigDecimal("100")));
    }
    @Test void roundsHalfUpWithoutFloatingPointError() {
        assertEquals(new BigDecimal("3.33"), Money.percentOf(new BigDecimal("33.33"), new BigDecimal("10")));
        assertEquals(new BigDecimal("0.01"), Money.percentOf(new BigDecimal("0.05"), new BigDecimal("10")));
    }
    @Test void rejectsInvalidPercent() {
        assertThrows(IllegalArgumentException.class, () -> Money.percentOf(BigDecimal.TEN, new BigDecimal("101")));
        assertThrows(IllegalArgumentException.class, () -> Money.percentOf(BigDecimal.TEN, new BigDecimal("-1")));
    }
}
