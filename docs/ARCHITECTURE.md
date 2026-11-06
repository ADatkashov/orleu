# Architecture (as implemented)

Modular monolith, one Spring Boot app, packages by module under `com.orleu`: `auth`, `tenancy`, `business`, `catalog`, `customers`, `scheduling`, `bookings`, `payments`, `subscriptions`, `analytics`, `publicapi`, `audit`, `notifications`, `reviews`, `support`, `admin`, `common`. Modules talk through services; read models use `JdbcClient`, writes use JPA.

## Enforced module boundaries (ArchUnit, `backend/src/test/java/com/orleu/arch/ArchitectureTest.java`)
These run in `./gradlew test` and therefore in CI: no cyclic dependencies between modules; `auth` depends on no business module (the `/me` endpoint that joins identity with memberships lives in `business`); `common` depends on no feature module; nothing depends on `publicapi` (the guest entry layer); controllers are not called by other classes; no field injection, `System.out`/`System.err` or `java.util.logging`. The cycle rule was red when introduced (auth ↔ business ↔ tenancy) and went green after the `/me` move. **Not enforced yet**: a layered rule between controller/service/repository inside a module, and "no uncontrolled shared database access" (modules still read each other's tables through `JdbcClient` in read models, e.g. analytics and admin).

## Key decisions
- **Double-booking**: `EXCLUDE USING gist (employee_id WITH =, tstzrange(starts_at, blocked_until) WITH &&) WHERE status IN (active)`. The Java availability check decides what to offer; the constraint is the final arbiter (race → 409 `SLOT_UNAVAILABLE`).
- **Tenant isolation**: `TenantAccess` + tenant-scoped finders + composite `(id, business_id)` foreign keys. Non-members receive 404.
- **Money**: `numeric(14,2)`/`BigDecimal`, HALF_UP; balances derived from the ledger. Ledger is append-only via trigger; idempotency key unique per business; per-booking row lock serializes money operations.
- **Time**: instants in UTC (`timestamptz`); slot calculation in the branch timezone.
- **Plan limits** live in `subscription_plans`, enforced in `EntitlementService`.
- **Auth**: stateless JWT access token + rotating opaque refresh token (hashed at rest).

## Threats considered (partial model)
Cross-tenant access → covered by tests. Booking manipulation → server-side price/deposit/state machine; clients cannot set status or price. Payment replay → idempotency keys. Account takeover → Argon2id, lockout, refresh-reuse detection (no MFA yet). Unauthorized export → no export endpoints exist yet.
