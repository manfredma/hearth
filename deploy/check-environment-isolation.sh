#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly PROD_ENV="$ROOT_DIR/deploy/.env.example"
readonly STAGING_ENV="$ROOT_DIR/deploy/.env.staging.example"

grep -Fq 'MYSQL_DATABASE: hearth' "$ROOT_DIR/deploy/docker-compose.single-host.yml"
grep -Fq 'hearth:staging:session:v1' "$ROOT_DIR/deploy/docker-compose.staging.yml"
grep -Fq 'HEARTH_STAGING_SESSION' "$ROOT_DIR/deploy/docker-compose.staging.yml"
grep -Fq 'HEARTH_REMEMBER_ME_KEY' "$ROOT_DIR/deploy/docker-compose.staging.yml"
grep -Fq 'HEARTH_REMEMBER_ME_COOKIE_SECURE: "true"' "$ROOT_DIR/deploy/docker-compose.staging.yml"
grep -Fq 'HEARTH_REMEMBER_ME_KEY' "$ROOT_DIR/deploy/docker-compose.single-host.yml"
grep -Fq '/opt/hearth/staging/mysql' "$ROOT_DIR/deploy/docker-compose.staging.yml"
grep -Fq '/opt/hearth/staging/redis' "$ROOT_DIR/deploy/docker-compose.staging.yml"
grep -Fq 'hearth-app:' "$ROOT_DIR/deploy/docker-compose.single-host.yml"
if grep -Eq '^[[:space:]]+app:' "$ROOT_DIR/deploy/docker-compose.single-host.yml" "$ROOT_DIR/deploy/docker-compose.staging.yml"; then
  echo 'generic compose service name app is forbidden' >&2
  exit 1
fi
test -s "$PROD_ENV"
test -s "$STAGING_ENV"
printf 'Hearth environment isolation contract passed.\n'
