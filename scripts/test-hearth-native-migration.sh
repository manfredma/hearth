#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly SOURCE="$ROOT/deploy/migrate-staging-docker-source.sh"
readonly IMPORT="$ROOT/deploy/migrate-staging-docker-to-native.sh"
test -x "$SOURCE"
test -x "$IMPORT"
grep -Fq 'MYSQL_ROOT_PASSWORD' "$SOURCE"
grep -Fq -- '--databases hearth' "$SOURCE"
if grep -Fq 'source_password' "$SOURCE"; then
  printf 'Source database password must not be extracted into a local variable.\n' >&2
  exit 1
fi
grep -Fq 'hearth.sql.gz' "$SOURCE"
grep -Fq 'dump-ready' "$SOURCE"
grep -Fq 'dump-clean' "$SOURCE"
grep -Fq 'gzip -t' "$SOURCE"
grep -Fq 'import-started' "$SOURCE"
grep -Fq 'import-started' "$IMPORT"
grep -Fq 'imported' "$IMPORT"
grep -Fq 'HEARTH_NATIVE_MYSQL_PORT' "$IMPORT"
grep -Fq 'gzip -dc' "$IMPORT"
grep -Fq 'SELECT SCHEMA_NAME' "$IMPORT"
if grep -Eq 'all-databases|--all-databases|/data/redis|redis-cli.*restore' "$SOURCE" "$IMPORT"; then
  printf 'Hearth staging migration must not dump all DBs or migrate Redis sessions.\n' >&2
  exit 1
fi
printf 'Hearth native migration contract passed.\n'
