# Operations

## Health and metrics
- Liveness `/actuator/health/liveness`, readiness `/actuator/health/readiness` (includes the database), `/actuator/health`. Only health/info are exposed over HTTP (health is public for probes without component details; verified by a test). **Metrics are deliberately not exposed** until a scraper-only authenticated path exists, so there are no dashboards/alerts yet.
- Logs: console; with `SPRING_PROFILES_ACTIVE=prod` they are structured JSON (ECS). Every request has an `X-Request-Id` (generated if absent) echoed in the response and in error bodies (`correlationId`) — ask users for it. Passwords, tokens and card data are never logged by the application code (password-reset tokens are logged **only** with the dev-only `orleu.mail.provider=log`).
- Audit trail: table `audit_logs` (logins, lockouts, role/plan/suspension changes, payments, refunds, password changes) and the admin console's Audit log.

## Background jobs (single instance safe; multi-instance safe by design)
| Job | Interval | Purpose | Failure behaviour |
|---|---|---|---|
| Outbox processor | 5 s | delivers in-app notifications | per-event transaction, exponential backoff, dead-letter after 5 attempts (`outbox_events.status = 'DEAD'`) |
| Booking hold expiry | 1 min | frees unpaid deposit holds | idempotent; errors logged, next run retries |
| Subscription expiry | 10 min | downgrades lapsed plans to FREE | idempotent |

Dead letters need a human: `select * from outbox_events where status = 'DEAD'`; fix the cause, then `update outbox_events set status='PENDING', attempts=0, next_attempt_at=now() where id = ...`.

## Incident basics
| Symptom | First checks |
|---|---|
| 5xx / readiness DOWN | database reachable? pool exhausted (`hikaricp` metrics)? recent migration? logs by `correlationId` |
| Users cannot sign in | account locked (429 `ACCOUNT_LOCKED`, 15 min) vs wrong password; JWT secret changed (everyone gets 401) |
| Booking page 404 | business unpublished or suspended (`businesses.status`, `published`) |
| 402 on adding staff/branches | plan limits (`subscription_plans`) — expected; platform admin can change plan |
| Double-booking suspected | impossible at DB level (`bookings_no_employee_overlap`); look for a different employee/branch |
| Notifications missing | `outbox_events` pending/dead rows |

## Not in place
Alerting/paging, uptime monitoring, error tracking (Sentry etc.), log retention policy, capacity monitoring, on-call process, SLA, formal incident-response runbook beyond this table, load tests (`scripts/` has none yet).
