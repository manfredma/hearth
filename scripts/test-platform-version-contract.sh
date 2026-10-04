#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -Fq 'optional:classpath:META-INF/build-info.properties' "$ROOT/hearth-start/src/main/resources/application.yml"
grep -Fq '@Value("${build.commitId:unknown}")' "$ROOT/hearth-adapter/src/main/java/manfred/hearth/adapter/web/identity/BuildInfoController.java"
grep -Fq '@Value("${build.time:unknown}")' "$ROOT/hearth-adapter/src/main/java/manfred/hearth/adapter/web/identity/BuildInfoController.java"
for entrypoint in deploy/deploy-staging.sh deploy/deploy-native-staging.sh deploy/deploy-native-production-remote.sh; do
  [[ ! -e "$ROOT/$entrypoint" ]] || { printf 'obsolete project release entrypoint exists: %s\n' "$entrypoint" >&2; exit 1; }
done
printf 'Hearth platform version contract passed.\n'
