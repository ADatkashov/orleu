# Backup and recovery

## What is verified
`scripts/verify-restore.sh` (run in CI by `.github/workflows/backup-restore.yml` and run manually in the authoring environment) proves the **logical backup/restore path** end to end on a real PostgreSQL 16:

1. `scripts/backup.sh` → custom-format `pg_dump` + SHA-256 file, owner-only permissions (`600`).
2. `scripts/restore.sh` → refuses a corrupted dump (checksum mismatch) and refuses a non-empty target database.
3. Exact row counts of **every** table match between source and restored database; Flyway history is intact.
4. The real application boots on the restored database (Flyway validation passes, `/actuator/health` is UP) and a user registered before the backup can sign in.

## What is NOT verified
- Neon-specific features (branching / point-in-time restore): documented below from the product's design, **never exercised** here (no Neon credentials).
- Restore time on production-size data; backup of Cloudflare R2 objects (no file storage is implemented yet); disaster recovery to another region; encryption of backups at rest (the scripts only restrict file permissions — encrypt the storage location).

## Targets (not measured guarantees)
| | Target | Basis |
|---|---|---|
| RPO | ≤ 24 h with nightly logical backups; minutes with Neon point-in-time restore if enabled on the plan | design target, unmeasured |
| RTO | ≤ 2 h | restore of a small database takes seconds in tests; production size unmeasured |

Do not quote these numbers to customers until a restore drill on production-sized data has been timed.

## Procedures
**Nightly backup** (cron / Kubernetes CronJob / CI schedule), with `PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE` set from the secret store:
```bash
scripts/backup.sh /backups/orleu-$(date -u +%F).dump
```
Keep at least 14 daily + 3 monthly copies in storage that is separate from the database account, encrypted, with restricted access. Copy the `.sha256` file with it.

**Restore into a NEW database, verify, then switch the application** (never restore over live data):
```bash
scripts/restore.sh /backups/orleu-2026-11-05.dump orleu_restored
# point a staging copy of the app at orleu_restored, check /actuator/health and sign in, then switch ORLEU_DB_URL
```
**Drill**: run `PGDATABASE=orleu scripts/verify-restore.sh` against a production snapshot at least quarterly and record the duration.

**Neon**: enable point-in-time history on the project; to recover from a bad change create a branch at a timestamp before the incident, verify it with the application, then promote/redirect. Confirm retention window and plan limits in the Neon console before relying on them.

## Rollback of schema changes
Flyway migrations are forward-only. A bad migration is handled by (1) restoring a backup/branch taken before the deploy, or (2) shipping a new corrective migration. Therefore: take a backup immediately before every production deploy that contains a migration, and keep migrations backward compatible with the previous application version (add columns nullable / with defaults; drop or rename in a later release).
