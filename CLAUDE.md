# Project notes for Claude

## Standing authorization (from the repository owner, ADatkashov, 2026-11-05)
The owner told Claude to work autonomously, choose the next work items itself, and **merge finished, CI-green pull requests into `main` without asking**. Still never skip/disable tests to get green, never force-push `main`, and keep `docs/IMPLEMENTATION_STATUS.md` honest.

## Standing instruction (from the repository owner, 2026-11-05, repeated)
Do not ask what to do next: pick the next most valuable work item yourself and do it the way you judge best, then merge when CI is green. Report results and limitations honestly (see `docs/IMPLEMENTATION_STATUS.md`); stop and ask only for things that need the owner's accounts/credentials (payment, SMS/e-mail providers) or for destructive/irreversible actions.

## Dev notes
- Backend: `backend/`, `./gradlew test`. Integration tests need PostgreSQL: set `ORLEU_TEST_DB_URL` (+ `_USER`/`_PASSWORD`) or have Docker for Testcontainers.
- Local PG in the cloud session: `pg_ctlcluster 16 main start`; db `orleu_test`, user/password `orleu`.
- Flutter SDK is not preinstalled: download from storage.googleapis.com (see git history/notes), `git config --global --add safe.directory /opt/sdk/flutter`, run as `flutter ... ` with CI=true is not needed.
- flutter_test: `setSurfaceSize` is in PHYSICAL pixels (default devicePixelRatio 3) — use `setPhone()` from `mobile/test/support/fake_api.dart`. The Ahem test font is wider than real fonts.
- Errors inside bottom sheets/dialogs must be inline (`FormError`/`attempt`), never SnackBars (drawn behind modals).
- Editing a Flyway migration that was already applied locally needs `DROP/CREATE DATABASE orleu_test`; never edit migrations already merged to main.
