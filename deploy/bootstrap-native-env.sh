#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ $# -eq 1 && "$1" =~ ^(staging|production)$ ]] || { printf 'Usage: %s staging|production\n' "$0" >&2; exit 2; }
readonly ENVIRONMENT="$1"
readonly ENV_DIR=/etc/hearth
readonly NATIVE_ENV="$ENV_DIR/$ENVIRONMENT-native.env"
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
source "$CONFIG_FILE"
if [[ "$ENVIRONMENT" == staging ]]; then
  readonly REDIS_CONF=/data/bytedepth-native-staging/redis/redis.conf
  readonly ISSUER=https://staging-hearth.bytedepth.cn
  readonly REDIS_DB=5
  readonly COOKIE=HEARTH_STAGING_SESSION
  readonly ROOT=/data/hearth-native-staging
else
  readonly REDIS_CONF=/data/bytedepth-native-production/redis/redis.conf
  readonly ISSUER=https://hearth.bytedepth.cn
  readonly REDIS_DB=6
  readonly COOKIE=HEARTH_PRODUCTION_SESSION
  readonly ROOT=/data/hearth-native-production
fi
[[ -r "$REDIS_CONF" ]] || { printf 'Missing shared Redis config: %s\n' "$REDIS_CONF" >&2; exit 1; }
redis_password="$(awk '$1 == "requirepass" {print $2; exit}' "$REDIS_CONF")"
[[ -n "$redis_password" ]] || { printf 'Shared Redis requirepass is missing.\n' >&2; exit 1; }
source_env="$ENV_DIR/$ENVIRONMENT.env"
if [[ ! -r "$source_env" && "$ENVIRONMENT" == staging ]]; then source_env=/opt/hearth/deploy/.env; fi
[[ -r "$source_env" ]] || { printf 'Missing Hearth owner environment: %s\n' "$source_env" >&2; exit 1; }
read_env() { awk -F= -v key="$1" '$1 == key {print substr($0, index($0, "=") + 1); exit}' "$source_env"; }
issuer="$(read_env HEARTH_OIDC_ISSUER)"
signing_key="$(read_env HEARTH_SIGNING_KEY)"
remember_key="$(read_env HEARTH_REMEMBER_ME_KEY)"
if [[ "$ENVIRONMENT" == production ]]; then
  issuer="$ISSUER"
  signing_key="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null | openssl pkcs8 -topk8 -nocrypt -outform DER 2>/dev/null | base64 | tr -d '\n')"
  remember_key="$(openssl rand -hex 32)"
fi
[[ "$issuer" =~ ^https:// ]] || { printf 'Hearth issuer must use HTTPS.\n' >&2; exit 1; }
[[ -n "$signing_key" && "$signing_key" != *replace* && "$signing_key" != *inject* ]] || { printf 'Hearth signing key is missing or placeholder.\n' >&2; exit 1; }
[[ -n "$remember_key" && "$remember_key" != *replace* && "$remember_key" != *inject* ]] || { printf 'Hearth Remember-Me key is missing or placeholder.\n' >&2; exit 1; }
db_password="$(openssl rand -hex 32)"
db_user="hearth_"$ENVIRONMENT"_native"
app_port="$([[ "$ENVIRONMENT" == staging ]] && printf '%s' "$HEARTH_NATIVE_STAGING_APP_PORT" || printf '%s' "$HEARTH_NATIVE_PRODUCTION_APP_PORT")"
native_tmp="$(mktemp "$ENV_DIR/.$ENVIRONMENT-native-env.XXXXXX")"
trap 'rm -f -- "$native_tmp"' EXIT
printf '%s\n' \
  "HEARTH_ENVIRONMENT=$ENVIRONMENT" \
  "HEARTH_DATASOURCE_URL=jdbc:mysql://127.0.0.1:$HEARTH_NATIVE_MYSQL_PORT/hearth?useSSL=false&serverTimezone=Asia/Shanghai&characterEncoding=UTF-8&allowPublicKeyRetrieval=true" \
  "HEARTH_DATASOURCE_USERNAME=$db_user" \
  "HEARTH_DATASOURCE_PASSWORD=$db_password" \
  "HEARTH_REDIS_HOST=127.0.0.1" \
  "HEARTH_REDIS_PORT=$HEARTH_NATIVE_REDIS_PORT" \
  "HEARTH_REDIS_PASSWORD=$redis_password" \
  "HEARTH_SESSION_REDIS_NAMESPACE=hearth:$ENVIRONMENT:session:v1" \
  "HEARTH_SESSION_COOKIE_NAME=$COOKIE" \
  "HEARTH_SESSION_COOKIE_SECURE=true" \
  "HEARTH_OIDC_ISSUER=$issuer" \
  "HEARTH_SIGNING_KEY=$signing_key" \
  "HEARTH_REMEMBER_ME_KEY=$remember_key" \
  "HEARTH_REMEMBER_ME_COOKIE_SECURE=true" \
  "HEARTH_APP_PORT=$app_port" \
  "HEARTH_DATA_DIR=$ROOT/data" > "$native_tmp"
install -d -o ubuntu -g hearth -m 0750 "$ENV_DIR"
install -o ubuntu -g hearth -m 0640 "$native_tmp" "$NATIVE_ENV"
printf 'Prepared Hearth native environment for %s.\n' "$ENVIRONMENT"
