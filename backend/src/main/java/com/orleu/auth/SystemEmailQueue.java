package com.orleu.auth;

import java.time.Duration;

/**
 * Where password-reset e-mails go when a message sender is configured. Defined in {@code auth} and implemented by the notifications module
 * (so auth does not depend on notifications). Absent when no sender is configured: then nothing is queued and nothing accumulates.
 */
public interface SystemEmailQueue {
    void enqueue(String email, String subject, String body, String purpose, Duration ttl);
}
