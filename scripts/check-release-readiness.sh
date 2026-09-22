#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SOURCE_ROOT/scripts/lib/java-25.sh"
grep -Fqx '## Unreleased' "$SOURCE_ROOT/docs/releases/CHANGELOG.md"
awk '/^## Unreleased/{inside=1; next} /^## /{inside=0} inside && /^### /{found=1} END{exit(found ? 0 : 1)}' "$SOURCE_ROOT/docs/releases/CHANGELOG.md"
bash "$SOURCE_ROOT/scripts/check-hearth-naming.sh"
printf 'Hearth release readiness contract passed.\n'
