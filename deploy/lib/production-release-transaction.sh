#!/usr/bin/env bash

HEARTH_PRODUCTION_TXN_ACTIVE=0
HEARTH_PRODUCTION_CONFIG_ACTIVE=0

hearth_production_config_begin() {
  HEARTH_PRODUCTION_CONFIG_BACKUP="$1"
  shift
  mkdir -m 0700 "$HEARTH_PRODUCTION_CONFIG_BACKUP" || return 1
  local file index=0 unit
  HEARTH_PRODUCTION_CONFIG_FILES=("$@")
  for file in "$@"; do
    if [[ -e "$file" || -L "$file" ]]; then
      [[ -f "$file" || -L "$file" ]] || return 1
      cp -pP "$file" "$HEARTH_PRODUCTION_CONFIG_BACKUP/$index" || return 1
    fi
    index=$((index + 1))
  done
  HEARTH_PRODUCTION_CONFIG_UNITS=(hearth-production-native-app.service hearth-production-native-edge.service
    hearth-production-native-edge-logrotate.timer hearth-production-cert-renew.timer)
  HEARTH_PRODUCTION_CONFIG_ACTIVE_UNITS=()
  for unit in "${HEARTH_PRODUCTION_CONFIG_UNITS[@]}"; do
    if systemctl is-active --quiet "$unit"; then HEARTH_PRODUCTION_CONFIG_ACTIVE_UNITS+=("$unit"); fi
  done
  # No installation starts until every preimage and unit state is captured.
  HEARTH_PRODUCTION_CONFIG_ACTIVE=1
}

hearth_production_config_rollback() {
  (( HEARTH_PRODUCTION_CONFIG_ACTIVE == 1 )) || return 0
  local file unit index=0 status=0
  for unit in "${HEARTH_PRODUCTION_CONFIG_UNITS[@]}"; do
    if systemctl is-active --quiet "$unit"; then systemctl stop "$unit" || status=1; fi
  done
  for file in "${HEARTH_PRODUCTION_CONFIG_FILES[@]}"; do
    if [[ -e "$HEARTH_PRODUCTION_CONFIG_BACKUP/$index" || -L "$HEARTH_PRODUCTION_CONFIG_BACKUP/$index" ]]; then
      rm -f -- "$file" && cp -pP "$HEARTH_PRODUCTION_CONFIG_BACKUP/$index" "$file" || status=1
    else
      rm -f -- "$file" || status=1
    fi
    index=$((index + 1))
  done
  systemctl daemon-reload || status=1
  return "$status"
}

hearth_production_config_restore_units() {
  (( HEARTH_PRODUCTION_CONFIG_ACTIVE == 1 )) || return 0
  local unit status=0
  for unit in "${HEARTH_PRODUCTION_CONFIG_ACTIVE_UNITS[@]+${HEARTH_PRODUCTION_CONFIG_ACTIVE_UNITS[@]}}"; do
    systemctl start "$unit" || status=1
  done
  return "$status"
}

hearth_production_link() {
  local staged_link="${2}.new.$$.${RANDOM}"
  [[ ! -e "$staged_link" && ! -L "$staged_link" ]] || return 1
  ln -s "$1" "$staged_link"
  if ! mv -Tf "$staged_link" "$2"; then
    rm -f -- "$staged_link"
    return 1
  fi
}

