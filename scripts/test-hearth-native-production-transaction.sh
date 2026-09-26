#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/production-release-transaction.sh"

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
ln -s "$ROOT/scripts/test-fixtures/atomic-mv" "$tmp/bin/mv"
export PATH="$tmp/bin:$PATH"
export HEARTH_ATOMIC_MV_LOG="$tmp/atomic-mv.log"
mkdir -p "$tmp/releases/old" "$tmp/releases/new" "$tmp/sources/old" "$tmp/sources/new"
ln -s "$tmp/releases/old" "$tmp/current"
ln -s "$tmp/sources/old" "$tmp/source-current"

unit_app=active
unit_edge=active
restart_count=0
stop_count=0
fail_first_app_restart=0
systemctl() {
  case "$1:$2" in
    is-active:--quiet) [[ "$3" == app.service && "$unit_app" == active || "$3" == edge.service && "$unit_edge" == active ]] ;;
    restart:app.service)
      restart_count=$((restart_count + 1))
      if (( fail_first_app_restart == 1 )); then fail_first_app_restart=0; return 1; fi
      unit_app=active
      ;;
    restart:edge.service) unit_edge=active ;;
    stop:app.service) stop_count=$((stop_count + 1)); unit_app=inactive ;;
    stop:edge.service) unit_edge=inactive ;;
    *) return 2 ;;
  esac
}

fail_first_app_restart=1
if hearth_production_release_begin "$tmp/current" "$tmp/source-current" "$tmp/releases/new" "$tmp/sources/new" app.service edge.service; then
  printf 'Release transaction ignored an app restart failure.\n' >&2
  exit 1
fi
hearth_production_release_rollback
[[ "$(readlink -f "$tmp/current")" == "$tmp/releases/old" ]]
[[ "$(readlink -f "$tmp/source-current")" == "$tmp/sources/old" ]]
[[ "$unit_app" == active && "$unit_edge" == active && "$restart_count" -eq 2 ]]

restart_count=0
hearth_production_release_begin "$tmp/current" "$tmp/source-current" "$tmp/releases/new" "$tmp/sources/new" app.service edge.service
[[ "$(readlink -f "$tmp/current")" == "$tmp/releases/new" ]]
hearth_production_release_rollback
[[ "$(readlink -f "$tmp/current")" == "$tmp/releases/old" ]]
[[ "$(readlink -f "$tmp/source-current")" == "$tmp/sources/old" ]]
[[ "$unit_app" == active && "$unit_edge" == active && "$restart_count" -eq 2 ]]

rm "$tmp/current" "$tmp/source-current"
unit_app=inactive
unit_edge=inactive
hearth_production_release_begin "$tmp/current" "$tmp/source-current" "$tmp/releases/new" "$tmp/sources/new" app.service edge.service
hearth_production_release_rollback
[[ ! -e "$tmp/current" && ! -L "$tmp/current" ]]
[[ ! -e "$tmp/source-current" && ! -L "$tmp/source-current" ]]
[[ "$unit_app" == inactive && "$unit_edge" == inactive && "$stop_count" -eq 1 ]]
grep -Fxq -- '-Tf' "$HEARTH_ATOMIC_MV_LOG"

printf 'Hearth production release transaction tests passed.\n'
