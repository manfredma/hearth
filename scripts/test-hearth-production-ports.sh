#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/production-port-preflight.sh"
listeners=''
active=1
group=/system.slice/hearth-production-native-app.service
ss() { printf '%s\n' "$listeners"; }
systemctl() {
  case "$1" in
    is-active) (( active == 1 )) ;;
    show) printf '/system.slice/%s\n' "$2" ;;
    *) return 2 ;;
  esac
}
hearth_process_cgroup() { printf '%s\n' "$group"; }
hearth_assert_production_ports
listeners='LISTEN 0 128 127.0.0.1:18112 0.0.0.0:* users:(("java",pid=123,fd=8))'
hearth_assert_production_ports
listeners='LISTEN 0 128 127.0.0.1:18113 0.0.0.0:* users:(("nginx",pid=123,fd=8),("nginx",pid=124,fd=8))'
group=/system.slice/hearth-production-native-edge.service
hearth_assert_production_ports
reject() { if hearth_assert_production_ports > /dev/null 2>&1; then printf 'Unsafe listener accepted.\n' >&2; exit 1; fi; }
group=/system.slice/career-production-native-app.service
reject
group=/system.slice/hearth-production-native-edge.service
active=0
reject
active=1
listeners='LISTEN 0 128 0.0.0.0:18113 0.0.0.0:* users:(("nginx",pid=123,fd=8))'
reject
listeners='LISTEN 0 128 127.0.0.1:18113 0.0.0.0:*'
reject
listeners='LISTEN 0 128 127.0.0.1:18113 0.0.0.0:* users:(("nginx",pid=123,fd=8),("foreign",pid=999,fd=8))'
hearth_process_cgroup() { [[ "$1" != 999 ]] && printf '%s\n' "$group" || printf '/other\n'; }
reject
ss() { return 1; }
reject
printf 'Hearth production listener ownership tests passed.\n'
