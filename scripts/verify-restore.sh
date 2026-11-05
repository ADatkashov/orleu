#!/usr/bin/env bash
# Backup -> restore -> compare. Proves that a backup is actually restorable and complete (row counts of every table match).
# Usage: PGDATABASE=orleu scripts/verify-restore.sh   (needs CREATEDB; the scratch database is dropped afterwards)
set -euo pipefail

: "${PGDATABASE:?set PGDATABASE to the database to verify}"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
scratch="${PGDATABASE}_restore_check"
cleanup() { dropdb --if-exists "$scratch" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

dropdb --if-exists "$scratch"
"$here/backup.sh" "$work/backup.dump"
"$here/restore.sh" "$work/backup.dump" "$scratch"

counts() {  # one line per table: name=rowcount, exact counts (not statistics)
  local db="$1"
  for t in $(psql -d "$db" -Atc "select tablename from pg_tables where schemaname = 'public' order by 1"); do
    echo "$t=$(psql -d "$db" -Atc "select count(*) from \"$t\"")"
  done
}
src="$(counts "$PGDATABASE")"
dst="$(counts "$scratch")"
if [ "$src" != "$dst" ]; then
  echo "MISMATCH between source and restored database:" >&2
  diff <(echo "$src") <(echo "$dst") >&2 || true
  exit 1
fi
migrations="$(psql -d "$scratch" -Atc "select count(*) from flyway_schema_history where success")"
echo "OK: $(echo "$src" | wc -l) tables restored with identical row counts, $migrations migrations recorded"
