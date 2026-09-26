#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# -eq 3 && "$1" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  printf 'Usage: %s vX.Y.Z <pom-version> <production-history>\n' "$0" >&2
  exit 2
}
readonly TAG="$1"
readonly POM_VERSION="$2"
readonly HISTORY="$3"
[[ "${TAG#v}" == "$POM_VERSION" ]] || { printf 'Release tag does not match the candidate POM version.\n' >&2; exit 1; }
[[ -f "$HISTORY" && ! -L "$HISTORY" ]] || { printf 'Production release history is missing or unsafe.\n' >&2; exit 1; }
if awk -F= -v version="$TAG" '$1 == "version" && $2 == version {found = 1} END {exit !found}' "$HISTORY"; then
  printf 'Release tag was already deployed to production.\n' >&2
  exit 1
fi
printf 'Release version %s matches POM and is not in production history.\n' "$TAG"
