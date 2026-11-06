package com.orleu.auth;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

/**
 * Sign-in history for the account owner: successes, failed passwords/codes and lockouts, with IP and device. A successful sign-in from a
 * device kind the user has not signed in from before is flagged `newDevice` (the first sign-in ever is not). The "device" is the user agent
 * without version numbers, so app/browser updates do not look like new devices; it is a hint, not proof of identity. Events are kept 90 days.
 * No e-mail/SMS alert is sent (no provider): the flag is shown in the app.
 */
@Service
public class LoginHistoryService {
    static final int RETENTION_DAYS = 90;

    public enum Outcome { SUCCESS, FAILED_PASSWORD, FAILED_MFA, LOCKED }

    public record Event(UUID id, String outcome, boolean mfaUsed, String ip, String userAgent, boolean newDevice, Instant occurredAt) {}
    public record History(List<Event> events, int failedSinceLastSuccess, boolean newDeviceRecently) {}

    private final JdbcClient jdbc;

    public LoginHistoryService(JdbcClient jdbc) { this.jdbc = jdbc; }

    /** @return true if this successful sign-in came from a device kind not seen before for this user. */
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRED, noRollbackFor = RuntimeException.class)
    public boolean record(UUID userId, Outcome outcome, boolean mfaUsed, String ip, String userAgent) {
        String ua = userAgent == null ? "" : userAgent.substring(0, Math.min(300, userAgent.length()));
        String key = deviceKey(ua);
        boolean newDevice = false;
        if (outcome == Outcome.SUCCESS) {
            boolean everSignedIn = jdbc.sql("select exists(select 1 from login_events where user_id = :u and outcome = 'SUCCESS')").param("u", userId).query(Boolean.class).single();
            boolean knownDevice = jdbc.sql("select exists(select 1 from login_events where user_id = :u and outcome = 'SUCCESS' and device_key = :k)")
                    .param("u", userId).param("k", key).query(Boolean.class).single();
            newDevice = everSignedIn && !knownDevice;
        }
        jdbc.sql("insert into login_events (user_id, outcome, mfa_used, ip, user_agent, device_key, new_device) values (:u, :o, :m, :ip, :ua, :k, :n)")
                .param("u", userId).param("o", outcome.name()).param("m", mfaUsed).param("ip", ip == null ? null : ip.substring(0, Math.min(45, ip.length())), java.sql.Types.VARCHAR)
                .param("ua", ua.isEmpty() ? null : ua, java.sql.Types.VARCHAR).param("k", key).param("n", newDevice).update();
        return newDevice;
    }

    @Transactional(readOnly = true)
    public History history(UUID userId) {
        List<Event> events = jdbc.sql("select id, outcome, mfa_used, ip, user_agent, new_device, occurred_at from login_events where user_id = :u order by occurred_at desc, id limit 50")
                .param("u", userId).query((rs, i) -> new Event(rs.getObject(1, UUID.class), rs.getString(2), rs.getBoolean(3), rs.getString(4), rs.getString(5),
                        rs.getBoolean(6), rs.getTimestamp(7).toInstant())).list();
        int failed = 0;
        for (Event e : events) { if (e.outcome().equals("SUCCESS")) break; if (!e.outcome().equals("LOCKED")) failed++; }
        boolean recentNew = events.stream().anyMatch(e -> e.newDevice() && e.occurredAt().isAfter(Instant.now().minusSeconds(7 * 86400)));
        return new History(events, failed, recentNew);
    }

    /** Daily retention job. */
    @Scheduled(fixedDelayString = "${orleu.jobs.login-history-purge-interval:PT24H}", initialDelayString = "PT10M")
    @Transactional
    public int purgeOld() {
        return jdbc.sql("delete from login_events where occurred_at < now() - make_interval(days => :d)").param("d", RETENTION_DAYS).update();
    }

    static String deviceKey(String userAgent) {
        String normalized = userAgent.toLowerCase().replaceAll("[0-9._]+", "").trim();
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(normalized.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
}
