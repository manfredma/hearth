#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/invalidate-staging-evidence.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
printf 'result=passed\n' > "$tmp/evidence"
printf 'partial\n' > "$tmp/evidence.tmp"
hearth_invalidate_staging_evidence "$tmp/evidence"
[[ ! -e "$tmp/evidence" && ! -e "$tmp/evidence.tmp" ]]
# Execute the real lock-to-credential-preflight section without host operations.
awk '/^flock -x 9$/ {inside=1} /^commit=/ {exit} inside {print}' "$ROOT/deploy/run-staging-e2e-tests.sh" > "$tmp/preflight.sh"
for credential_case in missing multiline; do
  printf 'result=passed\n' > "$tmp/evidence"
  printf 'result=passed\n' > "$tmp/evidence.tmp"
  if (
    export SOURCE_ROOT="$ROOT" EVIDENCE="$tmp/evidence"
    flock() { [[ -f "$EVIDENCE" ]]; }
    export -f flock
    unset HEARTH_STAGING_E2E_USERNAME HEARTH_STAGING_E2E_PASSWORD
    if [[ "$credential_case" == multiline ]]; then
      export HEARTH_STAGING_E2E_USERNAME=admin HEARTH_STAGING_E2E_PASSWORD=$'bad\ncredential'
    fi
    bash -e "$tmp/preflight.sh"
  ) > "$tmp/output" 2>&1; then
    printf 'Invalid E2E credentials accepted.\n' >&2
    exit 1
  fi
  [[ ! -e "$tmp/evidence" && ! -e "$tmp/evidence.tmp" ]]
done
printf 'Hearth staging evidence invalidation tests passed.\n'
