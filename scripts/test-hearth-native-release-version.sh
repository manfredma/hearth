#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
touch "$tmp/history"

bash "$ROOT/deploy/verify-release-version.sh" v0.1.0 0.1.0 "$tmp/history"
if bash "$ROOT/deploy/verify-release-version.sh" v0.1.0 0.2.0 "$tmp/history" 2>/dev/null; then
  printf 'Release verifier accepted a tag/POM version mismatch.\n' >&2
  exit 1
fi
printf 'version=v0.1.0\ncommit=%040d\n' 1 > "$tmp/history"
if bash "$ROOT/deploy/verify-release-version.sh" v0.1.0 0.1.0 "$tmp/history" 2>/dev/null; then
  printf 'Release verifier accepted an already deployed SemVer tag.\n' >&2
  exit 1
fi
printf 'Hearth release version tests passed.\n'