hearth_production_release_begin() {
  [[ $# -eq 6 ]] || return 2
  local current_link="$1" source_link="$2" release_target="$3" source_target="$4"
  local app_service="$5" edge_service="$6"
  [[ -d "$release_target" && -d "$source_target" ]] || { printf 'Production release targets are missing.\n' >&2; return 1; }
  [[ "$app_service" =~ ^[A-Za-z0-9_.@:-]+$ && "$edge_service" =~ ^[A-Za-z0-9_.@:-]+$ ]] || return 2
  for link in "$current_link" "$source_link"; do
    [[ ! -e "$link" || -L "$link" ]] || { printf 'Refusing to replace non-symlink production pointer: %s\n' "$link" >&2; return 1; }
  done

  HEARTH_PRODUCTION_TXN_CURRENT_LINK="$current_link"
  HEARTH_PRODUCTION_TXN_SOURCE_LINK="$source_link"
  HEARTH_PRODUCTION_TXN_APP_SERVICE="$app_service"
  HEARTH_PRODUCTION_TXN_EDGE_SERVICE="$edge_service"
  HEARTH_PRODUCTION_TXN_PREVIOUS_CURRENT=""
  HEARTH_PRODUCTION_TXN_PREVIOUS_SOURCE=""
  [[ ! -L "$current_link" ]] || HEARTH_PRODUCTION_TXN_PREVIOUS_CURRENT="$(readlink -f "$current_link")"
  [[ ! -L "$source_link" ]] || HEARTH_PRODUCTION_TXN_PREVIOUS_SOURCE="$(readlink -f "$source_link")"
  [[ -z "$HEARTH_PRODUCTION_TXN_PREVIOUS_CURRENT" || -d "$HEARTH_PRODUCTION_TXN_PREVIOUS_CURRENT" ]] || return 1
  [[ -z "$HEARTH_PRODUCTION_TXN_PREVIOUS_SOURCE" || -d "$HEARTH_PRODUCTION_TXN_PREVIOUS_SOURCE" ]] || return 1
  if systemctl is-active --quiet "$app_service"; then HEARTH_PRODUCTION_TXN_APP_WAS_ACTIVE=1; else HEARTH_PRODUCTION_TXN_APP_WAS_ACTIVE=0; fi
  if systemctl is-active --quiet "$edge_service"; then HEARTH_PRODUCTION_TXN_EDGE_WAS_ACTIVE=1; else HEARTH_PRODUCTION_TXN_EDGE_WAS_ACTIVE=0; fi

  HEARTH_PRODUCTION_TXN_ACTIVE=1
  hearth_production_link "$source_target" "$source_link" || return 1
  hearth_production_link "$release_target" "$current_link" || return 1
  systemctl restart "$app_service" || return 1
  systemctl restart "$edge_service" || return 1
}

hearth_production_release_commit() {
  HEARTH_PRODUCTION_TXN_ACTIVE=0
}

hearth_production_release_rollback() {
  (( HEARTH_PRODUCTION_TXN_ACTIVE == 1 )) || return 0
  local status=0
  if [[ -n "$HEARTH_PRODUCTION_TXN_PREVIOUS_SOURCE" ]]; then
    hearth_production_link "$HEARTH_PRODUCTION_TXN_PREVIOUS_SOURCE" "$HEARTH_PRODUCTION_TXN_SOURCE_LINK" || status=1
  else
    rm -f "$HEARTH_PRODUCTION_TXN_SOURCE_LINK" || status=1
  fi
  if [[ -n "$HEARTH_PRODUCTION_TXN_PREVIOUS_CURRENT" ]]; then
    hearth_production_link "$HEARTH_PRODUCTION_TXN_PREVIOUS_CURRENT" "$HEARTH_PRODUCTION_TXN_CURRENT_LINK" || status=1
  else
    rm -f "$HEARTH_PRODUCTION_TXN_CURRENT_LINK" || status=1
  fi

  if (( HEARTH_PRODUCTION_TXN_APP_WAS_ACTIVE == 1 )); then
    systemctl restart "$HEARTH_PRODUCTION_TXN_APP_SERVICE" || status=1
  else
    systemctl stop "$HEARTH_PRODUCTION_TXN_APP_SERVICE" || status=1
  fi
  if (( HEARTH_PRODUCTION_TXN_EDGE_WAS_ACTIVE == 1 )); then
    systemctl restart "$HEARTH_PRODUCTION_TXN_EDGE_SERVICE" || status=1
  else
    systemctl stop "$HEARTH_PRODUCTION_TXN_EDGE_SERVICE" || status=1
  fi
  HEARTH_PRODUCTION_TXN_ACTIVE=0
  (( status == 0 )) || printf 'Hearth production rollback was incomplete; inspect symlinks and systemd units.\n' >&2
  return "$status"
}
