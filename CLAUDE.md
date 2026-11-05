# Project notes for Claude

## Standing authorization (from the repository owner, ADatkashov, 2026-11-05)
The owner told Claude to work autonomously, choose the next work items itself, and **merge finished, CI-green pull requests into `main` without asking**. Still never skip/disable tests to get green, never force-push `main`, and keep `docs/IMPLEMENTATION_STATUS.md` honest.

## Dev notes
- Backend: `backend/`, `./gradlew test`. Integration tests need PostgreSQL: set `ORLEU_TEST_DB_URL` (+ `_USER`/`_PASSWORD`) or have Docker for Testcontainers.
- Local PG in the cloud session: `pg_ctlcluster 16 main start`; db `orleu_test`, user/password `orleu`.
