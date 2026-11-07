package com.orleu.notifications;

import com.orleu.notifications.MessageSender.Outbound;
import com.orleu.notifications.MessageSender.Result;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

/**
 * Sends prepared customer messages through the configured {@link MessageSender}. With no sender configured it does nothing (messages stay NOT_SENT).
 * Claiming is a short transaction (FOR UPDATE SKIP LOCKED + a lease in next_attempt_at); the send itself runs OUTSIDE any transaction so a slow
 * provider holds no database locks, and a crash mid-send only means the message is retried after the lease. Transient failures back off
 * 1 min, 5 min, 30 min and stop at {@value #MAX_ATTEMPTS} attempts (FAILED); permanent failures are FAILED at once. Staff can retry a FAILED message.
 */
@Component
public class MessageDispatcher {
    private static final Logger log = LoggerFactory.getLogger(MessageDispatcher.class);
    static final int MAX_ATTEMPTS = 4;
    static final Duration LEASE = Duration.ofMinutes(2);
    private static final Duration[] BACKOFF = {Duration.ofMinutes(1), Duration.ofMinutes(5), Duration.ofMinutes(30)};

    private final ObjectProvider<MessageSender> sender;
    private final JdbcClient jdbc;
    private final TransactionTemplate tx;

    public MessageDispatcher(ObjectProvider<MessageSender> sender, JdbcClient jdbc, TransactionTemplate tx) { this.sender = sender; this.jdbc = jdbc; this.tx = tx; }

    @Scheduled(fixedDelayString = "${orleu.jobs.message-interval:PT30S}")
    public void scheduled() {
        try { dispatchDue(50); } catch (Exception e) { log.error("Message dispatch failed", e); }
    }

    private record Claimed(UUID id, String channel, String phone, String body, int attempt) {}

    /** Sends up to {@code limit} due messages; returns how many were attempted. */
    public int dispatchDue(int limit) {
        MessageSender s = sender.getIfAvailable();
        if (s == null) return 0;
        List<Claimed> batch = tx.execute(st -> {
            var rows = jdbc.sql("""
                select id, channel, recipient_phone, body, attempts + 1 from customer_messages
                where status = 'NOT_SENT' and (next_attempt_at is null or next_attempt_at <= now())
                order by created_at limit :n for update skip locked
                """).param("n", limit).query((rs, i) -> new Claimed(rs.getObject(1, UUID.class), rs.getString(2), rs.getString(3), rs.getString(4), rs.getInt(5))).list();
            for (Claimed c : rows) {
                jdbc.sql("update customer_messages set attempts = :a, next_attempt_at = now() + make_interval(secs => :s) where id = :id")
                        .param("a", c.attempt()).param("s", (double) LEASE.toSeconds()).param("id", c.id()).update();
            }
            return rows;
        });
        if (batch == null) return 0;
        for (Claimed c : batch) {
            Result r;
            try { r = s.send(new Outbound(c.id(), c.channel(), c.phone(), c.body(), c.attempt())); }
            catch (Exception e) { r = Result.transientFailure("sender error: " + e.getClass().getSimpleName()); }
            record(c, r);
        }
        return batch.size();
    }

    private void record(Claimed c, Result r) {
        String err = r.error() == null ? null : (r.error().length() > 200 ? r.error().substring(0, 200) : r.error());
        switch (r.outcome()) {
            case SENT -> jdbc.sql("update customer_messages set status = 'SENT', sent_at = now(), provider_message_id = :p, last_error = null, next_attempt_at = null where id = :id and status = 'NOT_SENT'")
                    .param("p", r.providerMessageId()).param("id", c.id()).update();
            case PERMANENT_FAILURE -> jdbc.sql("update customer_messages set status = 'FAILED', last_error = :e, next_attempt_at = null where id = :id and status = 'NOT_SENT'")
                    .param("e", err).param("id", c.id()).update();
            case TRANSIENT_FAILURE -> {
                if (c.attempt() >= MAX_ATTEMPTS) {
                    jdbc.sql("update customer_messages set status = 'FAILED', last_error = :e, next_attempt_at = null where id = :id and status = 'NOT_SENT'").param("e", err).param("id", c.id()).update();
                } else {
                    Duration wait = BACKOFF[Math.min(c.attempt() - 1, BACKOFF.length - 1)];
                    jdbc.sql("update customer_messages set last_error = :e, next_attempt_at = now() + make_interval(secs => :s) where id = :id and status = 'NOT_SENT'")
                            .param("e", err).param("s", (double) wait.toSeconds()).param("id", c.id()).update();
                }
            }
        }
    }
}
