#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for file in \
  "$ROOT/deploy/hearth-native.conf.example" \
  "$ROOT/deploy/install-native-runtime.sh" \
  "$ROOT/deploy/systemd/hearth-staging-native-app.service.in" \
  "$ROOT/deploy/systemd/hearth-production-native-app.service.in" \
  "$ROOT/deploy/systemd/hearth-staging-native-edge.service.in" \
  "$ROOT/deploy/systemd/hearth-production-native-edge.service.in"; do
  test -f "$file" || { printf 'Missing native runtime file: %s\n' "$file" >&2; exit 1; }
done
grep -Fq 'HEARTH_NATIVE_STAGING_APP_PORT=18110' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'HEARTH_NATIVE_PRODUCTION_APP_PORT=18112' "$ROOT/deploy/hearth-native.conf.example"
grep -Fq 'User=hearth' "$ROOT/deploy/systemd/hearth-staging-native-app.service.in"
grep -Fq 'User=hearth' "$ROOT/deploy/systemd/hearth-production-native-app.service.in"
grep -Fq 'MemoryMax=' "$ROOT/deploy/systemd/hearth-staging-native-app.service.in"
grep -Fq 'install -d -o ubuntu -g ubuntu' "$ROOT/deploy/install-native-runtime.sh"
if rg -n 'listen 80|listen 443' "$ROOT/deploy/systemd" >/dev/null; then
  printf 'Native Hearth units must not bind public ports.\n' >&2
  exit 1
fi
printf 'Hearth native runtime contract passed.\n'
