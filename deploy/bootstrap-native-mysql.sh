#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ $# -eq 1 && "$1" =~ ^(staging|production)$ ]] || { printf 'Usage: %s staging|production\n' "$0" >&2; exit 2; }
readonly ENVIRONMENT="$1"
readonly NATIVE_ENV="/etc/hearth/$ENVIRONMENT-native.env"
readonly ADMIN_FILE="/etc/bytedepth/$([[ "$ENVIRONMENT" == staging ]] && printf staging-native-mysql-admin.cnf || printf production-green-mysql.cnf)"
source "$NATIVE_ENV"
[[ -r "$ADMIN_FILE" ]] || { printf 'Missing shared MySQL admin file.\n' >&2; exit 1; }
db_user="hearth_"$ENVIRONMENT"_native"
mysql_exec() { mysql --defaults-extra-file="$ADMIN_FILE" --protocol=tcp --host=127.0.0.1 --port="$HEARTH_NATIVE_MYSQL_PORT" --batch --skip-column-names "$@"; }
escape_sql() { printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g"; }
password="$(escape_sql "$HEARTH_DATASOURCE_PASSWORD")"
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
