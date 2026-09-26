#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ ${HEARTH_TEST_SLOT_LOCK_HELD:-} == 1 ]] || { printf 'Deployment/test lock is required.\n' >&2; exit 1; }
[[ $# -eq 2 && $1 == --manifest ]] || { printf 'Usage: %s --manifest PATH\n' "$0" >&2; exit 2; }
readonly MANIFEST="$2"
readonly EXPECTED_ROOT=/var/lib/hearth-staging/test-slots
readonly NATIVE_ENV=/etc/hearth/staging-native.env
readonly ADMIN_FILE=/etc/bytedepth/staging-native-mysql-admin.cnf
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
source "$CONFIG_FILE"
[[ "$MANIFEST" == "$EXPECTED_ROOT/"*/*.manifest && -f "$MANIFEST" && ! -L "$MANIFEST" ]] || { printf 'Invalid Hearth test-slot manifest path.\n' >&2; exit 1; }
[[ -r "$NATIVE_ENV" && -r "$ADMIN_FILE" ]] || { printf 'Hearth staging native credentials are unavailable.\n' >&2; exit 1; }
! systemctl is-active --quiet hearth-staging-native-test-slot.service || { printf 'Stop Hearth test-slot service before teardown.\n' >&2; exit 1; }
manifest_value() { awk -F= -v key="$1" '$1 == key {print substr($0, index($0, "=") + 1); exit}' "$MANIFEST"; }
run_id="$(manifest_value run_id)"
suite="$(manifest_value suite)"
database="$(manifest_value database)"
db_user="$(manifest_value user)"
redis_db="$(manifest_value redis_db)"
namespace="$(manifest_value namespace)"
env_file="$(manifest_value env_file)"
data_root="$(manifest_value data_root)"
[[ "$run_id" =~ ^[0-9]{8}t[0-9]{6}_[a-f0-9]{8}$ && "$suite" =~ ^(integration|e2e)$ ]] || { printf 'Invalid Hearth test-slot identifiers.\n' >&2; exit 1; }
case "$suite" in integration) expected_user_suite=it ;; e2e) expected_user_suite=e2e ;; esac
[[ "$database" == "hearth_${suite}_${run_id//t/_}" && "$db_user" == "h_${expected_user_suite}_${run_id//t/_}" ]] || { printf 'Refusing to remove unrecognized Hearth test-slot names.\n' >&2; exit 1; }
[[ "$namespace" == "hearth:staging:test:${suite}:${run_id}:" ]] || { printf 'Refusing to remove unrecognized Hearth test Redis namespace.\n' >&2; exit 1; }
case "$suite" in integration) [[ "$redis_db" == "$HEARTH_NATIVE_STAGING_IT_REDIS_DB" ]] ;; e2e) [[ "$redis_db" == "$HEARTH_NATIVE_STAGING_E2E_REDIS_DB" ]] ;; esac || { printf 'Refusing to remove unreserved Hearth Redis DB.\n' >&2; exit 1; }
[[ "$env_file" == "$EXPECTED_ROOT/$run_id/$suite.env" ]] || { printf 'Refusing to remove unexpected Hearth test environment.\n' >&2; exit 1; }
[[ "$data_root" == "/data/hearth-native-staging/test-slot/$run_id/$suite" && -d "$data_root" && ! -L "$data_root" ]] || { printf 'Refusing to remove unexpected Hearth test data path.\n' >&2; exit 1; }
[[ ! -e "$(dirname "$MANIFEST")/$suite.state-uncertain" ]] || { printf 'Hearth test-slot state is uncertain; refusing teardown.\n' >&2; exit 1; }
env_value() { awk -F= -v key="$1" '$1 == key {print substr($0, index($0, "=") + 1); exit}' "$NATIVE_ENV"; }
export REDISCLI_AUTH="$(env_value HEARTH_REDIS_PASSWORD)"
[[ -n "$REDISCLI_AUTH" ]] || { printf 'Hearth staging Redis credential is missing.\n' >&2; exit 1; }
redis_cli() { redis-cli --no-auth-warning -h 127.0.0.1 -p "$HEARTH_NATIVE_REDIS_PORT" -n "$redis_db" "$@"; }
key_file="$(mktemp "$(dirname "$MANIFEST")/.redis-keys.XXXXXX")"
chown ubuntu:ubuntu "$key_file"
chmod 0600 "$key_file"
redis_cli --scan --pattern "${namespace}*" > "$key_file"
while IFS= read -r key; do
  [[ -n "$key" ]] || continue
  redis_cli DEL "$key" >/dev/null
done < "$key_file"
rm -f -- "$key_file"
[[ -z "$(redis_cli --scan --pattern "${namespace}*")" ]] || { printf 'Hearth test Redis namespace is not empty after cleanup.\n' >&2; exit 1; }
mysql_admin() { mysql --defaults-extra-file="$ADMIN_FILE" --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" "$@"; }
mysql_admin --execute="DROP USER IF EXISTS '$db_user'@'localhost'; DROP USER IF EXISTS '$db_user'@'127.0.0.1'; DROP DATABASE IF EXISTS $database"
[[ "$(mysql_admin --batch --skip-column-names --execute="SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$database'")" == 0 ]] || { printf 'Hearth test database cleanup could not be verified.\n' >&2; exit 1; }
[[ "$(mysql_admin --batch --skip-column-names --execute="SELECT COUNT(*) FROM mysql.user WHERE user='$db_user'")" == 0 ]] || { printf 'Hearth test user cleanup could not be verified.\n' >&2; exit 1; }
rm -f -- "$env_file" "$MANIFEST"
rm -rf -- "$data_root"
rmdir "$(dirname "$MANIFEST")"
printf 'Removed isolated Hearth %s resources for run %s.\n' "$suite" "$run_id"
