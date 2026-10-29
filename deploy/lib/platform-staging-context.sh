#!/usr/bin/env bash

hearth_platform_test_context() {
  [[ $# -eq 2 && "$1" == --commit-sha && "$2" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'A complete platform candidate SHA is required.\n' >&2; return 1;
  }
  local expected="$2" root="${RELEASE_PLATFORM_NATIVE_ROOT:-}" manifest history file
  [[ -n "$root" && "${RELEASE_PLATFORM_TEST_LOCK_HELD:-}" == 1 \
    && "${RELEASE_PLATFORM_TEST_ARTIFACT_DIGEST:-}" =~ ^sha256:[0-9a-f]{64}$ \
    && "${RELEASE_PLATFORM_TASK_NONCE:-}" =~ ^[A-Za-z0-9_-]+$ ]] || {
    printf 'Signed platform test context and held deployment lock are required.\n' >&2; return 1;
  }
  [[ "${RELEASE_PLATFORM_TEST_SOURCE_ROOT:-}" == "$root/releases/$expected/source" ]] || {
    printf 'Platform test source does not match the immutable candidate.\n' >&2; return 1;
  }
  manifest="${RELEASE_PLATFORM_TEST_RELEASE_MANIFEST:-}"
  history="${RELEASE_PLATFORM_TEST_DEPLOY_HISTORY:-}"
  [[ "$manifest" == "$root/releases/$expected/manifest" ]] || return 1
  file="$RELEASE_PLATFORM_TEST_SOURCE_ROOT/.release-platform-source-commit"
  [[ -f "$file" && ! -L "$file" && "$(cat "$file")" == "$expected" ]] || return 1
  for file in "$manifest" "$history"; do
    [[ -f "$file" && ! -L "$file" ]] || return 1
    grep -Fxq "commit=$expected" "$file" || return 1
    grep -Fxq "artifact_digest=$RELEASE_PLATFORM_TEST_ARTIFACT_DIGEST" "$file" || return 1
  done
}
