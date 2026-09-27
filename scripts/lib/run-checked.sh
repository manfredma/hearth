#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/deploy/lib/check-warning-log.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/deploy/lib/pipeline-status.sh"

run_checked() {
  local log statuses result=0
  log="$(mktemp "${TMPDIR:-/tmp}/hearth-quality.XXXXXX")" || return 1
  set +e
  "$@" 2>&1 | tee "$log"
  statuses=("${PIPESTATUS[@]}")
  set -e
  hearth_require_successful_pipeline "${statuses[@]}" || result=1
  hearth_assert_log_has_no_warning "$log" || result=1
  if (( result != 0 )); then
    printf 'Quality step failed; captured output: %s\n' "$log" >&2
    return 1
  fi
  rm -f -- "$log"
}
