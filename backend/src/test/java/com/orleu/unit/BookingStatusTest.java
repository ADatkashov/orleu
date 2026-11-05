package com.orleu.unit;

import com.orleu.bookings.BookingStatus;
import org.junit.jupiter.api.Test;

import static com.orleu.bookings.BookingStatus.*;
import static org.junit.jupiter.api.Assertions.*;

class BookingStatusTest {
    @Test void happyPath() {
        assertTrue(PENDING.canTransitionTo(CONFIRMED));
        assertTrue(CONFIRMED.canTransitionTo(CHECKED_IN));
        assertTrue(CHECKED_IN.canTransitionTo(IN_PROGRESS));
        assertTrue(IN_PROGRESS.canTransitionTo(COMPLETED));
    }
    @Test void terminalStatesHaveNoExit() {
        for (BookingStatus s : new BookingStatus[]{COMPLETED, CANCELLED, NO_SHOW, EXPIRED}) {
            for (BookingStatus t : values()) assertFalse(s.canTransitionTo(t), s + " -> " + t);
        }
    }
    @Test void cannotSkipSteps() {
        assertFalse(PENDING.canTransitionTo(COMPLETED));
        assertFalse(CONFIRMED.canTransitionTo(COMPLETED));
        assertFalse(CONFIRMED.canTransitionTo(PENDING));
        assertFalse(AWAITING_PAYMENT.canTransitionTo(COMPLETED));
    }
    @Test void onlyActiveStatusesBlockTime() {
        assertTrue(CONFIRMED.isActive());
        assertFalse(CANCELLED.isActive());
        assertFalse(EXPIRED.isActive());
        assertFalse(COMPLETED.isActive());
    }
}
