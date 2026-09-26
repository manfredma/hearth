#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ $# -eq 1 && "$1" =~ ^(staging|production)$ ]] || { printf 'Usage: %s staging|production\n' "$0" >&2; exit 2; }
readonly ENVIRONMENT="$1"
readonly NATIVE_ENV="/etc/hearth/$ENVIRONMENT-native.env"
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
readonly ADMIN_FILE="/etc/bytedepth/$([[ "$ENVIRONMENT" == staging ]] && printf staging-native-mysql-admin.cnf || printf production-green-mysql.cnf)"
source "$CONFIG_FILE"
read_native_env() { awk -F= -v key="$1" '$1 == key {print substr($0, index($0, "=") + 1); exit}' "$NATIVE_ENV"; }
datasource_password="$(read_native_env HEARTH_DATASOURCE_PASSWORD)"
[[ -n "$datasource_password" ]] || { printf 'Hearth native database password is missing.\n' >&2; exit 1; }
[[ -r "$ADMIN_FILE" ]] || { printf 'Missing shared MySQL admin file.\n' >&2; exit 1; }
db_user="hearth_"$ENVIRONMENT"_native"
mysql_exec() { mysql --defaults-extra-file="$ADMIN_FILE" --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" --batch --skip-column-names "$@"; }
escape_sql() { printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g"; }
password="$(escape_sql "$datasource_password")"
mysql_exec <<SQL
CREATE DATABASE IF NOT EXISTS hearth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$password';
CREATE USER IF NOT EXISTS '$db_user'@'127.0.0.1' IDENTIFIED BY '$password';
ALTER USER '$db_user'@'localhost' IDENTIFIED BY '$password';
ALTER USER '$db_user'@'127.0.0.1' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON hearth.* TO '$db_user'@'localhost';
GRANT ALL PRIVILEGES ON hearth.* TO '$db_user'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
mysql_exec --execute='SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = "hearth"' | grep -Fxq hearth
printf 'Prepared Hearth native MySQL for %s.\n' "$ENVIRONMENT"
