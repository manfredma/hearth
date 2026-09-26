#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ ${HEARTH_STAGING_DEPLOYMENT_LOCK_HELD:-} == 1 ]] || { printf 'Staging deployment lock is required for import recovery.\n' >&2; exit 1; }
mode="${1:-recover}"
adopt_schema="${2:-}"
if [[ "$mode" == recover ]]; then
  [[ $# -eq 0 ]] || { printf 'Usage: %s [adopt <validated-recovery-schema>]\n' "$0" >&2; exit 2; }
elif [[ "$mode" == adopt ]]; then
  [[ $# -eq 2 && "$adopt_schema" =~ ^hearth_recovery_[0-9]{8}_[0-9]{6}_[a-f0-9]{8}$ ]] || {
    printf 'Usage: %s adopt <validated-recovery-schema>\n' "$0" >&2
    exit 2
  }
else
  printf 'Usage: %s [adopt <validated-recovery-schema>]\n' "$0" >&2
  exit 2
fi

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly STATE_ROOT=/var/lib/hearth-native-staging-migration
readonly DUMP_FILE="$STATE_ROOT/import/hearth.sql.gz"
readonly ADMIN_FILE=/etc/bytedepth/staging-native-mysql-admin.cnf
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
source "$CONFIG_FILE"
source "$SOURCE_ROOT/deploy/lib/staging-import-recovery.sh"
source "$SOURCE_ROOT/deploy/lib/pipeline-status.sh"
source "$SOURCE_ROOT/deploy/lib/check-warning-log.sh"

mysql_admin() {
  mysql --defaults-extra-file="$ADMIN_FILE" --connect-timeout=5 \
    --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" \
    --batch --skip-column-names "$@"
}
mysql_count() { mysql_admin --execute="$1"; }

[[ -r "$ADMIN_FILE" && -f "$DUMP_FILE" && ! -L "$DUMP_FILE" \
  && -f "$STATE_ROOT/import-started" && ! -L "$STATE_ROOT/import-started" \
  && -f "$STATE_ROOT/dump-ready" && ! -L "$STATE_ROOT/dump-ready" ]] || {
  printf 'Hearth import recovery requires the preserved source dump and safe import markers.\n' >&2
  exit 1
}
gzip -t "$DUMP_FILE"

imported=0
[[ ! -e "$STATE_ROOT/imported" ]] || imported=1
recovery_started=0
[[ ! -e "$STATE_ROOT/recovery-started" ]] || recovery_started=1
recovery_completed=0
[[ ! -e "$STATE_ROOT/recovery-completed" ]] || recovery_completed=1
recovery_ready=0
[[ ! -e "$STATE_ROOT/recovery-ready" ]] || recovery_ready=1
state="$(hearth_staging_import_state 1 "$imported" "$recovery_started" "$recovery_completed" "$recovery_ready")"

expected_tables="$(gzip -dc "$DUMP_FILE" | awk -F'`' '/^CREATE TABLE `/ {print $2}' | sort)"
expected_count="$(awk 'NF {count++} END {print count + 0}' <<< "$expected_tables")"
[[ "$expected_count" =~ ^[1-9][0-9]*$ ]] || { printf 'Hearth source dump contains no recognized tables.\n' >&2; exit 1; }

assert_complete_database() {
  local schema="$1" quoted_schema tables admin_count migrations
  quoted_schema="$(hearth_quote_mysql_identifier "$schema")"
  tables="$(mysql_admin --execute="SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='$schema' AND table_type='BASE TABLE' ORDER BY TABLE_NAME")"
  [[ "$tables" == "$expected_tables" ]] || { printf 'Hearth schema %s differs from the source table set.\n' "$schema" >&2; return 1; }
  admin_count="$(mysql_count "SELECT COUNT(*) FROM $quoted_schema.identity_credential WHERE login='admin' AND enabled=TRUE")"
  [[ "$admin_count" == 1 ]] || { printf 'Hearth schema %s has no unique enabled admin.\n' "$schema" >&2; return 1; }
  migrations="$(mysql_count "SELECT COUNT(*) FROM $quoted_schema.flyway_schema_history WHERE success=TRUE")"
  [[ "$migrations" =~ ^[1-9][0-9]*$ ]] || { printf 'Hearth schema %s has no successful Flyway history.\n' "$schema" >&2; return 1; }
}

resume=0
case "$state" in
  imported)
    assert_complete_database hearth
    printf 'Hearth staging import is already verified.\n'
    exit 0
    ;;
  recovery-finalize-marker)
    assert_complete_database hearth
    touch "$STATE_ROOT/imported"
    chown ubuntu:ubuntu "$STATE_ROOT/imported"
    chmod 0600 "$STATE_ROOT/imported"
    printf 'Finalized Hearth import marker after verifying the complete database.\n'
    exit 0
    ;;
  recovery-resume) resume=1 ;;
  recovery-interrupted)
    if [[ "$mode" != adopt ]]; then
      printf 'A prior recovery was interrupted; preserving every schema and refusing a second automatic attempt.\n' >&2
      exit 1
    fi
    ;;
  recovery-required) ;;
  *) printf 'No recoverable Hearth import marker is present.\n' >&2; exit 1 ;;
