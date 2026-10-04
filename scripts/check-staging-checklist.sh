#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$SOURCE_ROOT/scripts/test-platform-version-contract.sh"
bash "$SOURCE_ROOT/scripts/test-hearth-documentation.sh"
git -C "$SOURCE_ROOT" diff --check
test -f "$SOURCE_ROOT/docs/architecture/decisions/0001-unified-identity-and-authorization-boundary.md"
test -f "$SOURCE_ROOT/hearth-start/src/main/resources/db/migration/V1__create_hearth_identity_tables.sql"
printf 'Hearth staging checklist contract passed.\n'
