#!/usr/bin/env bash
# Logical backup of the ORLEU database (custom-format pg_dump + SHA-256 checksum).
# Connection comes from the standard libpq environment: PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE.
# Usage: scripts/backup.sh <output-file>
set -euo pipefail

out="${1:?usage: backup.sh <output-file>}"
: "${PGDATABASE:?set PGDATABASE (and PGHOST/PGUSER/PGPASSWORD as needed)}"

umask 077   # backups contain personal data: owner-only permissions
tmp="$(mktemp "${out}.XXXX")"
trap 'rm -f "$tmp"' EXIT

pg_dump --format=custom --no-owner --no-privileges --file "$tmp"
mv "$tmp" "$out"
trap - EXIT
(cd "$(dirname "$out")" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256")
echo "backup written: $out ($(du -h "$out" | cut -f1)), checksum: $out.sha256"
