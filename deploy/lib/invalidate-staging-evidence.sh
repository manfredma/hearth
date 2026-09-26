#!/usr/bin/env bash

hearth_invalidate_staging_evidence() {
  [[ $# -eq 1 && -n "$1" ]] || return 2
  [[ ! -d "$1" && ! -d "$1.tmp" ]] || { printf 'Refusing to replace a staging evidence directory.\n' >&2; return 1; }
  rm -f -- "$1" "$1.tmp"
}
