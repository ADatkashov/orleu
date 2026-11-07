package com.orleu.it;

import com.orleu.notifications.MessageDispatcher;
import com.orleu.notifications.OutboxProcessor;
import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

class MessageDispatchIT extends AbstractIT {
    @Autowired OutboxProcessor processor;
    @Autowired MessageDispatcher dispatcher;

    @org.junit.jupiter.api.BeforeEach void clearForeignBacklog() { jdbc.update("delete from outbox_events where status = 'PENDING'"); }

    /** Creates a booking for the phone and returns the id of its first prepared message. */
    private UUID message(Fixture f, int hour, String phone) {
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), hour, 0).toString(), "customer", Map.of("fullName", "Msg", "phone", phone)), f.businessId).status());
        processor.processDue();
        return jdbc.queryForObject("select id from customer_messages where business_id = ? and recipient_phone = ? order by created_at limit 1", UUID.class, f.businessId, phone);
    }

    private String status(UUID id) { return jdbc.queryForObject("select status from customer_messages where id = ?", String.class, id); }
    private int attempts(UUID id) { return jdbc.queryForObject("select attempts from customer_messages where id = ?", Integer.class, id); }
    private void makeDue(UUID id) { jdbc.update("update customer_messages set next_attempt_at = now() - interval '1 second' where id = ?", id); }

    @Test void aFakeSenderMarksMessagesSentAndNothingIsSentTwice() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = message(f, 10, "+77010021111");
        assertEquals("NOT_SENT", status(id));
        dispatcher.dispatchDue(1000);
        assertEquals("SENT", status(id));
        assertTrue(jdbc.queryForObject("select provider_message_id from customer_messages where id = ?", String.class, id).startsWith("fake-"));
        assertNotNull(jdbc.queryForObject("select sent_at from customer_messages where id = ?", java.sql.Timestamp.class, id));
        dispatcher.dispatchDue(1000);
        assertEquals(1, attempts(id), "a SENT message is never picked up again");
    }

    @Test void permanentFailureIsFinalAndStaffCanRetryIt() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = message(f, 10, "+77010020000");
        dispatcher.dispatchDue(1000);
        assertEquals("FAILED", status(id));
        assertEquals("fake: number rejected", jdbc.queryForObject("select last_error from customer_messages where id = ?", String.class, id));
        dispatcher.dispatchDue(1000);
        assertEquals(1, attempts(id), "no automatic retry of a permanent failure");

        assertEquals(204, post(f.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages/%s/retry", Map.of(), f.businessId, id).status());
        assertEquals("NOT_SENT", status(id));
        assertEquals(0, attempts(id));
        assertEquals(409, post(f.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages/%s/retry", Map.of(), f.businessId, id).status(), "only FAILED messages can be retried");
    }

    @Test void transientFailuresBackOffThenGiveUpAfterFourAttempts() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = message(f, 10, "+77010020001");
        for (int attempt = 1; attempt <= 3; attempt++) {
            dispatcher.dispatchDue(1000);
            assertEquals("NOT_SENT", status(id), "attempt " + attempt);
            assertEquals(attempt, attempts(id));
            assertTrue(jdbc.queryForObject("select next_attempt_at > now() from customer_messages where id = ?", Boolean.class, id), "waits before the next attempt");
            dispatcher.dispatchDue(1000);
            assertEquals(attempt, attempts(id), "not due yet, so not attempted");
            makeDue(id);
        }
        dispatcher.dispatchDue(1000);
        assertEquals("FAILED", status(id));
        assertEquals(4, attempts(id));
    }

    @Test void aMessageThatRecoversIsSentOnALaterAttempt() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = message(f, 10, "+77010020002");
        for (int i = 0; i < 2; i++) { dispatcher.dispatchDue(1000); assertEquals("NOT_SENT", status(id)); makeDue(id); }
        dispatcher.dispatchDue(1000);
        assertEquals("SENT", status(id));
        assertEquals(3, attempts(id));
    }

    @Test void concurrentDispatchersAttemptEachMessageOnce() throws Exception {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = message(f, 10, "+77010022222");
        ExecutorService pool = Executors.newFixedThreadPool(4);
        CountDownLatch go = new CountDownLatch(1);
        var futures = new java.util.ArrayList<Future<?>>();
        for (int i = 0; i < 4; i++) futures.add(pool.submit(() -> { go.await(); dispatcher.dispatchDue(1000); return null; }));
        go.countDown();
        for (var fu : futures) fu.get(30, TimeUnit.SECONDS);
        pool.shutdown();
        assertEquals("SENT", status(id));
        assertEquals(1, attempts(id), "SKIP LOCKED plus the lease: one sender call per message");
    }

    @Test void statusEndpointShowsTestModeAndRetryIsTenantIsolatedAndPermissioned() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        var st = get(f.ownerToken, "/api/v1/businesses/%s/notifications/messaging/status", f.businessId).body();
        assertEquals("FAKE", st.path("provider").asText());
        assertTrue(st.path("testMode").asBoolean());
        UUID id = message(f, 10, "+77010020000");
        dispatcher.dispatchDue(1000);
        assertEquals(404, post(other.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages/%s/retry", Map.of(), other.businessId, id).status(), "another business's message");
        String staff = newUser("staffmsg");
        post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(staff, "/api/v1/me").text("email"), "role", "STAFF"), f.businessId);
        assertEquals(403, post(staff, "/api/v1/businesses/%s/notifications/customer-messages/%s/retry", Map.of(), f.businessId, id).status());
        var m = get(f.ownerToken, "/api/v1/businesses/%s/notifications/customer-messages", f.businessId).body().get(0);
        assertEquals("FAILED", m.path("status").asText());
        assertEquals("SMS", m.path("channel").asText());
    }

    @Test void theFakeSenderRefusesToStartInTheProdProfile() {
        var cfg = new com.orleu.notifications.MessagingConfig();
        var prod = new org.springframework.mock.env.MockEnvironment();
        prod.setActiveProfiles("prod");
        assertThrows(IllegalStateException.class, () -> invoke(cfg, prod));
        assertNotNull(invoke(cfg, new org.springframework.mock.env.MockEnvironment()));
    }

    private static Object invoke(Object cfg, org.springframework.core.env.Environment env) {
        try {
            var m = cfg.getClass().getDeclaredMethod("fakeMessageSender", org.springframework.core.env.Environment.class);
            m.setAccessible(true);
            return m.invoke(cfg, env);
        } catch (java.lang.reflect.InvocationTargetException e) {
            throw (RuntimeException) e.getCause();
        } catch (ReflectiveOperationException e) { throw new IllegalStateException(e); }
    }
}
