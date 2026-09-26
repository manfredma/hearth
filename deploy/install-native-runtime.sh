#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ $# -eq 1 && "$1" =~ ^(staging|production)$ ]] || { printf 'Usage: %s staging|production\n' "$0" >&2; exit 2; }
readonly ENVIRONMENT="$1"
readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
readonly NATIVE_ROOT=/opt/hearth-native
readonly ENV_DIR=/etc/hearth
source "$CONFIG_FILE"

JAVA_BIN="$(readlink -f "$(command -v java 2>/dev/null || true)" 2>/dev/null || true)"
[[ -x "$JAVA_BIN" ]] || { printf 'Java 25 is required.\n' >&2; exit 1; }
"$JAVA_BIN" -version 2>&1 | grep -Eq 'version[[:space:]]"25([."]|$)' || { printf 'Resolved Java is not Java 25.\n' >&2; exit 1; }
getent group hearth >/dev/null || groupadd --system hearth
getent passwd hearth >/dev/null || useradd --system --gid hearth --home-dir /nonexistent --shell /usr/sbin/nologin hearth

if [[ "$ENVIRONMENT" == staging ]]; then
    ROOT_DIR="$HEARTH_NATIVE_STAGING_ROOT"
    APP_SERVICE=hearth-staging-native-app.service
    EDGE_SERVICE=hearth-staging-native-edge.service
    APP_TEMPLATE=hearth-staging-native-app.service.in
    EDGE_TEMPLATE=hearth-staging-native-edge.service.in
    LOGROTATE_SERVICE=hearth-staging-native-edge-logrotate.service
    LOGROTATE_TIMER=hearth-staging-native-edge-logrotate.timer
    TEST_SLOT_SERVICE=hearth-staging-native-test-slot.service
    TEST_SLOT_TEMPLATE=hearth-staging-native-test-slot.service.in
else
    ROOT_DIR="$HEARTH_NATIVE_PRODUCTION_ROOT"
    APP_SERVICE=hearth-production-native-app.service
    EDGE_SERVICE=hearth-production-native-edge.service
    APP_TEMPLATE=hearth-production-native-app.service.in
    EDGE_TEMPLATE=hearth-production-native-edge.service.in
    LOGROTATE_SERVICE=hearth-production-native-edge-logrotate.service
    LOGROTATE_TIMER=hearth-production-native-edge-logrotate.timer
fi
LOGROTATE_SERVICE_TEMPLATE=hearth-native-edge-logrotate.service.in
LOGROTATE_TIMER_TEMPLATE=hearth-native-edge-logrotate.timer.in
ENV_FILE="$ENV_DIR/$ENVIRONMENT-native.env"
[[ -r "$ENV_FILE" ]] || { printf 'Missing native environment: %s\n' "$ENV_FILE" >&2; exit 1; }
command -v nginx >/dev/null || { printf 'Nginx is required.\n' >&2; exit 1; }
command -v logrotate >/dev/null || { printf 'logrotate is required.\n' >&2; exit 1; }

install -d -o ubuntu -g ubuntu -m 0755 "$NATIVE_ROOT" "$NATIVE_ROOT/releases" "$NATIVE_ROOT/source" "$ROOT_DIR" "$ROOT_DIR/data" "$ROOT_DIR/edge" "$ROOT_DIR/edge/client_body_temp" "$ROOT_DIR/edge/proxy_temp"
chown ubuntu:hearth "$ROOT_DIR/data"
chmod 0770 "$ROOT_DIR/data"
chown -R ubuntu:hearth "$ROOT_DIR/edge"
chmod -R g+rwX "$ROOT_DIR/edge"
install -d -o ubuntu -g hearth -m 0750 "$ROOT_DIR/edge/logs"
for log_name in access.log error.log; do
    log_path="$ROOT_DIR/edge/logs/$log_name"
    [[ ! -L "$log_path" ]] || { printf 'Refusing symlinked Hearth edge log: %s\n' "$log_path" >&2; exit 1; }
    if [[ ! -e "$log_path" ]]; then
        install -o ubuntu -g hearth -m 0660 /dev/null "$log_path"
    else
        [[ -f "$log_path" ]] || { printf 'Hearth edge log path is not a regular file: %s\n' "$log_path" >&2; exit 1; }
        chown ubuntu:hearth "$log_path"
        chmod 0660 "$log_path"
    fi
done
for legacy_log in "$ROOT_DIR/edge/access.log" "$ROOT_DIR/edge/error.log"; do
    if [[ -f "$legacy_log" && ! -L "$legacy_log" ]]; then
        chown ubuntu:hearth "$legacy_log"
        chmod 0660 "$legacy_log"
    fi
done
install -d -o ubuntu -g hearth -m 0750 "$ENV_DIR"
chown ubuntu:hearth "$ENV_FILE"
chmod 0640 "$ENV_FILE"

