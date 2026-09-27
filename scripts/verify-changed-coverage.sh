#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SOURCE_ROOT/scripts/lib/java-25.sh"
source "$SOURCE_ROOT/scripts/lib/run-checked.sh"
readonly JAVA_25_HOME="$(resolve_java_25)"
cd "$SOURCE_ROOT"
# Activate the existing reactor merge/aggregate profile. Check XML after all
# modules finish, so tests in hearth-start count toward adapter coverage too.
run_checked env JAVA_HOME="$JAVA_25_HOME" "$SOURCE_ROOT/mvnw" clean verify -Dsort.skip=true '-Dcoverage.includes=manfred/hearth/*'
run_checked env JAVA_HOME="$JAVA_25_HOME" "$SOURCE_ROOT/mvnw" jacoco:report "-Djacoco.dataFile=$SOURCE_ROOT/hearth-start/target/jacoco-merged.exec"
python3 "$SOURCE_ROOT/scripts/check_changed_coverage.py"
