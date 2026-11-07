package com.orleu.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.UUID;

/**
 * TEST sender: nothing leaves the machine. The outcome is chosen by the last four digits of the recipient so every path can be exercised:
 * ...0000 permanent failure, ...0001 always transient failure, ...0002 transient on the first two attempts then success, anything else success.
 * Guarded by {@link MessagingConfig}: refuses to start in the prod profile.
 */
public class FakeMessageSender implements MessageSender {
    private static final Logger log = LoggerFactory.getLogger(FakeMessageSender.class);

    @Override public String name() { return "FAKE"; }
    @Override public boolean testMode() { return true; }

    @Override
    public Result send(Outbound m) {
        String r = m.recipient() == null ? "" : m.recipient();
        String last4 = r.length() >= 4 ? r.substring(r.length() - 4) : r;
        log.info("FAKE {} to ****{} (attempt {}, {} chars) - not delivered, test mode", m.channel(), last4, m.attempt(), m.body() == null ? 0 : m.body().length());
        return switch (last4) {
            case "0000" -> Result.permanentFailure("fake: number rejected");
            case "0001" -> Result.transientFailure("fake: provider unavailable");
            case "0002" -> m.attempt() <= 2 ? Result.transientFailure("fake: provider busy") : Result.sent("fake-" + UUID.randomUUID());
            default -> Result.sent("fake-" + UUID.randomUUID());
        };
    }
}
