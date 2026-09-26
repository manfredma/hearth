#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/staging-certificate-current.sh"

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf -- "$tmp"' EXIT
readonly RELEASE_ROOT="$tmp/releases"
readonly CURRENT="$tmp/current"
mkdir -p "$RELEASE_ROOT/old" "$RELEASE_ROOT/new"
printf old > "$RELEASE_ROOT/old/fullchain.pem"
printf old-key > "$RELEASE_ROOT/old/privkey.pem"
printf new > "$RELEASE_ROOT/new/fullchain.pem"
printf new-key > "$RELEASE_ROOT/new/privkey.pem"

hearth_staging_replace_tls_link() {
  rm -f -- "$2"
  mv "$1" "$2"
}
ln -s "$RELEASE_ROOT/old" "$CURRENT"
hearth_staging_promote_tls_current "$CURRENT" "$RELEASE_ROOT" "$RELEASE_ROOT/new"
[[ "$(readlink -f "$CURRENT")" == "$RELEASE_ROOT/new" ]]
[[ -f "$RELEASE_ROOT/old/fullchain.pem" && -f "$RELEASE_ROOT/old/privkey.pem" ]]

rm "$CURRENT"
mkdir "$CURRENT"
printf legacy > "$CURRENT/fullchain.pem"
printf legacy-key > "$CURRENT/privkey.pem"
hearth_staging_promote_tls_current "$CURRENT" "$RELEASE_ROOT" "$RELEASE_ROOT/old"
[[ -L "$CURRENT" && "$(readlink -f "$CURRENT")" == "$RELEASE_ROOT/old" ]]
legacy_count="$(find "$RELEASE_ROOT" -maxdepth 1 -type d -name 'legacy-current-*' | wc -l | tr -d ' ')"
[[ "$legacy_count" == 1 ]]

printf 'Hearth staging TLS promotion tests passed.\n'
