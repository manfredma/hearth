#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
readonly NATIVE_ENV=/etc/hearth/production-native.env
readonly ADMIN_FILE=/etc/bytedepth/production-green-mysql.cnf
source "$CONFIG_FILE"
[[ -r "$NATIVE_ENV" && -r "$ADMIN_FILE" ]] || { printf 'Hearth production database configuration is missing.\n' >&2; exit 1; }
IFS= read -r password_hash || { printf 'Existing Hearth admin password hash is required on stdin.\n' >&2; exit 1; }
extra_line=""
if IFS= read -r extra_line; then
  printf 'Expected exactly one admin password hash on stdin.\n' >&2
  exit 1
fi
[[ "$password_hash" =~ ^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$ ]] || { printf 'Hearth admin password hash is not BCrypt.\n' >&2; exit 1; }
env_value() { awk -F= -v key="$1" '$1 == key {print substr($0, index($0, "=") + 1); exit}' "$NATIVE_ENV"; }
readonly ISSUER="$(env_value HEARTH_OIDC_ISSUER)"
[[ "$ISSUER" == https://hearth.bytedepth.cn ]] || { printf 'Hearth production issuer is invalid.\n' >&2; exit 1; }
mysql_admin() {
  mysql --defaults-extra-file="$ADMIN_FILE" --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" --database=hearth "$@"
}
existing_hash="$(mysql_admin --batch --skip-column-names --execute="SELECT password_hash FROM identity_credential WHERE login='admin'")"
if [[ -n "$existing_hash" ]]; then
  [[ "$existing_hash" == "$password_hash" ]] || { printf 'Hearth production already has an admin credential; refusing to rotate it.\n' >&2; exit 1; }
  printf 'Hearth production admin already matches the existing shared credential.\n'
  exit 0
fi
credential_count="$(mysql_admin --batch --skip-column-names --execute='SELECT COUNT(*) FROM identity_credential')"
user_count="$(mysql_admin --batch --skip-column-names --execute='SELECT COUNT(*) FROM user_identity')"
[[ "$credential_count" == 0 && "$user_count" == 0 ]] || { printf 'Hearth production identity tables are not empty; refusing initial admin creation.\n' >&2; exit 1; }
mysql_admin <<SQL
START TRANSACTION;
SET @hearth_admin_id = UUID();
INSERT INTO user_identity (id, issuer, subject, display_name, email, created_at, updated_at)
VALUES (@hearth_admin_id, '$ISSUER', 'admin', 'admin', NULL, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
INSERT INTO identity_credential (user_id, login, password_hash, enabled, failed_attempts, locked_until, created_at, updated_at)
VALUES (@hearth_admin_id, 'admin', '$password_hash', TRUE, 0, NULL, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
COMMIT;
SQL
[[ "$(mysql_admin --batch --skip-column-names --execute="SELECT password_hash FROM identity_credential WHERE login='admin'")" == "$password_hash" ]] || { printf 'Hearth production admin bootstrap could not be verified.\n' >&2; exit 1; }
unset password_hash existing_hash
printf 'Bootstrapped the permanent Hearth production admin using the existing shared credential hash.\n'
