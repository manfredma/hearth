#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -x "$SOURCE_ROOT/deploy/check-environment-isolation.sh"
bash "$SOURCE_ROOT/deploy/check-environment-isolation.sh"
grep -Fq 'hearth-app' "$SOURCE_ROOT/deploy/docker-compose.single-host.yml"
grep -Fq 'HEARTH_OIDC_ISSUER=https://staging-hearth.bytedepth.cn' "$SOURCE_ROOT/deploy/.env.staging.example"
grep -Fq 'HEARTH_SIGNING_KEY=' "$SOURCE_ROOT/deploy/.env.staging.example"
grep -Fq 'staging-hearth.bytedepth.cn' "$SOURCE_ROOT/deploy/nginx/staging-hearth.conf"
grep -Fq 'hearth-app:8080' "$SOURCE_ROOT/deploy/nginx/staging-hearth.conf"
grep -Fq 'maven:3.9.11-eclipse-temurin-25' "$SOURCE_ROOT/deploy/deploy-staging.sh"
grep -Fq './mvnw -B clean install -DskipTests -Dsort.skip=true' "$SOURCE_ROOT/deploy/deploy-staging.sh"
grep -Fq '/opt/shared-maven/repository.lock' "$SOURCE_ROOT/deploy/deploy-staging.sh"
grep -Fq 'HEARTH_REPOSITORY_URL:-git@github.com:manfredma/hearth.git' "$SOURCE_ROOT/deploy/deploy-staging.sh"
grep -Fqx 'COPY public public' "$SOURCE_ROOT/Dockerfile"
printf 'Hearth deployment configuration contract passed.\n'
