package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

class ConcurrencyIT extends AbstractIT {
    @Test void twelveSimultaneousGuestsCompeteForOneSlotExactlyOneWins() throws Exception {
        Fixture f = Fixture.create(this, 1, true);
        int n = 12;
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Integer>> results = new ArrayList<>();
        AtomicInteger seq = new AtomicInteger(100);
        for (int i = 0; i < n; i++) {
            final String phone = "+7701000" + (1000 + seq.incrementAndGet());
            results.add(pool.submit(() -> {
                go.await();
                return post(null, "/api/v1/public/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                        "startsAt", at(bookingDate(), 15, 0).toString(),
                        "customer", Map.of("fullName", "Guest", "phone", phone)), f.slug).status();
            }));
        }
        go.countDown();
        int created = 0, conflict = 0;
        for (Future<Integer> r : results) {
            int s = r.get(60, TimeUnit.SECONDS);
            if (s == 201) created++; else if (s == 409) conflict++; else fail("unexpected status " + s);
        }
        pool.shutdown();
        assertEquals(1, created);
        assertEquals(n - 1, conflict);
        assertEquals(1, jdbc.queryForObject("select count(*) from bookings where employee_id = ? and status <> 'CANCELLED'", Integer.class, f.employeeId));
    }

    @Test void concurrentRetriesOfOnePaymentChargeOnce() throws Exception {
        Fixture f = Fixture.create(this, 1, false);
        var b = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), 10, 0).toString(), "customer", f.customer("+77010009999")), f.businessId);
        int n = 8;
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Integer>> rs = new ArrayList<>();
        for (int i = 0; i < n; i++) rs.add(pool.submit(() -> {
            go.await();
            return call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + b.id() + "/payments"),
                    f.ownerToken, Map.of("amount", "20000", "method", "CASH"), "Idempotency-Key", "same-key").status();
        }));
        go.countDown();
        for (Future<Integer> r : rs) assertEquals(201, r.get(60, TimeUnit.SECONDS));
        pool.shutdown();
        assertEquals(1, jdbc.queryForObject("select count(*) from ledger_entries where booking_id = ?", Integer.class, b.id()));
    }
}
