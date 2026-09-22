#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -x "$SOURCE_ROOT/deploy/check-environment-isolation.sh"
bash "$SOURCE_ROOT/deploy/check-environment-isolation.sh"
grep -Fq 'hearth-app' "$SOURCE_ROOT/deploy/docker-compose.single-host.yml"
grep -Fq 'HEARTH_OIDC_ENABLED' "$SOURCE_ROOT/deploy/.env.staging.example"
printf 'Hearth deployment configuration contract passed.\n'
