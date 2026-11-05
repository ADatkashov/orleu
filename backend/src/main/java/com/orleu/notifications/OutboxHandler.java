package com.orleu.notifications;

import java.util.UUID;

/** A consumer of outbox events. Throwing means "retry later". Implementations must be idempotent per eventId. */
public interface OutboxHandler {
    record Event(UUID id, UUID businessId, String type, UUID bookingId) {}

    void handle(Event event);
}
