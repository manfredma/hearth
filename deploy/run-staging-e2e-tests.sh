#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
readonly SOURCE_ROOT="${RELEASE_PLATFORM_TEST_SOURCE_ROOT:?Platform source snapshot is required}"
readonly STATE_ROOT=/var/lib/hearth-staging
readonly HISTORY="${RELEASE_PLATFORM_TEST_DEPLOY_HISTORY:?Platform deployment history is required}"
readonly EVIDENCE="${RELEASE_PLATFORM_TEST_EVIDENCE_DIR:?Platform evidence directory is required}/staging-e2e"
readonly LOCK="${RELEASE_PLATFORM_TEST_LOCK_FILE:?Platform deployment lock is required}"
readonly BASE=https://staging-hearth.bytedepth.cn
readonly DOMAIN=staging-hearth.bytedepth.cn
readonly CHROME=/opt/shared-e2e/chrome-linux64/chrome
readonly RUNTIME_MANIFEST="$STATE_ROOT/e2e-runtime.manifest"
source "$SOURCE_ROOT/deploy/lib/platform-staging-context.sh"
hearth_platform_test_context "$@"
source "$SOURCE_ROOT/deploy/lib/staging-test-slot.sh"
source "$SOURCE_ROOT/deploy/lib/pipeline-status.sh"
source "$SOURCE_ROOT/deploy/lib/check-warning-log.sh"
install -d -o ubuntu -g ubuntu -m 0700 "$STATE_ROOT" "$STATE_ROOT/test-history"
touch "$LOCK"
chown ubuntu:ubuntu "$LOCK"
chmod 0600 "$LOCK"
# The platform verifier already holds this deployment lock on inherited fd 9.
source "$SOURCE_ROOT/deploy/lib/invalidate-staging-evidence.sh"
hearth_invalidate_staging_evidence "$EVIDENCE"
HEARTH_STAGING_E2E_USERNAME="${E2E_ADMIN_USERNAME:-${HEARTH_STAGING_E2E_USERNAME:-}}"
HEARTH_STAGING_E2E_PASSWORD="${E2E_ADMIN_PASSWORD:-${HEARTH_STAGING_E2E_PASSWORD:-}}"
[[ -n "${HEARTH_STAGING_E2E_USERNAME:-}" && -n "${HEARTH_STAGING_E2E_PASSWORD:-}" ]] || { printf 'E2E administrator credentials must be explicitly injected; no account is created.\n' >&2; exit 1; }
[[ "$HEARTH_STAGING_E2E_USERNAME" != *$'\n'* && "$HEARTH_STAGING_E2E_PASSWORD" != *$'\n'* ]] || { printf 'E2E administrator credentials must be single-line values.\n' >&2; exit 1; }
commit="$(cat "$SOURCE_ROOT/.release-platform-source-commit")"
deployed="$(awk -F= '$1 == "commit" {v=$2} END {print v}' "$HISTORY")"
[[ "$commit" == "$deployed" && "$commit" =~ ^[0-9a-f]{40}$ ]] || { printf 'Hearth E2E SHA is not deployed.\n' >&2; exit 1; }
"$SOURCE_ROOT/deploy/bootstrap-staging-runtime.sh" --lock-held
[[ -x "$CHROME" && -f "$RUNTIME_MANIFEST" ]] || { printf 'Shared Chromium or Hearth E2E runtime manifest is missing.\n' >&2; exit 1; }
expected_lock="$(sha256sum "$SOURCE_ROOT/package-lock.json" | awk '{print $1}')"
expected_package="$(sha256sum "$SOURCE_ROOT/package.json" | awk '{print $1}')"
expected_node="$(sudo -n -u ubuntu -- node --version)"
manifest_lock="$(awk -F= '$1 == "lockfile_sha256" {print $2}' "$RUNTIME_MANIFEST")"
manifest_package="$(awk -F= '$1 == "package_json_sha256" {print $2}' "$RUNTIME_MANIFEST")"
manifest_node="$(awk -F= '$1 == "node_version" {print $2}' "$RUNTIME_MANIFEST")"
manifest_chrome="$(awk -F= '$1 == "chromium_version" {print substr($0, index($0, "=")+1); exit}' "$RUNTIME_MANIFEST")"
[[ "$manifest_lock" == "$expected_lock" && "$manifest_package" == "$expected_package" \
  && "$manifest_node" == "$expected_node" && "$manifest_chrome" == "$("$CHROME" --version)" ]] \
  || { printf 'Hearth E2E runtime manifest does not match dependencies/runtime.\n' >&2; exit 1; }
