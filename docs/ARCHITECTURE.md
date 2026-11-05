# Architecture (as implemented)

Modular monolith, one Spring Boot app, packages by module under `com.orleu`: `auth`, `tenancy`, `business`, `catalog`, `customers`, `scheduling`, `bookings`, `payments`, `subscriptions`, `analytics`, `publicapi`, `audit`, `common`. Modules talk through services; read models use `JdbcClient`, writes use JPA. No automated module-dependency check exists yet.

## Key decisions
- **Double-booking**: `EXCLUDE USING gist (employee_id WITH =, tstzrange(starts_at, blocked_until) WITH &&) WHERE status IN (active)`. The Java availability check decides what to offer; the constraint is the final arbiter (race → 409 `SLOT_UNAVAILABLE`).
- **Tenant isolation**: `TenantAccess` + tenant-scoped finders + composite `(id, business_id)` foreign keys. Non-members receive 404.
- **Money**: `numeric(14,2)`/`BigDecimal`, HALF_UP; balances derived from the ledger. Ledger is append-only via trigger; idempotency key unique per business; per-booking row lock serializes money operations.
- **Time**: instants in UTC (`timestamptz`); slot calculation in the branch timezone.
- **Plan limits** live in `subscription_plans`, enforced in `EntitlementService`.
- **Auth**: stateless JWT access token + rotating opaque refresh token (hashed at rest).

## Threats considered (partial model)
Cross-tenant access → covered by tests. Booking manipulation → server-side price/deposit/state machine; clients cannot set status or price. Payment replay → idempotency keys. Account takeover → Argon2id, lockout, refresh-reuse detection (no MFA yet). Unauthorized export → no export endpoints exist yet.
