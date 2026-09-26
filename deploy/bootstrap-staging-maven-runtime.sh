#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ ${HEARTH_STAGING_DEPLOYMENT_LOCK_HELD:-} == 1 ]] || { printf 'Staging deployment lock is required for Maven bootstrap.\n' >&2; exit 1; }

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly STATE_ROOT=/var/lib/hearth-staging
readonly LOG_ROOT="$STATE_ROOT/maven-bootstrap"
readonly MAVEN_REPOSITORY=/opt/shared-maven/repository
readonly MAVEN_REPOSITORY_LOCK=/opt/shared-maven/repository.lock
readonly MINIMUM_AVAILABLE_KIB=524288
readonly JAVA_BIN="$(readlink -f "$(command -v java 2>/dev/null || true)" 2>/dev/null || true)"
[[ -x "$JAVA_BIN" ]] || { printf 'Java 25 is required for staging Maven bootstrap.\n' >&2; exit 1; }
"$JAVA_BIN" -version 2>&1 | grep -Eq 'version[[:space:]]"25([."]|$)' || {
  printf 'Staging Maven bootstrap resolved a non-Java-25 runtime.\n' >&2
  exit 1
}
[[ -x "$SOURCE_ROOT/mvnw" && -f "$SOURCE_ROOT/.mvn/wrapper/maven-wrapper.properties" ]] || {
  printf 'Hearth Maven Wrapper inputs are missing.\n' >&2
  exit 1
}
grep -Fq 'apache-maven-3.9.11' "$SOURCE_ROOT/.mvn/wrapper/maven-wrapper.properties" || {
  printf 'Hearth Maven Wrapper must pin Maven 3.9.11.\n' >&2
  exit 1
}
[[ -d "$MAVEN_REPOSITORY" && -r "$MAVEN_REPOSITORY" && -w "$MAVEN_REPOSITORY" \
  && -r "$MAVEN_REPOSITORY_LOCK" ]] || {
  printf 'The shared Maven repository or global lock is unavailable.\n' >&2
  exit 1
}
sudo -n -u ubuntu -- test -r "$SOURCE_ROOT/pom.xml" \
  && sudo -n -u ubuntu -- test -w "$SOURCE_ROOT" \
  && sudo -n -u ubuntu -- test -w "$MAVEN_REPOSITORY" || {
  printf 'ubuntu cannot read the Hearth checkout or write the shared Maven repository.\n' >&2
  exit 1
}
available_kib="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)"
[[ "$available_kib" =~ ^[0-9]+$ && "$available_kib" -ge "$MINIMUM_AVAILABLE_KIB" ]] || {
  printf 'Refusing Maven cache warm-up: require %s KiB MemAvailable, found %s KiB.\n' \
    "$MINIMUM_AVAILABLE_KIB" "${available_kib:-unknown}" >&2
  exit 1
}
source "$SOURCE_ROOT/deploy/lib/pipeline-status.sh"
source "$SOURCE_ROOT/deploy/lib/check-warning-log.sh"
commit="$(cat "$SOURCE_ROOT/.hearth-commit")"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { printf 'Hearth source SHA is invalid for Maven bootstrap.\n' >&2; exit 1; }
run_id="$(date -u +%Y%m%dt%H%M%S)_$(openssl rand -hex 4)"
install -d -o ubuntu -g ubuntu -m 0700 "$LOG_ROOT"
log="$LOG_ROOT/$commit-$run_id.log"
install -o ubuntu -g ubuntu -m 0600 /dev/null "$log"
exec 9>>"$MAVEN_REPOSITORY_LOCK"
flock -x 9

run_maven_phase() {
  local phase="$1" unit="hearth-staging-maven-$run_id-$1.service"
  local -a statuses
  set +e
  systemd-run --expand-environment=no --uid=ubuntu --gid=ubuntu \
    --unit="$unit" --collect --quiet --wait --pipe \
    --property=MemoryMax=384M --property=MemorySwapMax=0 \
    /usr/bin/bash -c '
      set -Eeuo pipefail
      source_root="$1"
      java_home="$2"
      maven_repository="$3"
      phase="$4"
      cd "$source_root"
      export JAVA_HOME="$java_home" MAVEN_OPTS=-Xmx192m
      case "$phase" in
        go-offline)
          exec ./mvnw -B -DskipTests -Dsort.skip=true \
            -Pstaging-integration -pl hearth-start -am \
            -Dmaven.repo.local="$maven_repository" dependency:go-offline
          ;;
        *) printf "Unsupported Maven bootstrap phase.\n" >&2; exit 2 ;;
      esac
    ' _ "$SOURCE_ROOT" "${JAVA_BIN%/bin/java}" "$MAVEN_REPOSITORY" "$phase" 2>&1 | tee -a "$log"
  statuses=("${PIPESTATUS[@]}")
  set -e
  [[ ${#statuses[@]} -eq 2 ]] || { printf 'Maven bootstrap output pipeline status is incomplete.\n' >&2; return 1; }
  hearth_require_successful_pipeline "${statuses[@]}" || { printf 'Maven %s bootstrap phase or log capture failed.\n' "$phase" >&2; return 1; }
  hearth_assert_log_has_no_warning "$log" || { printf 'Maven bootstrap emitted WARNING or its log could not be scanned.\n' >&2; return 1; }
}

run_maven_phase go-offline
printf 'Hearth staging shared Maven repository is prepared for %s.\n' "$commit"