esac

if [[ "$mode" == adopt ]]; then
  [[ "$state" == recovery-interrupted && ! -e "$STATE_ROOT/recovery-ready" ]] || {
    printf 'Only an interrupted recovery without a ready marker can be adopted.\n' >&2
    exit 1
  }
  suffix="${adopt_schema#hearth_recovery_}"
  recovery_id="${suffix/_/t}"
  recovery_log="$STATE_ROOT/recovery-$recovery_id.log"
  recovery_schemas="$(mysql_admin --execute="SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'hearth_recovery_%' ORDER BY schema_name")"
  [[ "$recovery_schemas" == "$adopt_schema" && -f "$recovery_log" && ! -L "$recovery_log" ]] || {
    printf 'Adoption schema/log is ambiguous or missing; preserving all data.\n' >&2
    exit 1
  }
  [[ "$(mysql_count "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='hearth_partial_$suffix'")" == 0 ]] || {
    printf 'Adoption refuses an existing backup schema; preserving all data.\n' >&2
    exit 1
  }
  assert_complete_database "$adopt_schema"
  for query in \
    "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='$adopt_schema'" \
    "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='$adopt_schema'" \
    "SELECT COUNT(*) FROM information_schema.events WHERE event_schema='$adopt_schema'" \
    "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='$adopt_schema'"; do
    [[ "$(mysql_count "$query")" == 0 ]] || { printf 'Adoption schema contains unsupported objects.\n' >&2; exit 1; }
  done
  hearth_assert_log_has_no_warning "$recovery_log" || { printf 'Adoption import log has WARNING or cannot be scanned.\n' >&2; exit 1; }
  if grep -Eqi '(^|[^[:alnum:]_])ERROR([^[:alnum:]_]|$)' "$recovery_log"; then
    printf 'Adoption import log contains ERROR.\n' >&2
    exit 1
  fi
  ready_tmp="$(mktemp "$STATE_ROOT/.recovery-ready.XXXXXX")"
  printf '%s\n' "$adopt_schema" > "$ready_tmp"
  chown ubuntu:ubuntu "$ready_tmp"
  chmod 0600 "$ready_tmp"
  mv "$ready_tmp" "$STATE_ROOT/recovery-ready"
  printf 'Adopted the validated interrupted recovery schema; no table swap was performed.\n'
  exit 0
fi

mysql_admin --execute='SELECT 1' >/dev/null
partial_tables="$(mysql_admin --execute="SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='hearth' AND table_type='BASE TABLE' ORDER BY TABLE_NAME")"
for query in \
  "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='hearth'" \
  "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='hearth'" \
  "SELECT COUNT(*) FROM information_schema.events WHERE event_schema='hearth'" \
  "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='hearth'"; do
  [[ "$(mysql_count "$query")" == 0 ]] || { printf 'Hearth partial schema has a non-table object; refusing automatic swap.\n' >&2; exit 1; }
done

if (( resume == 1 )); then
  [[ -f "$STATE_ROOT/recovery-ready" && ! -L "$STATE_ROOT/recovery-ready" ]] || { printf 'Interrupted recovery has no verified resume marker.\n' >&2; exit 1; }
  recovery_database="$(<"$STATE_ROOT/recovery-ready")"
  [[ "$recovery_database" =~ ^hearth_recovery_[0-9]{8}_[0-9]{6}_[a-f0-9]{8}$ ]] || { printf 'Recovery resume marker contains an unsafe schema name.\n' >&2; exit 1; }
  suffix="${recovery_database#hearth_recovery_}"
  recovery_id="${suffix/_/t}"
  backup_database="hearth_partial_$suffix"
  recovery_log="$STATE_ROOT/recovery-$recovery_id.log"
  recovery_schemas="$(mysql_admin --execute="SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'hearth_recovery_%' ORDER BY schema_name")"
  [[ "$recovery_schemas" == "$recovery_database" && -f "$recovery_log" && ! -L "$recovery_log" ]] || {
    printf 'Recovery resume schema/log is ambiguous or missing; preserving all data.\n' >&2
    exit 1
  }
  [[ "$(mysql_count "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='$backup_database'")" == 0 ]] || {
    printf 'Recovery backup schema already exists; preserving it for manual reconciliation.\n' >&2
    exit 1
  }
  assert_complete_database "$recovery_database"
