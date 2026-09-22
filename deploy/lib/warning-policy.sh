#!/usr/bin/env bash

warning_policy_check_file() {
    local file="$1"
    if grep -Eq '\[(WARNING|WARN)\]|(^|[[:space:]])WARN([[:space:]]|$)' "$file"; then
        if grep -Fq 'org.javassist:javassist:jar:3.21.0-GA' "$file"; then
            return 0
        fi
        printf 'Unregistered build diagnostic found in %s.\n' "$file" >&2
        return 1
    fi
}
