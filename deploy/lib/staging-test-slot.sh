#!/usr/bin/env bash

HEARTH_TEST_SLOT_STATE_ROOT=/var/lib/hearth-staging/test-slots
HEARTH_TEST_SLOT_RUNTIME_ENV=/run/hearth/staging-test-slot.env
HEARTH_TEST_SLOT_SERVICE=hearth-staging-native-test-slot.service
HEARTH_TEST_SLOT_MAIN_SERVICE=hearth-staging-native-app.service
HEARTH_TEST_SLOT_EDGE_SERVICE=hearth-staging-native-edge.service
HEARTH_TEST_SLOT_APP_HEALTH=http://127.0.0.1:18110/api/health
HEARTH_TEST_SLOT_EDGE_HEALTH=http://127.0.0.1:18111/api/health
HEARTH_TEST_SLOT_MINIMUM_AVAILABLE_KIB=655360
HEARTH_TEST_SLOT_STARTED_AT=""

hearth_test_slot_check_journal() {
  local service="$1" since="$2" journal
  journal="$(journalctl --unit "$service" --since "$since" --no-pager --output=short-iso)"
  if grep -n -E -i '(^|[^[:alnum:]_])WARN(ING)?([^[:alnum:]_]|$)' <<< "$journal" >/dev/null; then
    printf 'Hearth staging service emitted WARNING during test slot: %s\n' "$service" >&2
    return 1
  fi
}

hearth_test_slot_wait_http() {
  local service="$1" url="$2" ready=0 attempt
  for attempt in $(seq 1 60); do
    if curl --fail --silent --show-error --max-time 5 "$url" >/dev/null 2>&1; then
      ready=1
      break
    fi
    systemctl is-active --quiet "$service" || break
    sleep 2
  done
  (( ready == 1 )) || { printf 'Hearth service did not become healthy: %s\n' "$service" >&2; return 1; }
}

hearth_test_slot_begin() {
  local suite="$1" run_id="$2" manifest env_file
  [[ "$EUID" -eq 0 ]] || { printf 'Staging test-slot runner must run as root.\n' >&2; return 1; }
  [[ "$suite" =~ ^(integration|e2e)$ && "$run_id" =~ ^[0-9]{8}t[0-9]{6}_[a-f0-9]{8}$ ]] || { printf 'Invalid Hearth test-slot request.\n' >&2; return 1; }
  systemctl is-active --quiet "$HEARTH_TEST_SLOT_MAIN_SERVICE" || { printf 'Hearth staging app must be active before test execution.\n' >&2; return 1; }
  systemctl is-active --quiet "$HEARTH_TEST_SLOT_EDGE_SERVICE" || { printf 'Hearth staging edge must be active before test execution.\n' >&2; return 1; }
  manifest="$HEARTH_TEST_SLOT_STATE_ROOT/$run_id/$suite.manifest"
  env_file="$HEARTH_TEST_SLOT_STATE_ROOT/$run_id/$suite.env"
  HEARTH_TEST_SLOT_MANIFEST="$manifest"
  HEARTH_TEST_SLOT_LOCK_HELD=1 /opt/hearth-native/source/current/deploy/provision-staging-test-slot.sh --run-id "$run_id" "$suite"
  install -d -o ubuntu -g hearth -m 0750 /run/hearth
  install -o ubuntu -g hearth -m 0640 "$env_file" "$HEARTH_TEST_SLOT_RUNTIME_ENV"
  systemctl stop "$HEARTH_TEST_SLOT_MAIN_SERVICE"
  available_kib="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)"
  [[ "$available_kib" =~ ^[0-9]+$ && "$available_kib" -ge "$HEARTH_TEST_SLOT_MINIMUM_AVAILABLE_KIB" ]] || {
    printf 'Refusing test-slot start: require %s KiB MemAvailable after stopping Hearth app, found %s KiB.\n' \
      "$HEARTH_TEST_SLOT_MINIMUM_AVAILABLE_KIB" "${available_kib:-unknown}" >&2
    return 1
  }
  HEARTH_TEST_SLOT_STARTED_AT="$(date --iso-8601=seconds)"
  systemctl start "$HEARTH_TEST_SLOT_SERVICE"
  hearth_test_slot_wait_http "$HEARTH_TEST_SLOT_SERVICE" "$HEARTH_TEST_SLOT_APP_HEALTH"
}

hearth_test_slot_end() {
  local manifest="$1" status=0 restore_started_at
  [[ -n "$manifest" ]] || return 1
  if systemctl is-active --quiet "$HEARTH_TEST_SLOT_SERVICE"; then
    hearth_test_slot_check_journal "$HEARTH_TEST_SLOT_SERVICE" "$HEARTH_TEST_SLOT_STARTED_AT" || status=1
    systemctl stop "$HEARTH_TEST_SLOT_SERVICE" || status=1
  fi
  rm -f -- "$HEARTH_TEST_SLOT_RUNTIME_ENV"
  if [[ -f "$manifest" ]]; then
    HEARTH_TEST_SLOT_LOCK_HELD=1 /opt/hearth-native/source/current/deploy/teardown-staging-test-slot.sh --manifest "$manifest" || status=1
  fi
  restore_started_at="$(date --iso-8601=seconds)"
  systemctl start "$HEARTH_TEST_SLOT_MAIN_SERVICE" || status=1
  hearth_test_slot_wait_http "$HEARTH_TEST_SLOT_MAIN_SERVICE" "$HEARTH_TEST_SLOT_APP_HEALTH" || status=1
  hearth_test_slot_check_journal "$HEARTH_TEST_SLOT_MAIN_SERVICE" "$restore_started_at" || status=1
  systemctl is-active --quiet "$HEARTH_TEST_SLOT_EDGE_SERVICE" || systemctl start "$HEARTH_TEST_SLOT_EDGE_SERVICE" || status=1
  hearth_test_slot_wait_http "$HEARTH_TEST_SLOT_EDGE_SERVICE" "$HEARTH_TEST_SLOT_EDGE_HEALTH" || status=1
  (( status == 0 )) || { printf 'Hearth test-slot cleanup or staging restore failed.\n' >&2; return 1; }
}
