#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ ${HEARTH_TEST_SLOT_LOCK_HELD:-} == 1 ]] || { printf 'Deployment/test lock is required.\n' >&2; exit 1; }
[[ $# -eq 3 && $1 == --run-id ]] || { printf 'Usage: %s --run-id RUN_ID integration|e2e\n' "$0" >&2; exit 2; }
readonly RUN_ID="$2"
readonly SUITE="$3"
[[ "$SUITE" =~ ^(integration|e2e)$ ]] || { printf 'Unsupported Hearth test suite.\n' >&2; exit 2; }
[[ "$RUN_ID" =~ ^[0-9]{8}t[0-9]{6}_[a-f0-9]{8}$ ]] || { printf 'Invalid Hearth test run id.\n' >&2; exit 1; }
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
readonly NATIVE_ENV=/etc/hearth/staging-native.env
readonly ADMIN_FILE=/etc/bytedepth/staging-native-mysql-admin.cnf
readonly STATE_ROOT=/var/lib/hearth-staging/test-slots
readonly RUN_ROOT="$STATE_ROOT/$RUN_ID"
readonly MANIFEST="$RUN_ROOT/$SUITE.manifest"
readonly ENV_FILE="$RUN_ROOT/$SUITE.env"
readonly DATA_ROOT="/data/hearth-native-staging/test-slot/$RUN_ID/$SUITE"
source "$CONFIG_FILE"
[[ -r "$NATIVE_ENV" && -r "$ADMIN_FILE" ]] || { printf 'Hearth staging native credentials are unavailable.\n' >&2; exit 1; }
[[ ! -e "$MANIFEST" && ! -L "$MANIFEST" && ! -e "$RUN_ROOT" && ! -L "$RUN_ROOT" ]] || { printf 'Hearth test-slot run already exists.\n' >&2; exit 1; }
systemctl is-active --quiet hearth-staging-native-app.service || { printf 'Staging app must be active before test-slot provisioning.\n' >&2; exit 1; }

case "$SUITE" in
  integration) readonly REDIS_DB="$HEARTH_NATIVE_STAGING_IT_REDIS_DB"; readonly USER_SUITE=it ;;
  e2e) readonly REDIS_DB="$HEARTH_NATIVE_STAGING_E2E_REDIS_DB"; readonly USER_SUITE=e2e ;;
