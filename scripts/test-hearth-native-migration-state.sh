#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/staging-dump-state.sh"

[[ "$(hearth_staging_dump_state 0 0 0 0)" == fresh ]] || exit 1
[[ "$(hearth_staging_dump_state 0 0 0 1)" == uncertain ]] || exit 1
[[ "$(hearth_staging_dump_state 0 0 1 1)" == recover-complete ]] || exit 1
[[ "$(hearth_staging_dump_state 0 1 1 1)" == ready ]] || exit 1
[[ "$(hearth_staging_dump_state 1 1 1 1)" == import-started ]] || exit 1
printf 'Hearth staging migration state tests passed.\n'
