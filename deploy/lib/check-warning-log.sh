#!/usr/bin/env bash

hearth_assert_log_has_no_warning() {
  [[ $# -eq 1 && -f "$1" && -r "$1" ]] || {
    printf 'Warning scan log is missing or unreadable.\n' >&2
    return 2
  }
  local matches status
  if matches="$(rg -n -i '\bWARN(ING)?\b' "$1")"; then
    printf 'WARNING output found in %s.\n' "$1" >&2
    return 1
  else
    status=$?
    if (( status == 1 )); then return 0; fi
    printf 'Unable to scan warning log: %s\n' "$1" >&2
    return "$status"
  fi
}
