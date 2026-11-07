# Deployment

## Artifacts (all built in CI)
| Artifact | Built by | Verified by |
|---|---|---|
| Backend jar / Docker image `backend/Dockerfile` | `backend.yml`, `docker.yml` | 87 integration tests on PostgreSQL; compose smoke test (health, 401/404, register, non-root, healthcheck) |
| Flutter mobile app (Android/iOS) | **not built** (only web builds run in CI) | unit/widget tests only |
| Flutter web: business app, admin console | `mobile.yml` | analyze + tests + release build |
| Kubernetes manifests `infrastructure/k8s/` | — | YAML-validated only; **never applied to a cluster** |

## Configuration (environment variables; never commit values)
| Variable | Required | Meaning |
|---|---|---|
| `ORLEU_DB_URL`, `ORLEU_DB_USER`, `ORLEU_DB_PASSWORD` | yes | PostgreSQL (Neon: use the pooled or direct endpoint with `sslmode=require`) |
| `ORLEU_JWT_SECRET` | yes | ≥ 32 bytes random; the app refuses to start without it. Changing it signs everyone out |
| `ORLEU_ALLOWED_ORIGINS` | if web apps are served from another origin | comma-separated CORS origins (empty = none) |
| `ORLEU_MESSAGING_PROVIDER` | optional | `none` (default; prepared messages stay NOT_SENT) or `fake` (TEST mode, nothing is delivered). `fake` is **refused at startup in the prod profile**. A real SMS/e-mail provider adapter does not exist yet |
| `ORLEU_BOOTSTRAP_ADMIN_EMAIL` | first deploy only | promotes this existing user to SUPER_ADMIN when no super admin exists |
| `ORLEU_RATE_LIMIT_PER_MINUTE` | no (60) | per-IP limit on auth/public POST; **in-memory, per instance** |
| `ORLEU_API_DOCS_ENABLED` | no (true) | set `false` in production to hide Swagger UI |
| `ORLEU_DB_POOL_SIZE` | no (10) | Hikari pool size |
| `SPRING_PROFILES_ACTIVE=prod` | recommended | structured JSON logs |
| `orleu.mail.provider` | never `log` in prod | `log` writes password-reset tokens to the log (development only) |

Build the web apps with `--dart-define=ORLEU_API_URL=https://api.example` (and `ORLEU_PUBLIC_URL` for the booking-link host).

## Environments
LOCAL (`infrastructure/docker-compose.yml`), TEST/STAGING/PRODUCTION must each have their own database, JWT secret and secrets store. No environment is provisioned by this repository; nothing deploys automatically.

## Release procedure (manual)
1. CI green on the release commit (backend, e2e, docker-smoke, mobile).
2. `scripts/backup.sh` against the target database (see BACKUP_AND_RECOVERY.md).
3. Deploy the new image; Flyway runs on startup. Wait for `/actuator/health/readiness` = UP.
4. Smoke test: sign in, open a public booking page, create and cancel a test booking.
5. Rollback: redeploy the previous image if the schema change was backward compatible; otherwise restore (see BACKUP_AND_RECOVERY.md).

## Known production blockers
Single-instance rate limiter (run **one replica** until a shared limiter exists); no TLS termination, WAF, secret manager or log shipping is defined here; no monitoring/alerting is configured; mobile store builds, push notifications, and payment/e-mail/SMS providers do not exist.
