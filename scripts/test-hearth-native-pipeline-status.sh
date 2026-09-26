#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/pipeline-status.sh"

hearth_require_successful_pipeline 0 0 0
for failed_status in '0 0 1' '0 1 0' '1 0 0'; do
  read -r -a statuses <<< "$failed_status"
  if hearth_require_successful_pipeline "${statuses[@]}"; then
    printf 'Pipeline validator accepted nonzero statuses: %s\n' "$failed_status" >&2
    exit 1
  fi
done
printf 'Hearth pipeline status tests passed.\n'
