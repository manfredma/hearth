#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/check-warning-log.sh"
source "$ROOT/deploy/lib/maven-runtime-manifest.sh"

temporary_root="$(mktemp -d /tmp/hearth-maven-cache-test.XXXXXX)"
trap 'rm -rf -- "$temporary_root"' EXIT

create_source() {
  local root="$1" commit="$2"
  mkdir -p "$root/.mvn/wrapper" "$root/hearth-start"
  printf '<project><dependencies>stable</dependencies></project>\n' > "$root/pom.xml"
  printf '<project><artifactId>hearth-start</artifactId></project>\n' > "$root/hearth-start/pom.xml"
  printf 'distributionUrl=https://maven.apache.org/apache-maven-3.9.11-bin.zip\n' \
    > "$root/.mvn/wrapper/maven-wrapper.properties"
  printf '%s\n' '-Xms64m' > "$root/.mvn/jvm.config"
  printf '%s\n' "$commit" > "$root/.hearth-commit"
}

create_source "$temporary_root/previous" 1111111111111111111111111111111111111111
create_source "$temporary_root/candidate" 2222222222222222222222222222222222222222
mkdir -p "$temporary_root/maven-repository"
printf 'BUILD SUCCESS\n' > "$temporary_root/bootstrap.log"
printf '<failsafe-summary><completed>1</completed><errors>0</errors><failures>0</failures></failsafe-summary>\n' \
  > "$temporary_root/failsafe-summary.xml"

previous_fingerprint="$(hearth_maven_runtime_inputs_sha256 "$temporary_root/previous")"
candidate_fingerprint="$(hearth_maven_runtime_inputs_sha256 "$temporary_root/candidate")"
[[ "$previous_fingerprint" == "$candidate_fingerprint" ]]
hearth_maven_runtime_manifest_write "$temporary_root/manifest" "$temporary_root/previous"
hearth_maven_runtime_manifest_matches "$temporary_root/manifest" "$temporary_root/candidate"
! grep -Fq 'commit=' "$temporary_root/manifest"
hearth_maven_previous_cache_reusable \
  "$temporary_root/previous" "$temporary_root/candidate" "$temporary_root/maven-repository" \
  "$temporary_root/bootstrap.log" "$temporary_root/failsafe-summary.xml"

printf 'WARNING: incomplete cache preparation\n' >> "$temporary_root/bootstrap.log"
if hearth_maven_previous_cache_reusable \
  "$temporary_root/previous" "$temporary_root/candidate" "$temporary_root/maven-repository" \
  "$temporary_root/bootstrap.log" "$temporary_root/failsafe-summary.xml" \
  2>"$temporary_root/warning-check.log"; then
  printf 'Maven cache reuse must be rejected when the previous bootstrap log contains WARNING.\n' >&2
  exit 1
fi
printf 'BUILD SUCCESS\n' > "$temporary_root/bootstrap.log"
printf '<failsafe-summary><completed>1</completed><errors>0</errors><failures>1</failures></failsafe-summary>\n' \
  > "$temporary_root/failsafe-summary.xml"
! hearth_maven_previous_cache_reusable \
  "$temporary_root/previous" "$temporary_root/candidate" "$temporary_root/maven-repository" \
  "$temporary_root/bootstrap.log" "$temporary_root/failsafe-summary.xml"

printf '<project><dependencies>changed</dependencies></project>\n' > "$temporary_root/candidate/pom.xml"
! hearth_maven_runtime_manifest_matches "$temporary_root/manifest" "$temporary_root/candidate"
! hearth_maven_previous_cache_reusable \
  "$temporary_root/previous" "$temporary_root/candidate" "$temporary_root/maven-repository" \
  "$temporary_root/bootstrap.log" "$temporary_root/failsafe-summary.xml"
printf 'Hearth Maven runtime cache contract passed.\n'
