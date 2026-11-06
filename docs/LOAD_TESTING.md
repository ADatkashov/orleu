# Load testing (first measured baseline)

`scripts/load/load-test.js` is a dependency-free Node (18+) script. It seeds its own business through the public API
(1 branch, 3 specialists, 1 service, ~1 500 bookings spread over 60 days, up to 800 customers) and then drives six scenarios
at a fixed concurrency (default 16 virtual users, 4 s warm-up, 15 s measured per scenario):

| Scenario | What it exercises |
|---|---|
| public availability (GET) | slot computation for a random day, unauthenticated |
| public booking create (POST) | guest booking incl. customer upsert, price/deposit math, exclusion constraint, outbox write |
| staff calendar day (GET bookings) | tenant-scoped day list with joins |
| customer search (GET customers?q=) | CRM search |
| dashboard summary, 90 days (GET) | aggregate analytics over the ledger and bookings |
| analytics breakdown by service (GET) | grouped report |

```
BASE=http://localhost:8080 [VUS=16] [DURATION=15] [WARMUP=4] [BOOKINGS=1500] [CUSTOMERS=800] [OUT=results.md] node scripts/load/load-test.js
```
Start the backend with `ORLEU_RATE_LIMIT_PER_MINUTE=1000000`, otherwise the per-IP limiter (60/min, by design) rejects the public booking scenario.
The script exits non-zero if any scenario other than "booking create" returns a non-2xx response.

## Baseline (2026-11-06, one run)
Environment: **one 4-vCPU cloud sandbox running everything** — the Node load generator, the backend (`java -Xmx1g -jar`, Java 21,
default Hikari pool) and PostgreSQL 16 (default configuration, local socket/loopback, no network latency, no TLS, no CDN).
Data when the scenarios ran: 1 business, ~1 500 → 3 900 bookings (the booking scenario adds some), ~3 200 customers.

| Scenario | Requests | req/s | p50 ms | p95 ms | p99 ms | max ms | Status codes |
|---|---|---|---|---|---|---|---|
| public availability (GET) | 14476 | 964.7 | 14.9 | 33.3 | 45.2 | 100.8 | 200×14476 |
| public booking create (POST) | 10804 | 719.7 | 20.9 | 38.3 | 48.4 | 77.4 | 201×1070, 409×9734 |
| ↳ 2xx responses only | 1070 | | 29.1 | 47.6 | 62.2 | | |
| staff calendar day (GET bookings) | 14129 | 941.6 | 11.5 | 55.4 | 79.8 | 390.2 | 200×14129 |
| customer search (GET customers?q=) | 21392 | 1425.2 | 10.1 | 21.5 | 28.6 | 64.2 | 200×21392 |
| dashboard summary, 90 days (GET) | 5902 | 392.9 | 39.1 | 61.1 | 73.1 | 203.4 | 200×5902 |
| analytics breakdown by service (GET) | 13976 | 931 | 16 | 31.5 | 40.4 | 86.9 | 200×13976 |

## How to read this honestly
- **It is a baseline for regression comparison on the same kind of machine, not a capacity claim.** The load generator competes with the
  server for the same 4 CPUs, there is no network, TLS or proxy in between, and the data set is small. Production (Neon over the network,
  TLS, several clients) will be slower per request; no statement about concurrent users or SLA follows from these numbers.
- **Run-to-run variance is large.** An earlier, partly invalid run of the same script (its booking scenario sent out-of-window dates and got only 409s, so it
  left the data set smaller) measured the calendar-day scenario at ~1 850 req/s and the dashboard at ~750 req/s versus 940 and 390 above. Single
  runs on a shared machine cannot support differences smaller than roughly a factor of two; compare medians of several runs before drawing conclusions.
- **Booking create:** with 16 users hammering ~4 000 slots the scenario quickly saturates the calendar, so most responses are 409 (the
  exclusion constraint / availability check doing its job). The "2xx only" row is the latency of successful bookings.
- **Expected-conflict noise:** when two concurrent requests pick the same free slot, PostgreSQL rejects the second with
  `bookings_no_employee_overlap` and the API answers 409 correctly, but Hibernate logs the SQL error at `ERROR` level (11 lines in this run).
  Alerting must not page on that message; the 409 rate is the useful signal.
- No errors other than those conflicts were logged; no 5xx responses occurred.
- Not measured: sustained soak (minutes–hours), memory/GC behaviour, connection-pool saturation, multi-instance behaviour (the rate limiter is per
  instance), large tenants (100k+ bookings), mobile app startup, Neon cold starts, backup impact.

## Next steps
Repeat the run 3–5 times and publish medians; run the generator on a separate machine; seed a 100k-booking tenant and look at `EXPLAIN` for the
dashboard and calendar queries (the dashboard summary is the slowest scenario); add a CI job that runs the script with a fixed seed and fails on a
large regression only after a stable baseline exists on the runner type used.
