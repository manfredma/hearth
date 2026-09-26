#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# -eq 3 && "$1" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'Usage: %s <full-commit-sha> <integration-evidence> <e2e-evidence>\n' "$0" >&2
  exit 2
}
readonly EXPECTED_COMMIT="$1"

verify_evidence() {
  local file="$1" expected_command="$2"
  [[ -f "$file" && ! -L "$file" ]] || { printf 'Missing or unsafe staging evidence: %s\n' "$file" >&2; return 1; }
  awk -F= -v expected_commit="$EXPECTED_COMMIT" -v expected_command="$expected_command" '
    NF != 2 { invalid = 1; next }
    $1 == "commit" && !seen_commit++ { commit = $2; next }
    $1 == "command" && !seen_command++ { command = $2; next }
    $1 == "result" && !seen_result++ { result = $2; next }
    { invalid = 1 }
    END {
      if (invalid || seen_commit != 1 || seen_command != 1 || seen_result != 1 ||
          commit != expected_commit || command != expected_command || result != "passed") exit 1
    }
  ' "$file" || { printf 'Staging evidence is not passed and bound to %s: %s\n' "$EXPECTED_COMMIT" "$file" >&2; return 1; }
}

verify_evidence "$2" run-staging-integration-tests
verify_evidence "$3" run-staging-e2e-tests
printf 'Staging integration and E2E evidence are passed for %s.\n' "$EXPECTED_COMMIT"