run_id="$(hearth_test_slot_new_run_id)"
log="$STATE_ROOT/e2e-$commit.log"
: > "$log"
chown ubuntu:ubuntu "$log"
chmod 0600 "$log"
cleanup_done=0
cleanup() {
  local status=$?
  if (( cleanup_done == 0 )) && [[ -n "${HEARTH_TEST_SLOT_MANIFEST:-}" ]]; then
    hearth_test_slot_end "$HEARTH_TEST_SLOT_MANIFEST" || status=1
  fi
  exit "$status"
}
trap cleanup EXIT
hearth_test_slot_begin e2e "$run_id"
available_kib="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)"
[[ "$available_kib" =~ ^[0-9]+$ && "$available_kib" -ge 393216 ]] || { printf 'Refusing Playwright start: need 384 MiB MemAvailable after test-slot startup.\n' >&2; exit 1; }
cd "$SOURCE_ROOT"
set +e
# Keep Bash parameter expansion and positional arguments intact in the transient service.
printf '%s\n%s\n' "$HEARTH_STAGING_E2E_USERNAME" "$HEARTH_STAGING_E2E_PASSWORD" | \
  systemd-run --expand-environment=no --unit="hearth-staging-e2e-$run_id.service" --collect --quiet --wait --pipe --property=MemoryMax=512M \
    /usr/bin/bash -c '
    set -Eeuo pipefail
    IFS= read -r admin_username
    IFS= read -r admin_password
    [[ -n "$admin_username" && -n "$admin_password" ]]
    export HEARTH_E2E_ADMIN_USERNAME="$admin_username"
    export HEARTH_E2E_ADMIN_PASSWORD="$admin_password"
    unset admin_username admin_password
    cd "$5"
    exec sudo -n --preserve-env=HEARTH_E2E_ADMIN_USERNAME,HEARTH_E2E_ADMIN_PASSWORD -u ubuntu -- env NODE_OPTIONS=--max-old-space-size=256 E2E_BASE_URL="$1" \
      HEARTH_EXPECTED_COMMIT="$2" \
      HEARTH_E2E_EXPECTED_ISSUER="$1" \
      HEARTH_E2E_HOST_RESOLVER_RULES="MAP $4 127.0.0.1" \
      PLAYWRIGHT_CHROMIUM_EXECUTABLE="$3" \
      PLAYWRIGHT_JSON_OUTPUT_FILE="$6" npm run test:e2e -- --reporter=list,json
  ' hearth-e2e "$BASE" "$commit" "$CHROME" "$DOMAIN" "$SOURCE_ROOT" "$log.json" 2>&1 | tee "$log"
pipeline_statuses=("${PIPESTATUS[@]}")
set -e
[[ ${#pipeline_statuses[@]} -eq 3 ]] || { printf 'E2E output pipeline status is incomplete.\n' >&2; exit 1; }
hearth_require_successful_pipeline "${pipeline_statuses[@]}" || { printf 'Hearth Playwright or its log capture failed.\n' >&2; exit 1; }
hearth_assert_log_has_no_warning "$log" || { printf 'Hearth staging E2E emitted WARNING or its log could not be scanned.\n' >&2; exit 1; }
tests_total="$(jq -er '.stats | select(.unexpected == 0 and .expected > 0) | .expected' "$log.json")"
[[ "$tests_total" =~ ^[1-9][0-9]*$ ]] || { printf 'No passing E2E cases were executed.\n' >&2; exit 1; }
hearth_test_slot_end "$HEARTH_TEST_SLOT_MANIFEST"
cleanup_done=1
[[ "$(cat "$SOURCE_ROOT/.release-platform-source-commit")" == "$commit" && "$(awk -F= '$1 == "commit" {v=$2} END {print v}' "$HISTORY")" == "$commit" ]] || { printf 'Hearth E2E candidate SHA changed during test.\n' >&2; exit 1; }
hearth_platform_test_context "$@"
printf 'commit=%s\nartifact_digest=%s\nattempt_nonce=%s\ncommand=run-staging-e2e-tests\nresult=passed\ncleanup=result=passed\ntests_total=%s\n' "$commit" "$RELEASE_PLATFORM_TEST_ARTIFACT_DIGEST" "$RELEASE_PLATFORM_TASK_NONCE" "$tests_total" > "$EVIDENCE.tmp"
chown ubuntu:ubuntu "$EVIDENCE.tmp"
chmod 0600 "$EVIDENCE.tmp"
mv "$EVIDENCE.tmp" "$EVIDENCE"
printf 'Hearth native staging E2E passed for %s.\n' "$commit"
