# ORLEU — Implementation Status

_Last updated: 2026-11-05. Everything below marked TESTED was actually executed: `./gradlew test` → 49 tests, 0 failures, against a real PostgreSQL 16 (local server; CI uses Testcontainers)._

## What this increment is
Backend foundation (modular Spring Boot 3.5 / Java 21 / PostgreSQL / Flyway) plus a first Flutter business app (`mobile/`). **No admin UI or public booking web page exists yet.** The product is NOT production-ready.

## IMPLEMENTED AND TESTED
| Area | Details |
|---|---|
| Auth | Register, login, refresh with rotation + reuse detection (revokes all sessions), logout, logout-all. Argon2id hashes, refresh tokens stored only as SHA-256, account lockout after 5 failures, uniform error for unknown user/wrong password, JWT access tokens (15 min, HS256). |
| Multi-tenancy | Memberships with per-business roles (OWNER, ADMIN, BRANCH_MANAGER, RECEPTIONIST, STAFF, ACCOUNTANT) → permissions. Every business endpoint goes through `TenantAccess.require`; non-members get 404 (no enumeration). All repository lookups are `...AndBusinessId`. Composite FKs make cross-tenant relations impossible even via raw SQL. `TenantIsolationIT` covers reads, writes, foreign ids inside own business, DB-level rejection, and multi-business users. |
| Business | Create (slug), settings (deposit %, auto-confirm, min notice, max advance, payment hold), publish (requires branch+hours+online service+assigned employee), members add/deactivate. |
| Catalog | Branches + weekly hours, services (duration, buffer, price, deposit override), employees with branch/service assignment, time off. |
| Plan limits | `subscription_plans` data (FREE: 1 branch/3 employees; PRO placeholder). `EntitlementService` enforces on backend (HTTP 402). |
| Availability | 15-min grid in the branch timezone; hours, duration, buffer, employee bookings, time off, min-notice/max-advance (online only). |
| Booking | State machine validated server-side; staff + public guest creation; any-employee assignment; reschedule; cancel frees slot; status history. **Double booking is prevented by a PostgreSQL exclusion constraint** — a 12-thread race test yields exactly one success. |
| Deposits & ledger | Decimal-safe deposit math (20,000 @ 30% = 6,000.00), append-only ledger (DB trigger), idempotency keys (concurrent retries charge once), overpayment/refund-limit checks, payment confirms booking when deposit reached, unpaid holds expire. Manual methods only (CASH, BANK_TRANSFER, CARD_MANUAL). |
| Analytics | Summary keeps booked value, collected, refunded, net, outstanding separate; cancellation/no-show rates. |
| Public API | Profile, availability, guest booking for published businesses; no PII in responses; existing customers not overwritten. |
| Flutter business app (`mobile/`) | Design tokens + light/dark themes (brand palette; secondary text darkened to pass WCAG AA — spec value was 4.1:1), kk/ru/en localization (identical key sets enforced by a test), Riverpod + GoRouter, Dio client with single-flight token refresh and secure token storage, adaptive navigation (bottom bar / rail). Screens wired to the real API: login, register, create business (first-run onboarding step), home (today's collected cash, bookings, pending, upcoming), calendar day view + booking details with backend-validated status actions, customers search, finance summary (booked value vs collected vs outstanding), more (language, theme, plan usage, sign out). Tested with an in-memory HTTP adapter plus a manual contract check against the running backend; **not run on a device/emulator.** |
| Public booking website | Mobile-first pages served by the backend: `/b/{slug}` (SEO title/description/OpenGraph from escaped business data; 5-step flow: service → location/specialist → date/time → details → review → confirmation) and `/m/{token}` (customer views/cancels via secret link). kk/ru/en, dark mode, no framework, DOM built with `textContent` only, strict CSP (no inline script/style), token page `no-store` + `no-referrer` + `noindex`. Verified by a **real Chromium end-to-end run** (`scripts/e2e-public-booking.js`: guest books, owner sees it with normalised phone, guest cancels via link, language switch, XSS probe inert) plus `PublicPagesIT`. Online deposit payment is NOT offered: the page tells the guest the business will arrange it. |
| Platform administration (API only) | Platform roles SUPER_ADMIN / PLATFORM_SUPPORT / PLATFORM_ANALYST on `users.platform_role`, checked against the DB on every call (revocation is immediate). `/api/v1/admin/**`: businesses list/search/detail with usage and subscription history, plan assignment with mandatory reason (+ optional expiry), suspend/reactivate (suspended tenants get 403 `BUSINESS_SUSPENDED`, public pages/booking vanish, reactivation does NOT republish), editable plan limits, audit-log viewer. Expiry job downgrades lapsed plans to FREE without deleting data. First SUPER_ADMIN via `ORLEU_BOOTSTRAP_ADMIN_EMAIL` (only when none exists). No impersonation exists by design. |
| Ops basics | Request-ID correlation, uniform error envelope (no stack traces), actuator health/readiness, OpenAPI, in-memory per-IP rate limit on auth/public POST, audit log table. App boot smoke-tested (health UP). |

## IMPLEMENTED BUT NOT TESTED
- `backend/Dockerfile`, `infrastructure/docker-compose.yml`, `.github/workflows/backend.yml` — no Docker daemon was available; never executed. Testcontainers path of the tests is likewise unexercised here.
- ECS JSON logging profile (`prod`) — enabled, output format not inspected.

## NOT IMPLEMENTED
Flutter: create-booking and reschedule UI, drag-and-drop, week/month calendar, service/employee/branch management screens, full onboarding (branch, hours, services, staff, publish), push notifications, deep links, offline cache, bundled Manrope/Inter font, Android/iOS builds and store release; Flutter Web admin; QR codes / embeddable widget / custom page branding / images / map link / reviews on the public page; OTP / phone login / password reset / MFA / invitations by e-mail; device-session UI; calendar views (API list endpoint only); employee-only visibility restriction for STAFF; CRM extras (tags, import/export, segments, duplicate merge, consent history); employee commissions/payouts; cash shifts/closing; refund approval workflow; invoices; automatic subscription billing (trial, grace period, renewal, proration, invoices, payment-failure recovery — plans are assigned manually by a super admin today); notifications (push/SMS/e-mail/in-app) and outbox; marketing, loyalty, referrals, gift cards, packages, memberships; reviews; support tickets; platform admin UI (Flutter Web), users/payments/support/reviews/abuse/feature-flag admin sections, support tickets; AI module; forecasting; recurring/group bookings, waitlists, resources/rooms; localization (kk/ru/en) resources; file storage (Cloudflare R2); Kubernetes manifests; load tests; backup/restore procedures; remaining docs from the original list.

## BLOCKED BY EXTERNAL DEPENDENCY
Real payment providers (FreedomPay, Kaspi, cards) need merchant accounts, official API docs and webhook secrets — no provider code or mock was written, to avoid presenting fake payments. SMS/e-mail/WhatsApp/push providers, Neon and R2 credentials likewise.

## Known limitations / production blockers
1. Rate limiter is per-instance memory; needs a shared limiter before multiple replicas.
2. No PostgreSQL row-level security (application + FK isolation only).
3. HS256 shared-secret JWT without key rotation; no secret-rotation procedure.
4. Public booking has no CAPTCHA/abuse controls beyond the IP limiter; customers cannot self-cancel yet.
5. Plan changes are manual (super-admin API); there is no billing, so nothing is charged.
6. No security review, penetration test, backup/restore test, load test or legal/privacy assessment (Kazakhstan personal-data law) has been done.
7. Migration V1 was edited during development; once any shared database exists, schema changes must be new Flyway versions.

## Environment variables
`ORLEU_DB_URL`, `ORLEU_DB_USER`, `ORLEU_DB_PASSWORD`, `ORLEU_JWT_SECRET` (≥32 bytes, required), `ORLEU_ALLOWED_ORIGINS`, `ORLEU_RATE_LIMIT_PER_MINUTE`, `ORLEU_API_DOCS_ENABLED`, `ORLEU_DB_POOL_SIZE`. Tests: `ORLEU_TEST_DB_URL/_USER/_PASSWORD`.

## Suggested next increments
1. Customer self-service links + notifications with transactional outbox. 2. Flutter management screens (services, employees, branches, create/reschedule booking) and full onboarding. 3. Public page extras (QR, widget, branding, reviews). 4. Subscription lifecycle + platform admin API. 5. Payment-provider adapter once credentials exist.
