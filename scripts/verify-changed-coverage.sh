#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SOURCE_ROOT/scripts/lib/java-25.sh"
readonly JAVA_25_HOME="$(resolve_java_25)"
JAVA_HOME="$JAVA_25_HOME" "$SOURCE_ROOT/mvnw" verify -Dsort.skip=true
printf 'Hearth Maven verification and coverage report generation passed.\n'
