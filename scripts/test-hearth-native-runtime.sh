#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for file in \
  "$ROOT/deploy/hearth-native.conf.example" \
  "$ROOT/deploy/bootstrap-native-env.sh" \
  "$ROOT/deploy/bootstrap-native-mysql.sh" \
  "$ROOT/deploy/install-native-runtime.sh" \
  "$ROOT/deploy/logrotate/hearth-native-edge.conf.template" \
  "$ROOT/deploy/systemd/hearth-native-edge-logrotate.service.in" \
  "$ROOT/deploy/systemd/hearth-native-edge-logrotate.timer.in" \
  "$ROOT/deploy/systemd/hearth-staging-native-app.service.in" \
  "$ROOT/deploy/systemd/hearth-staging-native-test-slot.service.in" \
  "$ROOT/deploy/systemd/hearth-production-native-app.service.in" \
  "$ROOT/deploy/systemd/hearth-staging-native-edge.service.in" \
  "$ROOT/deploy/systemd/hearth-production-native-edge.service.in"; do
  test -f "$file" || { printf 'Missing native runtime file: %s\n' "$file" >&2; exit 1; }
done
grep -Fq 'HEARTH_NATIVE_STAGING_APP_PORT=18110' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'HEARTH_NATIVE_PRODUCTION_APP_PORT=18112' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'HEARTH_NATIVE_STAGING_REDIS_DB=5' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'HEARTH_NATIVE_PRODUCTION_REDIS_DB=6' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'HEARTH_NATIVE_STAGING_IT_REDIS_DB=12' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'HEARTH_NATIVE_STAGING_E2E_REDIS_DB=13' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'HEARTH_REDIS_DATABASE=$redis_db' "$ROOT/deploy/bootstrap-native-env.sh"
grep -Fq 'database: ${HEARTH_REDIS_DATABASE:0}' "$ROOT/hearth-start/src/main/resources/application.yml"
! grep -Fq '"$NATIVE_ROOT/current"' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'User=hearth' "$ROOT/deploy/systemd/hearth-staging-native-app.service.in"
grep -Fq 'MemoryMax=384M' "$ROOT/deploy/systemd/hearth-staging-native-app.service.in"
grep -Fq -- '-XX:MaxRAMPercentage=55' "$ROOT/deploy/systemd/hearth-staging-native-app.service.in"
grep -Fq 'Conflicts=hearth-staging-native-app.service' "$ROOT/deploy/systemd/hearth-staging-native-test-slot.service.in"
grep -Fq 'SPRING_PROFILES_ACTIVE=$ENVIRONMENT-native' "$ROOT/deploy/bootstrap-native-env.sh"
grep -Fq 'NODE_OPTIONS=--max-old-space-size=384' "$ROOT/deploy/bootstrap-staging-runtime.sh"
grep -Fq 'MemAvailable' "$ROOT/deploy/bootstrap-staging-runtime.sh"
grep -Fq '/opt/hearth-native/e2e-runtime' "$ROOT/deploy/bootstrap-staging-runtime.sh"
grep -Fq 'lockfile_sha256' "$ROOT/deploy/bootstrap-staging-runtime.sh"
grep -Fq 'package_json_sha256' "$ROOT/deploy/bootstrap-staging-runtime.sh"
grep -Fq '$1 == "lockfile_sha256" {print $2}' "$ROOT/deploy/bootstrap-staging-runtime.sh"
grep -Fq '$1 == "package_json_sha256" {print $2}' "$ROOT/deploy/bootstrap-staging-runtime.sh"
grep -Fq 'index($0,"=")' "$ROOT/deploy/bootstrap-staging-runtime.sh"
if grep -Fq '\\"lockfile_sha256\\"' "$ROOT/deploy/bootstrap-staging-runtime.sh"; then
  printf 'Hearth runtime manifest awk programs must not escape quotes inside single-quoted scripts.\n' >&2
  exit 1
fi
grep -Fq 'MemAvailable' "$ROOT/deploy/run-staging-e2e-tests.sh"
grep -Fq 'systemd-run --scope' "$ROOT/deploy/run-staging-e2e-tests.sh"
grep -Fq 'MemoryMax=512M' "$ROOT/deploy/run-staging-e2e-tests.sh"
grep -Fq 'NODE_OPTIONS=--max-old-space-size=256' "$ROOT/deploy/run-staging-e2e-tests.sh"
grep -Fq 'groupadd --system hearth' "$ROOT/deploy/bootstrap-native-env.sh"
grep -Fq 'groupadd --system hearth' "$ROOT/deploy/migrate-staging-docker-source.sh"
grep -Fq 'on-profile: staging-native' "$ROOT/hearth-start/src/main/resources/application-staging-native.yml"
grep -Fq 'on-profile: production-native' "$ROOT/hearth-start/src/main/resources/application-production-native.yml"
grep -Fq 'User=hearth' "$ROOT/deploy/systemd/hearth-production-native-app.service.in"
grep -Fq 'port: ${HEARTH_APP_PORT:8080}' "$ROOT/hearth-start/src/main/resources/application.yml"
for profile in staging-native production-native staging-test; do
  grep -Fq 'address: 127.0.0.1' "$ROOT/hearth-start/src/main/resources/application-$profile.yml"
done
grep -Fq 'listen 127.0.0.1:$edge_port' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'access_log $ROOT_DIR/edge/logs/access.log;' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'error_log $ROOT_DIR/edge/logs/error.log warn;' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'install -d -o ubuntu -g hearth -m 0750 "$ROOT_DIR/edge/logs"' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'install -o ubuntu -g hearth -m 0660 /dev/null "$log_path"' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'hearth-native-edge.conf.template' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'command -v logrotate' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'install -o ubuntu -g ubuntu -m 0640 "$logrotate_tmp" "$ROOT_DIR/edge/logrotate.conf"' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'copytruncate' "$ROOT/deploy/logrotate/hearth-native-edge.conf.template"
grep -Fq 'size 10M' "$ROOT/deploy/logrotate/hearth-native-edge.conf.template"
grep -Fq 'rotate 14' "$ROOT/deploy/logrotate/hearth-native-edge.conf.template"
! grep -Fq 'postrotate' "$ROOT/deploy/logrotate/hearth-native-edge.conf.template"
grep -Fq 'User=ubuntu' "$ROOT/deploy/systemd/hearth-native-edge-logrotate.service.in"
grep -Fq 'copytruncate' "$ROOT/deploy/logrotate/hearth-native-edge.conf.template"
grep -Fq 'OnUnitActiveSec=5min' "$ROOT/deploy/systemd/hearth-native-edge-logrotate.timer.in"
grep -Fq 'LOGROTATE_TIMER' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'MemoryMax=' "$ROOT/deploy/systemd/hearth-staging-native-app.service.in"
grep -Fq 'install -d -o ubuntu -g ubuntu' "$ROOT/deploy/install-native-runtime.sh"
grep -Fq 'chown -R ubuntu:hearth "$ROOT_DIR/edge"' "$ROOT/deploy/install-native-runtime.sh"
! grep -Fq 'chown -R hearth:hearth "$ROOT_DIR/edge"' "$ROOT/deploy/install-native-runtime.sh"
if rg -n 'listen 80|listen 443' "$ROOT/deploy/systemd" >/dev/null; then
  printf 'Native Hearth units must not bind public ports.\n' >&2
  exit 1
fi
printf 'Hearth native runtime contract passed.\n'
