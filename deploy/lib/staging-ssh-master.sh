#!/usr/bin/env bash

hearth_ensure_staging_ssh_master() {
  [[ $# -ge 2 ]] || { printf 'Usage: hearth_ensure_staging_ssh_master <user@host> <ssh-options...>\n' >&2; return 2; }
  local target="$1"
  shift
  local attempt

  if ssh "$@" -O check "$target" >/dev/null 2>&1; then
    return 0
  fi
  for attempt in 1 2 3 4 5; do
    if ssh "$@" -MNf "$target"; then
      return 0
    fi
    if ssh "$@" -O check "$target" >/dev/null 2>&1; then
      return 0
    fi
    if (( attempt < 5 )); then
      sleep 2
    fi
  done
  printf 'Unable to establish the Hearth staging SSH master after five attempts.\n' >&2
  return 1
}
