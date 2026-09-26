#!/usr/bin/env bash

hearth_staging_dump_state() {
  [[ $# -eq 4 ]] || return 2
  local import_started="$1" ready="$2" clean="$3" dump_exists="$4"
  [[ "$import_started" =~ ^[01]$ && "$ready" =~ ^[01]$ && "$clean" =~ ^[01]$ && "$dump_exists" =~ ^[01]$ ]] || return 2
  if [[ "$import_started" == 1 ]]; then
    printf 'import-started\n'
  elif [[ "$ready" == 1 ]]; then
    printf 'ready\n'
  elif [[ "$clean" == 1 ]]; then
    printf 'recover-complete\n'
  elif [[ "$dump_exists" == 1 ]]; then
    printf 'uncertain\n'
  else
    printf 'fresh\n'
  fi
}
