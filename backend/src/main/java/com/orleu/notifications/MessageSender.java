package com.orleu.notifications;

/**
 * One delivery channel (SMS, e-mail, WhatsApp). A real provider adapter implements this; until credentials exist only {@link FakeMessageSender}
 * (test mode, never in the prod profile) can be enabled. Implementations must not log full phone numbers or message bodies.
 */
public interface MessageSender {
    enum Outcome { SENT, TRANSIENT_FAILURE, PERMANENT_FAILURE }

    /** {@code attempt} starts at 1. */
    record Outbound(java.util.UUID messageId, String channel, String recipient, String subject, String body, int attempt) {}

    record Result(Outcome outcome, String providerMessageId, String error) {
        public static Result sent(String id) { return new Result(Outcome.SENT, id, null); }
        public static Result transientFailure(String error) { return new Result(Outcome.TRANSIENT_FAILURE, null, error); }
        public static Result permanentFailure(String error) { return new Result(Outcome.PERMANENT_FAILURE, null, error); }
    }

    /** "FAKE" for the test sender, the provider name for real ones. */
    String name();

    boolean testMode();

    Result send(Outbound message);
}
