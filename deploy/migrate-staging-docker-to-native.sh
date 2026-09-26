#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ $# -eq 1 && "$1" == prepare ]] || { printf 'Usage: %s prepare\n' "$0" >&2; exit 2; }
readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly IMPORT_ROOT=/var/lib/hearth-native-staging-migration/import
readonly STATE_ROOT=/var/lib/hearth-native-staging-migration
readonly ADMIN_FILE=/etc/bytedepth/staging-native-mysql-admin.cnf
readonly NATIVE_ENV=/etc/hearth/staging-native.env
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
readonly NATIVE_ROOT=/data/hearth-native-staging
source "$CONFIG_FILE"
mysql_exec() { mysql --defaults-extra-file="$ADMIN_FILE" --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" --batch --skip-column-names "$@"; }
[[ -r "$IMPORT_ROOT/hearth.sql.gz" ]] || { printf 'Missing Hearth staging dump.\n' >&2; exit 1; }
[[ -r "$ADMIN_FILE" ]] || { printf 'Missing shared MySQL admin file.\n' >&2; exit 1; }
[[ -e "$STATE_ROOT/dump-ready" ]] || { printf 'Hearth source dump has no completed transfer marker.\n' >&2; exit 1; }
if [[ -e "$STATE_ROOT/imported" ]]; then
  printf 'Hearth staging database was already imported.\n'
  exit 0
fi
if mysql_exec --execute='SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = "hearth"' | grep -Eq '^[1-9][0-9]*$'; then
  printf 'Hearth native database is non-empty without an imported marker; refusing to overwrite it.\n' >&2
  exit 1
fi
if [[ -e "$STATE_ROOT/import-started" ]]; then
  printf 'Hearth staging import state is uncertain; refusing automatic retry.\n' >&2
  exit 1
fi
install -d -o ubuntu -g ubuntu -m 0700 "$STATE_ROOT"
touch "$STATE_ROOT/import-started"
chown ubuntu:ubuntu "$STATE_ROOT/import-started"
gzip -dc "$IMPORT_ROOT/hearth.sql.gz" | mysql_exec
mysql_exec --execute='SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = "hearth"' | awk '$0 == "hearth" {found=1} END {exit !found}'
install -d -o ubuntu -g hearth -m 0770 "$NATIVE_ROOT/data"
install -d -o ubuntu -g ubuntu -m 0700 "$STATE_ROOT"
touch "$STATE_ROOT/imported"
chown ubuntu:ubuntu "$STATE_ROOT/imported"
printf 'Hearth staging database imported into shared native MySQL.\n'