edge_conf_tmp="$(mktemp "$ENV_DIR/.native-edge.XXXXXX")"
logrotate_tmp="$(mktemp "$ENV_DIR/.native-logrotate.XXXXXX")"
logrotate_service_tmp="$(mktemp "$ENV_DIR/.native-logrotate-service.XXXXXX")"
logrotate_timer_tmp="$(mktemp "$ENV_DIR/.native-logrotate-timer.XXXXXX")"
trap 'rm -f -- "$edge_conf_tmp" "$logrotate_tmp" "$logrotate_service_tmp" "$logrotate_timer_tmp"' EXIT
edge_port="$([[ "$ENVIRONMENT" == staging ]] && printf '%s' "$HEARTH_NATIVE_STAGING_EDGE_PORT" || printf '%s' "$HEARTH_NATIVE_PRODUCTION_EDGE_PORT")"
app_port="$([[ "$ENVIRONMENT" == staging ]] && printf '%s' "$HEARTH_NATIVE_STAGING_APP_PORT" || printf '%s' "$HEARTH_NATIVE_PRODUCTION_APP_PORT")"
cat > "$edge_conf_tmp" <<EOF
events { worker_connections 1024; }
pid $ROOT_DIR/edge/nginx.pid;
http {
    include /etc/nginx/mime.types;
    access_log $ROOT_DIR/edge/logs/access.log;
    error_log $ROOT_DIR/edge/logs/error.log warn;
    client_body_temp_path $ROOT_DIR/edge/client_body_temp;
    proxy_temp_path $ROOT_DIR/edge/proxy_temp;
    server {
        listen 127.0.0.1:$edge_port;
        server_name _;
        location / {
            proxy_pass http://127.0.0.1:$app_port;
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF
install -o ubuntu -g hearth -m 0640 "$edge_conf_tmp" "$ENV_DIR/$ENVIRONMENT-native-edge.conf"
sed \
    -e "s#__EDGE_LOG_DIR__#$ROOT_DIR/edge/logs#g" \
    "$SOURCE_ROOT/deploy/logrotate/hearth-native-edge.conf.template" > "$logrotate_tmp"
install -o ubuntu -g ubuntu -m 0640 "$logrotate_tmp" "$ROOT_DIR/edge/logrotate.conf"
sed \
    -e "s#__EDGE_ROOT__#$ROOT_DIR/edge#g" \
    -e "s#__ENVIRONMENT__#$ENVIRONMENT#g" \
    "$SOURCE_ROOT/deploy/systemd/$LOGROTATE_SERVICE_TEMPLATE" > "$logrotate_service_tmp"
sed \
    -e "s#__ENVIRONMENT__#$ENVIRONMENT#g" \
    -e "s#__LOGROTATE_SERVICE__#$LOGROTATE_SERVICE#g" \
    "$SOURCE_ROOT/deploy/systemd/$LOGROTATE_TIMER_TEMPLATE" > "$logrotate_timer_tmp"
install -o ubuntu -g ubuntu -m 0644 "$logrotate_service_tmp" "/etc/systemd/system/$LOGROTATE_SERVICE"
install -o ubuntu -g ubuntu -m 0644 "$logrotate_timer_tmp" "/etc/systemd/system/$LOGROTATE_TIMER"
sed "s#__JAVA_BIN__#$JAVA_BIN#g" "$SOURCE_ROOT/deploy/systemd/$APP_TEMPLATE" > "/etc/systemd/system/$APP_SERVICE"
sed "s#__JAVA_BIN__#$JAVA_BIN#g" "$SOURCE_ROOT/deploy/systemd/$EDGE_TEMPLATE" > "/etc/systemd/system/$EDGE_SERVICE"
chown ubuntu:ubuntu "/etc/systemd/system/$APP_SERVICE" "/etc/systemd/system/$EDGE_SERVICE"
chmod 0644 "/etc/systemd/system/$APP_SERVICE" "/etc/systemd/system/$EDGE_SERVICE"
if [[ "$ENVIRONMENT" == staging ]]; then
    sed "s#__JAVA_BIN__#$JAVA_BIN#g" "$SOURCE_ROOT/deploy/systemd/$TEST_SLOT_TEMPLATE" > "/etc/systemd/system/$TEST_SLOT_SERVICE"
    chown ubuntu:ubuntu "/etc/systemd/system/$TEST_SLOT_SERVICE"
    chmod 0644 "/etc/systemd/system/$TEST_SLOT_SERVICE"
fi
systemctl daemon-reload
systemctl enable "$APP_SERVICE" "$EDGE_SERVICE" "$LOGROTATE_TIMER"
systemctl start "$LOGROTATE_TIMER"
printf 'Installed Hearth native runtime for %s.\n' "$ENVIRONMENT"
