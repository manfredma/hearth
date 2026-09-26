#!/usr/bin/env bash

hearth_maven_runtime_inputs_sha256() {
  local source_root="$1"
  local -a checksum_command
  if command -v sha256sum >/dev/null 2>&1; then
    checksum_command=(sha256sum)
  else
    checksum_command=(shasum -a 256)
  fi
  (
    cd "$source_root"
    find . -type d -name target -prune -o \
      -type f \( -name pom.xml -o -path './.mvn/*' \) -print0 \
      | sort -z \
      | xargs -0 "${checksum_command[@]}"
  ) | "${checksum_command[@]}" | awk '{print $1}'
}

hearth_maven_runtime_manifest_matches() {
  local manifest="$1" source_root="$2" recorded current
  [[ -f "$manifest" && ! -L "$manifest" ]] || return 1
  recorded="$(awk -F= '$1 == "maven_inputs_sha256" {print $2; exit}' "$manifest")"
  [[ "$recorded" =~ ^[0-9a-f]{64}$ ]] || return 1
  current="$(hearth_maven_runtime_inputs_sha256 "$source_root")"
  [[ "$recorded" == "$current" ]]
}

hearth_maven_runtime_manifest_write() {
  local manifest="$1" source_root="$2" directory temporary fingerprint
  [[ ! -L "$manifest" ]] || { printf 'Refusing to replace symlink Maven runtime manifest.\n' >&2; return 1; }
  directory="$(dirname "$manifest")"
  install -d -m 0700 "$directory"
  if [[ "$EUID" -eq 0 ]] && getent passwd ubuntu >/dev/null 2>&1 && getent group ubuntu >/dev/null 2>&1; then
    chown ubuntu:ubuntu "$directory"
  fi
  temporary="$(mktemp "$directory/.maven-inputs.XXXXXX")"
  fingerprint="$(hearth_maven_runtime_inputs_sha256 "$source_root")"
  printf 'maven_inputs_sha256=%s\n' "$fingerprint" > "$temporary"
  if [[ "$EUID" -eq 0 ]] && getent passwd ubuntu >/dev/null 2>&1 && getent group ubuntu >/dev/null 2>&1; then
    chown ubuntu:ubuntu "$temporary"
  fi
  chmod 0600 "$temporary"
  mv -f -- "$temporary" "$manifest"
}

hearth_maven_previous_cache_reusable() {
  local previous_source="$1" current_source="$2" repository="$3" bootstrap_log="$4" summary="$5"
  local previous_commit previous_inputs current_inputs completed failures errors
  [[ -d "$previous_source" && ! -L "$previous_source" \
    && -f "$previous_source/.hearth-commit" && ! -L "$previous_source/.hearth-commit" \
    && -d "$repository" && -r "$repository" \
    && -f "$bootstrap_log" && ! -L "$bootstrap_log" \
    && -f "$summary" && ! -L "$summary" ]] || return 1

  previous_commit="$(cat "$previous_source/.hearth-commit")"
  [[ "$previous_commit" =~ ^[0-9a-f]{40}$ ]] || return 1
  previous_inputs="$(hearth_maven_runtime_inputs_sha256 "$previous_source")"
  current_inputs="$(hearth_maven_runtime_inputs_sha256 "$current_source")"
  [[ "$previous_inputs" == "$current_inputs" ]] || return 1
  grep -Fq 'BUILD SUCCESS' "$bootstrap_log" || return 1
  hearth_assert_log_has_no_warning "$bootstrap_log" || return 1

  completed="$(sed -n 's/.*<completed>\([0-9][0-9]*\)<\/completed>.*/\1/p' "$summary")"
  failures="$(sed -n 's/.*<failures>\([0-9][0-9]*\)<\/failures>.*/\1/p' "$summary")"
  errors="$(sed -n 's/.*<errors>\([0-9][0-9]*\)<\/errors>.*/\1/p' "$summary")"
  [[ "$completed" =~ ^[1-9][0-9]*$ && "$failures" == 0 && "$errors" == 0 ]]
}
