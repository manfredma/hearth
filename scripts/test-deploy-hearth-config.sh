#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -x "$SOURCE_ROOT/deploy/check-environment-isolation.sh"
bash "$SOURCE_ROOT/deploy/check-environment-isolation.sh"
grep -Fq 'hearth-app' "$SOURCE_ROOT/deploy/docker-compose.single-host.yml"
grep -Fq 'HEARTH_OIDC_ENABLED' "$SOURCE_ROOT/deploy/.env.staging.example"
grep -Fq 'staging-hearth.bytedepth.cn' "$SOURCE_ROOT/deploy/nginx/staging-hearth.conf"
grep -Fq 'hearth-app:8080' "$SOURCE_ROOT/deploy/nginx/staging-hearth.conf"
printf 'Hearth deployment configuration contract passed.\n'
