#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
readonly SOURCE_ROOT=/opt/hearth-native/source/current
readonly STATE_ROOT=/var/lib/hearth-staging
readonly HISTORY="$STATE_ROOT/deploy-history"
readonly EVIDENCE="$STATE_ROOT/test-history/staging-integration"
readonly LOCK="$STATE_ROOT/deployment-test.lock"
readonly MAVEN_REPOSITORY=/opt/shared-maven/repository
readonly MAVEN_REPOSITORY_LOCK=/opt/shared-maven/repository.lock
readonly BASE=https://staging-hearth.bytedepth.cn
readonly DOMAIN=staging-hearth.bytedepth.cn
source "$SOURCE_ROOT/deploy/lib/staging-test-slot.sh"
source "$SOURCE_ROOT/deploy/lib/invalidate-staging-evidence.sh"
source "$SOURCE_ROOT/deploy/lib/pipeline-status.sh"
source "$SOURCE_ROOT/deploy/lib/check-warning-log.sh"
commit="$(cat "$SOURCE_ROOT/.hearth-commit")"
deployed="$(awk -F= '$1 == "commit" {v=$2} END {print v}' "$HISTORY")"
[[ "$commit" == "$deployed" && "$commit" =~ ^[0-9a-f]{40}$ ]] || { printf 'Hearth integration SHA is not deployed.\n' >&2; exit 1; }
install -d -o ubuntu -g ubuntu -m 0700 "$STATE_ROOT/test-history"
touch "$LOCK"
chown ubuntu:ubuntu "$LOCK"
chmod 0600 "$LOCK"
exec 9>>"$LOCK"
flock -x 9
hearth_invalidate_staging_evidence "$EVIDENCE"
run_id="$(date -u +%Y%m%dt%H%M%S)_$(openssl rand -hex 4)"
cleanup_done=0
cookie=""
response=""
maven_log=""
cleanup() {
  local status=$?
  [[ -z "$cookie" ]] || rm -f -- "$cookie"
  [[ -z "$response" ]] || rm -f -- "$response"
  [[ -z "$maven_log" ]] || rm -f -- "$maven_log"
  if (( cleanup_done == 0 )) && [[ -n "${HEARTH_TEST_SLOT_MANIFEST:-}" ]]; then
    hearth_test_slot_end "$HEARTH_TEST_SLOT_MANIFEST" || status=1
  fi
  exit "$status"
}
trap cleanup EXIT
hearth_test_slot_begin integration "$run_id"
[[ -d "$MAVEN_REPOSITORY" && -r "$MAVEN_REPOSITORY" && -r "$MAVEN_REPOSITORY_LOCK" ]] || {
  printf 'The shared read-only Maven repository or its global lock is unavailable.\n' >&2
  exit 1
}
exec 8<"$MAVEN_REPOSITORY_LOCK"
flock -s 8
maven_log="$(mktemp /run/hearth/it-maven.XXXXXX)"
chown ubuntu:hearth "$maven_log"
chmod 0600 "$maven_log"
summary="$SOURCE_ROOT/hearth-start/target/failsafe-reports/failsafe-summary.xml"
rm -f -- "$summary"
set +e
systemd-run --scope --quiet --wait --pipe \
  --unit="hearth-staging-integration-$run_id.scope" \
  --property=MemoryMax=512M --property=MemorySwapMax=0 \
  /usr/bin/bash -c '
    set -Eeuo pipefail
    while IFS= read -r entry; do
      [[ "$entry" == *=* ]] || continue
      key="${entry%%=*}"
      value="${entry#*=}"
      [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && export "$key=$value"
    done < /run/hearth/staging-test-slot.env
    [[ -n "${HEARTH_REDIS_PASSWORD:-}" ]] || { printf "Test-slot Redis password is missing.\\n" >&2; exit 1; }
    export HEARTH_IT_REDIS_PASSWORD="$HEARTH_REDIS_PASSWORD"
    export MAVEN_OPTS=-Xmx160m
    cd /opt/hearth-native/source/current
    exec sudo -n -u ubuntu --preserve-env=HEARTH_DATASOURCE_URL,HEARTH_DATASOURCE_USERNAME,HEARTH_DATASOURCE_PASSWORD,HEARTH_REDIS_HOST,HEARTH_REDIS_PORT,HEARTH_REDIS_DATABASE,HEARTH_REDIS_PASSWORD,HEARTH_SESSION_REDIS_NAMESPACE,HEARTH_IT_REDIS_PASSWORD,MAVEN_OPTS -- ./mvnw --offline -B -Dmaven.repo.local=/opt/shared-maven/repository -Pstaging-integration -pl hearth-start -am verify
  ' 2>&1 | tee "$maven_log"
pipeline_statuses=("${PIPESTATUS[@]}")
set -e
hearth_assert_log_has_no_warning "$maven_log" || { printf 'Hearth Maven staging integration emitted WARNING or its log could not be scanned.\n' >&2; exit 1; }
[[ ${#pipeline_statuses[@]} -eq 2 ]] || { printf 'Maven output pipeline status is incomplete.\n' >&2; exit 1; }
hearth_require_successful_pipeline "${pipeline_statuses[@]}" || { printf 'Hearth Maven staging integration or log capture failed.\n' >&2; exit 1; }
[[ -f "$summary" ]] || { printf 'Maven Failsafe summary is missing.\n' >&2; exit 1; }
completed="$(sed -n 's/.*<completed>\([0-9][0-9]*\)<\/completed>.*/\1/p' "$summary")"
failures="$(sed -n 's/.*<failures>\([0-9][0-9]*\)<\/failures>.*/\1/p' "$summary")"
errors="$(sed -n 's/.*<errors>\([0-9][0-9]*\)<\/errors>.*/\1/p' "$summary")"
[[ "$completed" =~ ^[1-9][0-9]*$ && "$failures" == 0 && "$errors" == 0 ]] || {
  printf 'Maven Failsafe must report at least one completed integration test and zero failures/errors.\n' >&2
  exit 1
}
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
rm -f -- "$maven_log"
maven_log=""
hearth_test_slot_end "$HEARTH_TEST_SLOT_MANIFEST"
cleanup_done=1
[[ "$(cat "$SOURCE_ROOT/.hearth-commit")" == "$commit" && "$(awk -F= '$1 == "commit" {v=$2} END {print v}' "$HISTORY")" == "$commit" ]] || { printf 'Hearth integration candidate SHA changed during test.\n' >&2; exit 1; }
printf 'commit=%s\ncommand=run-staging-integration-tests\nresult=passed\n' "$commit" > "$EVIDENCE.tmp"
chown ubuntu:ubuntu "$EVIDENCE.tmp"
chmod 0600 "$EVIDENCE.tmp"
mv "$EVIDENCE.tmp" "$EVIDENCE"
printf 'Hearth native staging integration checks passed for %s.\n' "$commit"
