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
printf 'Hearth staging evidence invalidation tests passed.\n'
