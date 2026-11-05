#!/usr/bin/env bash
# Restores a backup made by backup.sh into an EMPTY database (created if missing).
# Refuses to touch a database that already contains tables: restoring over live data must be a deliberate manual act.
# Usage: scripts/restore.sh <dump-file> <target-database>
set -euo pipefail

dump="${1:?usage: restore.sh <dump-file> <target-database>}"
target="${2:?usage: restore.sh <dump-file> <target-database>}"

if [ -f "$dump.sha256" ]; then
  (cd "$(dirname "$dump")" && sha256sum --check --quiet "$(basename "$dump").sha256") || { echo "checksum mismatch: refusing to restore"; exit 1; }
else
  echo "warning: no checksum file next to the dump" >&2
fi

exists="$(psql -d postgres -Atc "select 1 from pg_database where datname = '$target'")"
if [ "$exists" != "1" ]; then
  createdb "$target"
else
  tables="$(psql -d "$target" -Atc "select count(*) from information_schema.tables where table_schema = 'public'")"
  if [ "$tables" != "0" ]; then
    echo "target database '$target' is not empty ($tables tables): refusing to restore" >&2
    exit 1
  fi
fi

pg_restore --no-owner --no-privileges --exit-on-error --dbname "$target" "$dump"
echo "restored $dump into $target"
