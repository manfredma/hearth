#!/usr/bin/env bash

hearth_require_successful_pipeline() {
  [[ $# -gt 0 ]] || return 2
  local index=0 status
  for status in "$@"; do
    if [[ ! "$status" =~ ^[0-9]+$ || "$status" != 0 ]]; then
      printf 'Pipeline stage %s failed with exit status %s.\n' "$index" "$status" >&2
      return 1
    fi
    index=$((index + 1))
  done
}
