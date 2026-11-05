package com.orleu.bookings;

import java.util.EnumSet;
import java.util.Set;

/** Booking lifecycle. Transitions are validated on the backend; clients cannot set arbitrary statuses. */
public enum BookingStatus {
    PENDING, AWAITING_PAYMENT, CONFIRMED, CHECKED_IN, IN_PROGRESS, COMPLETED, CANCELLED, NO_SHOW, EXPIRED;

    /** Statuses that occupy the employee's time (mirrors the exclusion-constraint predicate). */
    public static final Set<BookingStatus> ACTIVE = EnumSet.of(PENDING, AWAITING_PAYMENT, CONFIRMED, CHECKED_IN, IN_PROGRESS);

    public Set<BookingStatus> next() {
        return switch (this) {
            case PENDING -> EnumSet.of(CONFIRMED, CANCELLED);
            case AWAITING_PAYMENT -> EnumSet.of(CONFIRMED, CANCELLED, EXPIRED);
            case CONFIRMED -> EnumSet.of(CHECKED_IN, CANCELLED, NO_SHOW);
            case CHECKED_IN -> EnumSet.of(IN_PROGRESS, CANCELLED);
            case IN_PROGRESS -> EnumSet.of(COMPLETED);
            case COMPLETED, CANCELLED, NO_SHOW, EXPIRED -> EnumSet.noneOf(BookingStatus.class);
        };
    }

    public boolean canTransitionTo(BookingStatus target) { return next().contains(target); }

    public boolean isActive() { return ACTIVE.contains(this); }
}
