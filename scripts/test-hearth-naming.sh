#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/hearth-naming-test.XXXXXX")"
trap 'rm -rf "$fixture_dir"' EXIT

mkdir -p "$fixture_dir/deploy"
printf '%s\n' 'services:' '  bytedepth-app:' > "$fixture_dir/deploy/illegal.yml"

if HEARTH_CHECK_ROOT="$fixture_dir" "$script_dir/check-hearth-naming.sh" >/dev/null 2>&1; then
  printf 'Expected the illegal fixture to fail the naming guard.\n' >&2
  exit 1
fi

rm "$fixture_dir/deploy/illegal.yml"
printf '%s\n' 'services:' '  hearth-app:' > "$fixture_dir/deploy/legal.yml"

if ! HEARTH_CHECK_ROOT="$fixture_dir" "$script_dir/check-hearth-naming.sh" >/dev/null; then
  printf 'Expected the legal fixture to pass the naming guard.\n' >&2
  exit 1
fi

printf 'Hearth naming guard test passed.\n'
