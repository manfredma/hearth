#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/check-warning-log.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

printf 'build complete\n' > "$tmp/clean.log"
printf 'WARNING. unexpected tool output\n' > "$tmp/warning.log"
hearth_assert_log_has_no_warning "$tmp/clean.log"
if hearth_assert_log_has_no_warning "$tmp/warning.log" 2>/dev/null; then
  printf 'Warning checker accepted WARNING followed by punctuation.\n' >&2
  exit 1
fi
if hearth_assert_log_has_no_warning "$tmp/missing.log" 2>/dev/null; then
  printf 'Warning checker accepted an unreadable log.\n' >&2
  exit 1
fi
printf 'Hearth warning-log tests passed.\n'
