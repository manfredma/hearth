#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

commit=0123456789abcdef0123456789abcdef01234567
for suite in integration e2e; do
  command="run-staging-${suite}-tests"
  printf 'commit=%s\ncommand=%s\nresult=passed\n' "$commit" "$command" > "$tmp/$suite"
done

bash "$ROOT/deploy/verify-staging-evidence.sh" "$commit" "$tmp/integration" "$tmp/e2e"

printf 'commit=%s\ncommand=run-staging-integration-tests\nresult=failed\n' "$commit" > "$tmp/integration"
if bash "$ROOT/deploy/verify-staging-evidence.sh" "$commit" "$tmp/integration" "$tmp/e2e" 2>/dev/null; then
  printf 'Verifier accepted failed integration evidence.\n' >&2
  exit 1
fi

printf 'commit=%s\ncommand=run-staging-e2e-tests\nresult=passed\n' 1111111111111111111111111111111111111111 > "$tmp/e2e"
if bash "$ROOT/deploy/verify-staging-evidence.sh" "$commit" "$tmp/integration" "$tmp/e2e" 2>/dev/null; then
  printf 'Verifier accepted evidence for a different SHA.\n' >&2
  exit 1
fi

printf 'Hearth staging release evidence tests passed.\n'
