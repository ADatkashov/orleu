package com.orleu.notifications;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

/** Queues a short-lived system message for delivery by {@link MessageDispatcher}. Only the dispatcher reads the body. */
@Service
@org.springframework.boot.autoconfigure.condition.ConditionalOnExpression("'${orleu.messaging.provider:none}' != 'none'")
public class SystemMessageService implements com.orleu.auth.SystemEmailQueue {
    private final JdbcClient jdbc;

    public SystemMessageService(JdbcClient jdbc) { this.jdbc = jdbc; }

    @Override
    public void enqueue(String email, String subject, String body, String purpose, Duration ttl) { enqueue("EMAIL", email, subject, body, purpose, ttl); }

    public UUID enqueue(String channel, String recipient, String subject, String body, String purpose, Duration ttl) {
        return jdbc.sql("""
            insert into system_messages (channel, recipient, subject, body, purpose, expires_at) values (:c, :r, :s, :b, :p, :e) returning id
            """).param("c", channel).param("r", recipient).param("s", subject, java.sql.Types.VARCHAR).param("b", body).param("p", purpose)
                .param("e", Timestamp.from(Instant.now().plus(ttl))).query(UUID.class).single();
    }
}
