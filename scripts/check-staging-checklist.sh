#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SOURCE_ROOT/scripts/lib/java-25.sh"
bash "$SOURCE_ROOT/scripts/check-release-readiness.sh"
bash "$SOURCE_ROOT/scripts/test-deploy-hearth-config.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-documentation.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-runtime.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-migration.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-nginx.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-deployment.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-release-evidence.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-release-version.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-production-transaction.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-staging-certificate.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-evidence-invalidation.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-pipeline-status.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-native-test-slot.sh"
test -f "$SOURCE_ROOT/docs/architecture/decisions/0001-unified-identity-and-authorization-boundary.md"
test -f "$SOURCE_ROOT/hearth-start/src/main/resources/db/migration/V1__create_hearth_identity_tables.sql"
printf 'Hearth staging checklist contract passed.\n'
