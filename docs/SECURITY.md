# Security notes (as implemented — not a certification)

No penetration test, formal security review or legal/privacy assessment has been done.

## Controls in place (each is covered by an automated test unless noted)
| Threat | Control |
|---|---|
| Cross-tenant data access | `TenantAccess` on every business endpoint; tenant-scoped finders; composite `(id, business_id)` FKs; non-members get 404. `TenantIsolationIT` |
| Privilege escalation | Per-business RBAC; owner cannot be assigned/removed via API; no self-service plan change; platform roles read from DB per request. `PlatformRulesIT`, `AdminIT` |
| Account takeover | Argon2id, lockout after 5 failures, uniform login errors, rotating refresh tokens with reuse detection (revoke-all), tokens hashed at rest. `AuthIT`. Password reset/change and session revocation exist (reset delivery needs a mail provider). **TOTP MFA** (RFC 6238, authenticator apps): secret encrypted at rest (AES-256-GCM), single-use time steps (replay rejected), 10 hashed single-use recovery codes, opaque 5-minute challenge token (never a JWT, so it cannot be used as an access token) limited to 5 attempts and counted towards the account lockout, disabling needs password + code; optional enforcement for platform roles (`ORLEU_REQUIRE_MFA_FOR_PLATFORM=true`, **set it in production**). `MfaIT`, `MfaPlatformIT`, `TotpTest` (RFC vectors). MFA is opt-in for business users; no SMS/OTP login, no passkeys. |
| Double booking / booking manipulation | DB exclusion constraint; server computes price, deposit and status; state machine. `BookingFlowIT`, `ConcurrencyIT` |
| Payment replay / double charge | Idempotency keys (per business), per-booking row lock, append-only ledger trigger. `ConcurrencyIT`, `PlatformRulesIT` |
| XSS on public pages | `textContent`-only DOM building, escaped SEO meta, strict CSP (no inline script). `PublicPagesIT` + Chromium E2E |
| Secret-link leakage | Manage token 256-bit random, stored as SHA-256, page `no-store` + `no-referrer` + `noindex` |
| Suspended/abusive tenants | Super-admin suspension locks the tenant and removes public pages. `AdminIT` |
| Abuse of unauthenticated endpoints | Per-IP in-memory limiter (**single instance only**) |

## Known gaps
MFA secrets are encrypted with a key from configuration (`ORLEU_MFA_KEY`, else derived from the JWT secret); rotating that key is not implemented (existing secrets would become undecryptable), and the admin console has no MFA enrolment screen (staff enrol in the business app). No "suspicious login" detection or login history screen. No PostgreSQL row-level security; HS256 shared-secret JWT without rotation; no CAPTCHA; no export/consent/data-deletion workflows; no webhook signature verification (no webhooks exist yet); no secret-rotation or backup/restore procedure; dependency update PRs are automated by Dependabot (`.github/dependabot.yml`; enabling alerts/security updates in the repository settings is the owner's step), but there is no SAST, no container-image scan and no secret scanning in CI.
