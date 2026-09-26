#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
readonly SOURCE_ROOT=/opt/hearth-native/source/current
readonly STATE_ROOT=/var/lib/hearth-staging
readonly HISTORY="$STATE_ROOT/deploy-history"
readonly EVIDENCE="$STATE_ROOT/test-history/staging-integration"
readonly LOCK="$STATE_ROOT/deployment-test.lock"
readonly BASE=https://staging-hearth.bytedepth.cn
readonly DOMAIN=staging-hearth.bytedepth.cn
source "$SOURCE_ROOT/deploy/lib/staging-test-slot.sh"
commit="$(cat "$SOURCE_ROOT/.hearth-commit")"
deployed="$(awk -F= '$1 == "commit" {v=$2} END {print v}' "$HISTORY")"
[[ "$commit" == "$deployed" && "$commit" =~ ^[0-9a-f]{40}$ ]] || { printf 'Hearth integration SHA is not deployed.\n' >&2; exit 1; }
install -d -o ubuntu -g ubuntu -m 0700 "$STATE_ROOT/test-history"
touch "$LOCK"
chown ubuntu:ubuntu "$LOCK"
chmod 0600 "$LOCK"
exec 9>>"$LOCK"
flock -x 9
rm -f -- "$EVIDENCE"
run_id="$(date -u +%Y%m%dt%H%M%S)_$(openssl rand -hex 4)"
cleanup_done=0
cookie=""
response=""
cleanup() {
  local status=$?
  [[ -z "$cookie" ]] || rm -f -- "$cookie"
  [[ -z "$response" ]] || rm -f -- "$response"
  if (( cleanup_done == 0 )) && [[ -n "${HEARTH_TEST_SLOT_MANIFEST:-}" ]]; then
    hearth_test_slot_end "$HEARTH_TEST_SLOT_MANIFEST" || status=1
  fi
  exit "$status"
}
trap cleanup EXIT
hearth_test_slot_begin integration "$run_id"
cookie="$(mktemp /run/hearth/it-cookie.XXXXXX)"
response="$(mktemp /run/hearth/it-response.XXXXXX)"
chown ubuntu:hearth "$cookie" "$response"
chmod 0600 "$cookie" "$response"
version_json="$(curl --fail --silent --show-error --max-time 15 --resolve "$DOMAIN:443:127.0.0.1" "$BASE/version")"
printf '%s' "$version_json" | jq -e --arg commit "$commit" '.commitId == $commit and .version != "unknown"' >/dev/null
curl --fail --silent --show-error --max-time 15 --resolve "$DOMAIN:443:127.0.0.1" "$BASE/api/health" | jq -e '.status == "ok" and .service == "hearth"' >/dev/null
discovery="$(curl --fail --silent --show-error --max-time 15 --resolve "$DOMAIN:443:127.0.0.1" "$BASE/.well-known/openid-configuration")"
printf '%s' "$discovery" | jq -e --arg issuer "$BASE" '.issuer == $issuer and (.authorization_endpoint | contains("/oauth2/authorize")) and (.jwks_uri | contains("/oauth2/jwks"))' >/dev/null
jwks_uri="$(printf '%s' "$discovery" | jq -er '.jwks_uri')"
curl --fail --silent --show-error --max-time 10 --resolve "$DOMAIN:443:127.0.0.1" "$jwks_uri" | jq -e '.keys | length > 0' >/dev/null
csrf="$(curl --fail --silent --show-error --max-time 10 --resolve "$DOMAIN:443:127.0.0.1" -c "$cookie" -b "$cookie" -H 'Accept: application/json' "$BASE/api/csrf" | jq -er '.token')"
status="$(curl --silent --show-error --max-time 10 --resolve "$DOMAIN:443:127.0.0.1" -o "$response" -w '%{http_code}' -c "$cookie" -b "$cookie" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "X-CSRF-TOKEN=$csrf" --data "{\"login\":\"native-missing-$run_id\",\"password\":\"invalid-e2e-password\"}" "$BASE/api/login")"
[[ "$status" == 401 && "$(jq -r '.authenticated' "$response")" == false ]] || { printf 'Invalid login did not return the expected 401 response.\n' >&2; exit 1; }
rm -f -- "$cookie" "$response"
cookie=""
response=""
hearth_test_slot_end "$HEARTH_TEST_SLOT_MANIFEST"
cleanup_done=1
[[ "$(cat "$SOURCE_ROOT/.hearth-commit")" == "$commit" && "$(awk -F= '$1 == "commit" {v=$2} END {print v}' "$HISTORY")" == "$commit" ]] || { printf 'Hearth integration candidate SHA changed during test.\n' >&2; exit 1; }
printf 'commit=%s\ncommand=run-staging-integration-tests\nresult=passed\n' "$commit" > "$EVIDENCE.tmp"
chown ubuntu:ubuntu "$EVIDENCE.tmp"
chmod 0600 "$EVIDENCE.tmp"
mv "$EVIDENCE.tmp" "$EVIDENCE"
printf 'Hearth native staging integration checks passed for %s.\n' "$commit"