else
  recovery_id="$(date -u +%Y%m%dt%H%M%S)_$(openssl rand -hex 4)"
  suffix="${recovery_id//t/_}"
  recovery_database="hearth_recovery_$suffix"
  backup_database="hearth_partial_$suffix"
  [[ "$recovery_id" =~ ^[0-9]{8}t[0-9]{6}_[a-f0-9]{8}$ ]] || { printf 'Unable to generate a safe recovery id.\n' >&2; exit 1; }
  for database in "$recovery_database" "$backup_database"; do
    [[ "$(mysql_count "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='$database'")" == 0 ]] || {
      printf 'Recovery schema already exists; preserving it: %s\n' "$database" >&2
      exit 1
    }
  done
  touch "$STATE_ROOT/recovery-started"
  chown ubuntu:ubuntu "$STATE_ROOT/recovery-started"
  chmod 0600 "$STATE_ROOT/recovery-started"
  recovery_log="$STATE_ROOT/recovery-$recovery_id.log"
  install -o ubuntu -g ubuntu -m 0600 /dev/null "$recovery_log"
  set +e
  gzip -dc "$DUMP_FILE" 2>>"$recovery_log" \
    | hearth_rewrite_staging_dump_schema "$recovery_database" \
    | mysql_admin 2>>"$recovery_log"
  import_pipeline_statuses=("${PIPESTATUS[@]}")
  set -e
  [[ ${#import_pipeline_statuses[@]} -eq 3 ]] || { printf 'Recovery import pipeline status is incomplete.\n' >&2; exit 1; }
  hearth_require_successful_pipeline "${import_pipeline_statuses[@]}" || { printf 'Source dump import into scratch schema failed.\n' >&2; exit 1; }
  hearth_assert_log_has_no_warning "$recovery_log" || { printf 'Recovery import emitted WARNING or its log could not be scanned.\n' >&2; exit 1; }
  if grep -Eqi '(^|[^[:alnum:]_])ERROR([^[:alnum:]_]|$)' "$recovery_log"; then
    printf 'Recovery import log contains ERROR.\n' >&2
    exit 1
  fi
  ready_tmp="$(mktemp "$STATE_ROOT/.recovery-ready.XXXXXX")"
  printf '%s\n' "$recovery_database" > "$ready_tmp"
  chown ubuntu:ubuntu "$ready_tmp"
  chmod 0600 "$ready_tmp"
  mv "$ready_tmp" "$STATE_ROOT/recovery-ready"
fi

recovery_tables="$(mysql_admin --execute="SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='$recovery_database' AND table_type='BASE TABLE' ORDER BY TABLE_NAME")"
[[ "$recovery_tables" == "$expected_tables" ]] || { printf 'Scratch schema table set differs from the source dump.\n' >&2; exit 1; }
assert_complete_database "$recovery_database"
for query in \
  "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='$recovery_database'" \
  "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='$recovery_database'" \
  "SELECT COUNT(*) FROM information_schema.events WHERE event_schema='$recovery_database'" \
  "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='$recovery_database'"; do
  [[ "$(mysql_count "$query")" == 0 ]] || { printf 'Scratch schema has a non-table object; refusing automatic swap.\n' >&2; exit 1; }
done

partial_table_count="$(awk 'NF {count++} END {print count + 0}' <<< "$partial_tables")"
if (( partial_table_count > 0 )); then
  mysql_admin --execute="CREATE DATABASE $backup_database CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
fi
rename_sql="$(hearth_build_staging_recovery_rename_sql "$backup_database" "$recovery_database" "$partial_tables" "$recovery_tables")"
mysql_admin --execute="$rename_sql"
assert_complete_database hearth
[[ "$(mysql_count "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$recovery_database'")" == 0 ]] || {
  printf 'Scratch schema still contains objects after the table swap.\n' >&2
  exit 1
}
mysql_admin --execute="DROP DATABASE $recovery_database"

backup_for_history=none
(( partial_table_count == 0 )) || backup_for_history="$backup_database"
history_tmp="$(mktemp "$STATE_ROOT/.recovery-history.$recovery_id.XXXXXX")"
printf 'run_id=%s\nsource_dump_sha256=%s\nbackup_database=%s\npartial_table_count=%s\nrecovered_table_count=%s\nrecovered_at=%s\n' \
  "$recovery_id" "$(sha256sum "$DUMP_FILE" | awk '{print $1}')" \
  "$backup_for_history" "$partial_table_count" "$expected_count" "$(date -u +%FT%TZ)" > "$history_tmp"
chown ubuntu:ubuntu "$history_tmp"
chmod 0600 "$history_tmp"
mv "$history_tmp" "$STATE_ROOT/recovery-$recovery_id.manifest"
touch "$STATE_ROOT/recovery-completed"
chown ubuntu:ubuntu "$STATE_ROOT/recovery-completed"
chmod 0600 "$STATE_ROOT/recovery-completed"
touch "$STATE_ROOT/imported"
chown ubuntu:ubuntu "$STATE_ROOT/imported"
chmod 0600 "$STATE_ROOT/imported"
printf 'Recovered Hearth staging import; previous partial tables are preserved in %s.\n' "$backup_for_history"
