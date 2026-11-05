# Security notes (as implemented — not a certification)

No penetration test, formal security review or legal/privacy assessment has been done.

## Controls in place (each is covered by an automated test unless noted)
| Threat | Control |
|---|---|
| Cross-tenant data access | `TenantAccess` on every business endpoint; tenant-scoped finders; composite `(id, business_id)` FKs; non-members get 404. `TenantIsolationIT` |
| Privilege escalation | Per-business RBAC; owner cannot be assigned/removed via API; no self-service plan change; platform roles read from DB per request. `PlatformRulesIT`, `AdminIT` |
| Account takeover | Argon2id, lockout after 5 failures, uniform login errors, rotating refresh tokens with reuse detection (revoke-all), tokens hashed at rest. `AuthIT`. **No MFA, OTP or password reset yet.** |
| Double booking / booking manipulation | DB exclusion constraint; server computes price, deposit and status; state machine. `BookingFlowIT`, `ConcurrencyIT` |
| Payment replay / double charge | Idempotency keys (per business), per-booking row lock, append-only ledger trigger. `ConcurrencyIT`, `PlatformRulesIT` |
| XSS on public pages | `textContent`-only DOM building, escaped SEO meta, strict CSP (no inline script). `PublicPagesIT` + Chromium E2E |
| Secret-link leakage | Manage token 256-bit random, stored as SHA-256, page `no-store` + `no-referrer` + `noindex` |
| Suspended/abusive tenants | Super-admin suspension locks the tenant and removes public pages. `AdminIT` |
| Abuse of unauthenticated endpoints | Per-IP in-memory limiter (**single instance only**) |

## Known gaps
No PostgreSQL row-level security; HS256 shared-secret JWT without rotation; no CAPTCHA; no export/consent/data-deletion workflows; no webhook signature verification (no webhooks exist yet); no secret-rotation or backup/restore procedure; dependency scanning not automated.
