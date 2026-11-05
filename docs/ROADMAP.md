# ORLEU roadmap (source of truth for "what next")

The owner's original specification is saved **verbatim** in `docs/roadmap/PROMPT_1_MASTER.md` (main spec, sections 1–35)
and `docs/roadmap/PROMPT_2_ADDENDUM.md` (addendum, delivery phases, the 7 pre-launch directions). This file maps every
requirement to its current status; `docs/IMPLEMENTATION_STATUS.md` holds the technical detail and limitations.
Update both after every merged increment. Status words: **DONE** (implemented and verified by automated tests/CI),
**PARTIAL**, **TODO**, **BLOCKED** (needs the owner's external accounts/credentials/legal decision).

_Last updated: 2026-11-05._

## Working agreement (from the owner)
- Choose the next most valuable item yourself; merge when CI is green (see `CLAUDE.md`). Ask only for external accounts/credentials or irreversible actions.
- Real vertical slices UI → API → DB with tests; never fake payments, providers or statistics; report limitations honestly.
- Fixed choices: Flutter + Spring Boot 3 / Java 21 + PostgreSQL (Neon) modular monolith, Cloudflare R2, GitHub Actions (self-hosted compatible), Docker/Kubernetes-ready, **no Redis** without measured need, **no Codemagic**, no secrets in the repo, KZT / Asia/Almaty / kk-ru-en defaults.
- ORLEU is a **working** brand: trademark/domain/store-name availability in Kazakhstan is unverified and must be decided before launch.

## Definition of Done (spec §34)
| | Requirement | Status | Notes |
|---|---|---|---|
| A | Owner registers and creates a business | DONE | API + app |
| B | Configure branches, hours, services, employees | DONE | app + API (no edit/delete yet) |
| C | Publish a public booking page | DONE | `/b/{slug}` |
| D | Customer books without installing the app | DONE | real-browser E2E in CI |
| E | Double booking prevented | DONE | DB exclusion constraint, 12-thread race test |
| F | Confirm, reschedule, cancel, complete | DONE | staff in app; customer cancel by link |
| G | Deposit through a provider or an identified sandbox | **BLOCKED / PARTIAL** | manual payments only; provider adapters need FreedomPay/Kaspi accounts + official docs |
| H | Remaining balance visible | DONE | |
| I | Manage customers and employees | PARTIAL | backend DONE (customer profile + stats, edit; branch/service/specialist edit + deactivate); app screens for them are the next step; no tags/import/export/segments |
| J | Meaningful financial/booking analytics | PARTIAL | summary + finance screen; no charts, per-employee/service/branch breakdowns |
| K | Subscription entitlements enforced by backend | DONE | limits; billing lifecycle is TODO |
| L | Tenant isolation covered by tests | DONE | |
| M | Flutter app: auth, navigation, localization, API | PARTIAL | no password-reset/OTP screens, not run on a device |
| N | Admin interface manages platform entities | PARTIAL | businesses, plans, audit; no users/payments/support/reviews |
| O | CI builds and tests run | DONE | backend, e2e, docker-smoke, backup-restore, mobile |

## Phases (spec addendum §14)
### Phase 1 — Foundation: DONE (with gaps)
Auth, multi-tenancy, onboarding (create business → setup checklist → publish), branches/hours, services, employees, scheduling, bookings: DONE.
Gaps: OTP/phone login, MFA, e-mail invitations, branch-level permissions, employee shifts/breaks/holidays, service images, per-employee prices, onboarding templates per business type, branding settings.

### Phase 2 — Commercial core: PARTIAL
- DONE: deposits (decimal-safe), immutable ledger, manual payments/refunds with idempotency, plans + entitlements, outbox + in-app notifications.
- PARTIAL: CRM (basic customer records), subscription lifecycle (manual plan assignment, expiry → FREE).
- TODO: promo codes/discounts, partial-refund approval workflow, reconciliation, invoices/receipts, trial/grace/renewal/proration, usage metering, notification templates kk/ru/en, reminders before appointments.
- BLOCKED: payment providers, SMS/e-mail/WhatsApp/push delivery.

### Phase 3 — Operations: PARTIAL
- DONE: calendar day view + actions, public booking page, platform admin (core), customer self-cancel.
- TODO: week/month calendar, employee/branch calendars and filters, drag-and-drop, analytics charts, staff performance, customer portal (history, reschedule, favourites), reviews and ratings, support tickets, reconciliation views.

### Phase 4 — Business growth: TODO
Marketing campaigns, loyalty, referrals, gift cards, packages, memberships, QR codes, widgets, promo landing pages (consent rules apply).

### Phase 5 — Advanced platform: TODO
AI assistant (only with real testable use cases), forecasting (labelled estimates), integrations registry (calendar, accounting export, maps, WhatsApp), automation, more locales/currencies.

## Cross-cutting requirements
| Area | Status |
|---|---|
| Tests (backend integration, concurrency, tenant isolation, Flutter widget, real-browser E2E) | DONE, growing |
| Load tests (availability, booking, calendar, customer search, dashboard) | TODO |
| Migration tests beyond "applies from scratch and Flyway validates" | PARTIAL |
| Security: threat model | PARTIAL (`docs/SECURITY.md`); MFA, webhook signing/replay protection, file upload validation, secret rotation, data retention, export authorization: TODO |
| PostgreSQL row-level security | TODO (decision: defence in depth, not a replacement) |
| Observability: JSON logs, request ids, health/readiness DONE; metrics scraping, alerting, error tracking, APM: TODO |
| Backup/restore verified | DONE for the logical path (`docs/BACKUP_AND_RECOVERY.md`); Neon PITR drill, production-size timing, backup encryption: TODO/BLOCKED |
| Docker/compose | DONE (CI smoke test); Kubernetes manifests written, cluster-untested; image registry publishing TODO |
| Flutter design system, kk/ru/en localization | DONE for implemented screens; bundled Inter/Manrope font TODO; screen-reader/dynamic-text audit TODO |
| Mobile quality: deep links, push, offline cache, device sessions UI, store builds, crash reporting | TODO |
| Documentation set (spec §32) | PARTIAL: `IMPLEMENTATION_STATUS`, `SECURITY`, `ARCHITECTURE`, `DEPLOYMENT`, `OPERATIONS`, `BACKUP_AND_RECOVERY` exist; the other listed files are not written (write each when the area has real content, never from imagination) |
| Architecture checks (no cyclic module deps) | TODO (ArchUnit) |
| Privacy: consent history, data export, account deletion, retention | TODO; legal review required before any compliance claim |

## The 7 pre-launch directions (addendum follow-up)
| # | Direction | Status |
|---|---|---|
| 1 | Legal & compliance (terms, privacy policy, consents, retention) | TODO — needs legal review; consent capture on public booking exists only as a marketing opt-in checkbox |
| 2 | Localization (dates, times, phones, currencies, addresses, timezones) | PARTIAL — kk/ru/en UI, E.164 +7 phones, KZT formatting, business-timezone times; address formats, other currencies TODO |
| 3 | Data import (Excel/CSV) | TODO |
| 4 | Customer acquisition (SEO, referral links, landing pages, business registration) | PARTIAL — SEO meta on booking pages; rest TODO |
| 5 | Platform economics (CAC, LTV, MRR, ARR, churn, conversion) | TODO — needs billing first |
| 6 | Product analytics (onboarding funnel, adoption, retention) | TODO |
| 7 | Release engineering (App Store / Play, crash reporting, staged rollout, rollback) | TODO / BLOCKED on store accounts |

## Kazakhstan-specific
Personal-data law review (TODO, legal), KZT + other currencies (KZT DONE), real payment integrations (BLOCKED), local SMS and numbers (E.164 DONE; SMS BLOCKED), Kazakhstan document/address formats (TODO), accounting export (TODO). No claim of fiscal-receipt/tax compliance is made anywhere.

## Next up (my ordering; revisit after each merge)
1. Customer CRM profile + visit history (app + API) and employee/service edit/delete — closes DoD I.
2. Analytics breakdowns and charts (by employee/service/branch, peak hours) — closes DoD J.
3. Reminders and notification templates (kk/ru/en) behind the existing outbox; provider-specific senders stay BLOCKED.
4. Password-reset / change-password / sessions screens in the app — closes DoD M.
5. Week/month calendar and filters.
6. Reviews + customer portal; support tickets + admin sections (users, support).
7. Load-test scenarios and a first measured baseline; ArchUnit checks.
8. When the owner provides accounts: payment provider adapter (sandbox first), e-mail/SMS provider, Neon/R2.