esac
readonly DATABASE="hearth_${SUITE}_${RUN_ID//t/_}"
readonly DB_USER="h_${USER_SUITE}_${RUN_ID//t/_}"
readonly NAMESPACE="hearth:staging:test:${SUITE}:${RUN_ID}:"
[[ ${#DB_USER} -le 32 && "$DATABASE" =~ ^[a-z0-9_]+$ && "$DB_USER" =~ ^[a-z0-9_]+$ ]] || { printf 'Hearth test-slot resource names exceed MySQL limits.\n' >&2; exit 1; }
[[ "$REDIS_DB" =~ ^[0-9]+$ && "$REDIS_DB" != "$HEARTH_NATIVE_STAGING_REDIS_DB" && "$REDIS_DB" != "$HEARTH_NATIVE_PRODUCTION_REDIS_DB" && "$REDIS_DB" != 14 && "$REDIS_DB" != 15 ]] || { printf 'Hearth test Redis DB assignment conflicts with a reserved environment.\n' >&2; exit 1; }
env_value() { awk -F= -v key="$1" '$1 == key {print substr($0, index($0, "=") + 1); exit}' "$NATIVE_ENV"; }
readonly REDIS_PASSWORD="$(env_value HEARTH_REDIS_PASSWORD)"
[[ -n "$REDIS_PASSWORD" ]] || { printf 'Hearth staging Redis credential is missing.\n' >&2; exit 1; }
export REDISCLI_AUTH="$REDIS_PASSWORD"
redis_cli() { redis-cli --no-auth-warning -h 127.0.0.1 -p "$HEARTH_NATIVE_REDIS_PORT" "$@"; }
redis_capacity="$(redis_cli CONFIG GET databases | tail -n 1)"
[[ "$redis_capacity" =~ ^[0-9]+$ && "$redis_capacity" -gt "$REDIS_DB" ]] || { printf 'Reserved Hearth test Redis DB %s is unavailable.\n' "$REDIS_DB" >&2; exit 1; }
redis_keyspace="$(redis_cli INFO keyspace)"
if grep -Eq "^db${REDIS_DB}:" <<< "$redis_keyspace"; then
  printf 'Reserved Hearth test Redis DB %s is not empty; refusing to use it.\n' "$REDIS_DB" >&2
  exit 1
fi

mysql_admin() { mysql --defaults-extra-file="$ADMIN_FILE" --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" "$@"; }
existing_database="$(mysql_admin --batch --skip-column-names --execute="SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DATABASE'")"
existing_user="$(mysql_admin --batch --skip-column-names --execute="SELECT COUNT(*) FROM mysql.user WHERE user='$DB_USER' AND host='localhost'")"
[[ "$existing_database" == 0 && "$existing_user" == 0 ]] || { printf 'Hearth test-slot names already exist; refusing reuse.\n' >&2; exit 1; }

install -d -o ubuntu -g ubuntu -m 0700 "$STATE_ROOT" "$RUN_ROOT"
install -d -o ubuntu -g hearth -m 0750 "$DATA_ROOT"
manifest_tmp="$(mktemp "$RUN_ROOT/.manifest.XXXXXX")"
printf 'run_id=%s\nsuite=%s\ndatabase=%s\nuser=%s\nredis_db=%s\nnamespace=%s\nenv_file=%s\ndata_root=%s\n' \
  "$RUN_ID" "$SUITE" "$DATABASE" "$DB_USER" "$REDIS_DB" "$NAMESPACE" "$ENV_FILE" "$DATA_ROOT" > "$manifest_tmp"
chown ubuntu:ubuntu "$manifest_tmp"
chmod 0600 "$manifest_tmp"
mv "$manifest_tmp" "$MANIFEST"
chown ubuntu:ubuntu "$RUN_ROOT"

failed_setup() {
  local status=$?
  if (( status != 0 )); then
    printf 'state_uncertain=1\n' > "$RUN_ROOT/$SUITE.state-uncertain"
    chown ubuntu:ubuntu "$RUN_ROOT/$SUITE.state-uncertain"
    chmod 0600 "$RUN_ROOT/$SUITE.state-uncertain"
    printf 'Hearth test-slot setup failed; preserving exact run resources for inspection.\n' >&2
  fi
}
trap failed_setup EXIT
db_password="$(openssl rand -hex 32)"
mysql_admin --execute="CREATE DATABASE $DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
mysql_admin --execute="CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$db_password'; CREATE USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$db_password'; GRANT ALL PRIVILEGES ON $DATABASE.* TO '$DB_USER'@'localhost'; GRANT ALL PRIVILEGES ON $DATABASE.* TO '$DB_USER'@'127.0.0.1';"
dump_file="$RUN_ROOT/$SUITE.sql"
dump_log="$RUN_ROOT/$SUITE-dump.log"
import_log="$RUN_ROOT/$SUITE-import.log"
if ! mysqldump --defaults-extra-file="$ADMIN_FILE" --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" --single-transaction --quick --routines --events --triggers --no-tablespaces --set-gtid-purged=OFF hearth > "$dump_file" 2> "$dump_log"; then
  printf 'Unable to snapshot Hearth staging logical database.\n' >&2
  exit 1
fi
if grep -Eqi 'WARNING|WARN|ERROR' "$dump_log"; then
  printf 'Hearth test-slot snapshot emitted a warning or error.\n' >&2
  exit 1
fi
sed -E "s/^USE .?hearth.?;/USE $DATABASE;/" "$dump_file" > "$RUN_ROOT/$SUITE-import.sql"
if ! mysql_admin --database="$DATABASE" < "$RUN_ROOT/$SUITE-import.sql" 2> "$import_log"; then
  printf 'Unable to import isolated Hearth test database.\n' >&2
  exit 1
fi
if grep -Eqi 'WARNING|WARN|ERROR' "$import_log"; then
  printf 'Hearth test-slot import emitted a warning or error.\n' >&2
  exit 1
fi
source_tables="$(mysql_admin --batch --skip-column-names --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='hearth'")"
test_tables="$(mysql_admin --batch --skip-column-names --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DATABASE'")"
[[ "$source_tables" =~ ^[1-9][0-9]*$ && "$source_tables" == "$test_tables" ]] || { printf 'Hearth test-slot schema does not match staging.\n' >&2; exit 1; }
[[ "$(env_value HEARTH_REDIS_DATABASE)" == 5 ]] || { printf 'Hearth staging Redis DB is not the expected isolated slot.\n' >&2; exit 1; }
issuer="$(env_value HEARTH_OIDC_ISSUER)"
session_cookie="HEARTH_STAGING_TEST_${SUITE^^}_SESSION"
remember_key="$(openssl rand -hex 32)"
signing_key="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null | openssl pkcs8 -topk8 -nocrypt -outform DER 2>/dev/null | base64 | tr -d '\n')"
[[ -n "$signing_key" && "$issuer" == https://staging-hearth.bytedepth.cn ]] || { printf 'Hearth test-slot security configuration is invalid.\n' >&2; exit 1; }
jdbc="jdbc:mysql://127.0.0.1:$HEARTH_NATIVE_MYSQL_PORT/$DATABASE?useSSL=false&serverTimezone=Asia/Shanghai&characterEncoding=UTF-8&allowPublicKeyRetrieval=true"
printf '%s\n' \
  'HEARTH_ENVIRONMENT=staging' \
  'SPRING_PROFILES_ACTIVE=staging-test' \
  "HEARTH_DATASOURCE_URL=$jdbc" \
  "HEARTH_DATASOURCE_USERNAME=$DB_USER" \
  "HEARTH_DATASOURCE_PASSWORD=$db_password" \
  'HEARTH_REDIS_HOST=127.0.0.1' \
  "HEARTH_REDIS_PORT=$HEARTH_NATIVE_REDIS_PORT" \
  "HEARTH_REDIS_DATABASE=$REDIS_DB" \
  "HEARTH_REDIS_PASSWORD=$REDIS_PASSWORD" \
  "HEARTH_SESSION_REDIS_NAMESPACE=$NAMESPACE" \
  "HEARTH_SESSION_COOKIE_NAME=$session_cookie" \
  'HEARTH_SESSION_COOKIE_SECURE=true' \
  "HEARTH_OIDC_ISSUER=$issuer" \
  "HEARTH_SIGNING_KEY=$signing_key" \
  "HEARTH_REMEMBER_ME_KEY=$remember_key" \
  'HEARTH_REMEMBER_ME_COOKIE_SECURE=true' \
  "HEARTH_APP_PORT=$HEARTH_NATIVE_STAGING_APP_PORT" \
  "HEARTH_DATA_DIR=$DATA_ROOT/data" > "$ENV_FILE"
chown ubuntu:hearth "$ENV_FILE"
chmod 0640 "$ENV_FILE"
chown ubuntu:ubuntu "$dump_file" "$dump_log" "$import_log" "$RUN_ROOT/$SUITE-import.sql"
chmod 0600 "$dump_file" "$dump_log" "$import_log" "$RUN_ROOT/$SUITE-import.sql"
rm -f -- "$dump_file" "$RUN_ROOT/$SUITE-import.sql" "$dump_log" "$import_log"
trap - EXIT
printf 'Provisioned isolated Hearth %s resources for run %s.\n' "$SUITE" "$RUN_ID"
