#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/staging-certificate-current.sh"

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
ln -s "$ROOT/scripts/test-fixtures/atomic-mv" "$tmp/bin/mv"
export PATH="$tmp/bin:$PATH"
export HEARTH_ATOMIC_MV_LOG="$tmp/atomic-mv.log"
readonly RELEASE_ROOT="$tmp/releases"
readonly CURRENT="$tmp/current"
mkdir -p "$RELEASE_ROOT/old" "$RELEASE_ROOT/new"
printf old > "$RELEASE_ROOT/old/fullchain.pem"
printf old-key > "$RELEASE_ROOT/old/privkey.pem"
printf new > "$RELEASE_ROOT/new/fullchain.pem"
printf new-key > "$RELEASE_ROOT/new/privkey.pem"

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

rm "$CURRENT"
mkdir "$CURRENT"
printf failed > "$CURRENT/fullchain.pem"
printf failed-key > "$CURRENT/privkey.pem"
hearth_staging_create_tls_link() { return 1; }
if hearth_staging_promote_tls_current "$CURRENT" "$RELEASE_ROOT" "$RELEASE_ROOT/new"; then
  printf 'TLS promotion ignored a temporary-link creation failure.\n' >&2
  exit 1
fi
[[ -d "$CURRENT" && ! -L "$CURRENT" && "$(<"$CURRENT/fullchain.pem")" == failed ]]
grep -Fxq -- '-Tf' "$HEARTH_ATOMIC_MV_LOG"

printf 'Hearth staging TLS promotion tests passed.\n'
