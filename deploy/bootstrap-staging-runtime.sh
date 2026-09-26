#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
readonly SOURCE_ROOT=/opt/hearth-native/source/current
readonly STATE_ROOT=/var/lib/hearth-staging
readonly RUNTIME_ROOT=/opt/hearth-native/e2e-runtime
readonly CHROME=/opt/shared-e2e/chrome-linux64/chrome
readonly LOCK="$STATE_ROOT/deployment-test.lock"
readonly RUNTIME_MANIFEST="$STATE_ROOT/e2e-runtime.manifest"
readonly NPM_LOG="$STATE_ROOT/npm-ci.log"
readonly MINIMUM_AVAILABLE_KIB=524288
[[ -x "$CHROME" ]] || { printf 'Shared Chromium is missing.\n' >&2; exit 1; }
install -d -o ubuntu -g ubuntu -m 0700 "$STATE_ROOT"
touch "$LOCK"
chown ubuntu:ubuntu "$LOCK"
chmod 0600 "$LOCK"
if [[ "${1:-}" != --lock-held ]]; then
  exec flock -x "$LOCK" "$0" --lock-held
fi
[[ $# -eq 1 ]] || { printf 'Usage: %s [--lock-held]\n' "$0" >&2; exit 2; }
[[ -f "$SOURCE_ROOT/package.json" && -f "$SOURCE_ROOT/package-lock.json" ]] || { printf 'Hearth staging Node lock inputs are missing.\n' >&2; exit 1; }
readonly LOCK_SHA="$(sha256sum "$SOURCE_ROOT/package-lock.json" | awk '{print $1}')"
readonly PACKAGE_JSON_SHA="$(sha256sum "$SOURCE_ROOT/package.json" | awk '{print $1}')"
readonly CHROME_VERSION="$("$CHROME" --version)"
readonly NODE_VERSION="$(sudo -n -u ubuntu -- node --version)"
install -d -o ubuntu -g ubuntu -m 0755 "$RUNTIME_ROOT"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ROOT/package.json" "$RUNTIME_ROOT/package.json"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ROOT/package-lock.json" "$RUNTIME_ROOT/package-lock.json"
if [[ -x "$RUNTIME_ROOT/node_modules/.bin/playwright" && -f "$RUNTIME_MANIFEST" ]] \
  && [[ "$(awk -F= '$1 == \"lockfile_sha256\" {print $2}' "$RUNTIME_MANIFEST")" == "$LOCK_SHA" ]] \
  && [[ "$(awk -F= '$1 == \"package_json_sha256\" {print $2}' "$RUNTIME_MANIFEST")" == "$PACKAGE_JSON_SHA" ]] \
  && [[ "$(awk -F= '$1 == \"chromium_version\" {print substr($0,index($0,\"=\")+1); exit}' "$RUNTIME_MANIFEST")" == "$CHROME_VERSION" ]] \
  && [[ "$(awk -F= '$1 == \"node_version\" {print $2}' "$RUNTIME_MANIFEST")" == "$NODE_VERSION" ]]; then
  printf 'Reusing the Hearth staging E2E runtime for unchanged dependency inputs.\n'
else
  available_kib="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)"
  [[ "$available_kib" =~ ^[0-9]+$ && "$available_kib" -ge "$MINIMUM_AVAILABLE_KIB" ]] || {
    printf 'Refusing Hearth npm ci: require at least %s KiB MemAvailable, found %s KiB.\n' \
      "$MINIMUM_AVAILABLE_KIB" "${available_kib:-unknown}" >&2
    exit 1
  }
  : > "$NPM_LOG"
  chown ubuntu:ubuntu "$NPM_LOG"
  chmod 0600 "$NPM_LOG"
  set +e
  sudo -n -u ubuntu -- bash -c 'cd /opt/hearth-native/e2e-runtime && NODE_OPTIONS=--max-old-space-size=384 npm ci --ignore-scripts --no-audit --no-fund --maxsockets=1' 2>&1 | tee "$NPM_LOG"
  npm_status="${PIPESTATUS[0]}"
  set -e
  if rg -n -i '\bWARN(ING)?\b' "$NPM_LOG"; then
    printf 'Hearth staging npm ci emitted WARNING; stopping.\n' >&2
    exit 1
  fi
  (( npm_status == 0 )) || exit "$npm_status"
  manifest_tmp="$(mktemp "$STATE_ROOT/.e2e-runtime.XXXXXX")"
  printf 'lockfile_sha256=%s\npackage_json_sha256=%s\nnode_version=%s\nchromium_version=%s\n' \
    "$LOCK_SHA" "$PACKAGE_JSON_SHA" "$NODE_VERSION" "$CHROME_VERSION" > "$manifest_tmp"
  chown ubuntu:ubuntu "$manifest_tmp"
  chmod 0600 "$manifest_tmp"
  mv -f "$manifest_tmp" "$RUNTIME_MANIFEST"
fi
[[ -x "$RUNTIME_ROOT/node_modules/.bin/playwright" ]] || { printf 'Hearth Playwright runtime is not executable.\n' >&2; exit 1; }
if [[ -L "$SOURCE_ROOT/node_modules" ]]; then
  [[ "$(readlink -f "$SOURCE_ROOT/node_modules")" == "$RUNTIME_ROOT/node_modules" ]] || { printf 'Hearth source node_modules points outside its project runtime.\n' >&2; exit 1; }
elif [[ -e "$SOURCE_ROOT/node_modules" ]]; then
  printf 'Hearth source has an unexpected non-runtime node_modules directory.\n' >&2
  exit 1
else
  sudo -n -u ubuntu -- ln -s "$RUNTIME_ROOT/node_modules" "$SOURCE_ROOT/node_modules"
fi
chown ubuntu:ubuntu "$SOURCE_ROOT/node_modules"
printf 'Hearth staging runtime ready: %s\n' "$CHROME_VERSION"
