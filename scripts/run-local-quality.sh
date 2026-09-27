#!/usr/bin/env bash
set -Eeuo pipefail

# One local-only quality entry point for an isolated worktree.
# It prepares this worktree's untracked node_modules before any frontend tool.
# Usage: bash scripts/run-local-quality.sh
readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SOURCE_ROOT/scripts/lib/java-25.sh"
source "$SOURCE_ROOT/scripts/lib/run-checked.sh"

cd "$SOURCE_ROOT"
run_checked bash scripts/check-release-readiness.sh
run_checked npm ci --ignore-scripts --no-audit --no-fund
readonly JAVA_25_HOME="$(resolve_java_25)"
run_checked env JAVA_HOME="$JAVA_25_HOME" "$SOURCE_ROOT/mvnw" clean install -DskipTests -Dsort.skip=true
run_checked env JAVA_HOME="$JAVA_25_HOME" "$SOURCE_ROOT/mvnw" test -Dsort.skip=true
run_checked npm test
run_checked npm run lint
run_checked bash scripts/verify-changed-coverage.sh
run_checked bash scripts/check-staging-checklist.sh
run_checked git diff --check
