#!/usr/bin/env bash

hearth_process_cgroup() {
  awk -F: '$1 == "0" {print $3}' "/proc/$1/cgroup"
}

hearth_assert_production_ports() {
  local snapshot line endpoint port unit expected owners pid actual
  snapshot="$(ss -ltnpH)" || return 1
  while IFS= read -r line; do
    read -r _ _ _ endpoint _ <<< "$line"
    port="${endpoint##*:}"
    case "$port" in
      18112) unit=hearth-production-native-app.service ;;
      18113) unit=hearth-production-native-edge.service ;;
      *) continue ;;
    esac
    [[ "$endpoint" == "127.0.0.1:$port" ]] || return 1
    systemctl is-active --quiet "$unit" || return 1
    expected="$(systemctl show "$unit" --property=ControlGroup --value)" || return 1
    [[ "$expected" == "/system.slice/$unit" ]] || return 1
    owners="$line"
    [[ "$owners" =~ pid=([0-9]+) ]] || return 1
    # Nginx can report both master and worker owners. Every owner must belong
    # to the already-active Hearth unit; a process name alone proves nothing.
    while [[ "$owners" =~ pid=([0-9]+) ]]; do
      pid="${BASH_REMATCH[1]}"
      actual="$(hearth_process_cgroup "$pid")" || return 1
      [[ "$actual" == "$expected" ]] || return 1
      owners="${owners#*pid=$pid}"
    done
  done <<< "$snapshot"
}
