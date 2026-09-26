#!/usr/bin/env bash

hearth_staging_create_tls_link() {
  ln -s "$1" "$2"
}

hearth_staging_replace_tls_link() {
  mv -Tf "$1" "$2"
}

hearth_staging_promote_tls_current() {
  [[ $# -eq 3 ]] || return 2
  local current="$1" release_root="$2" release="$3"
  local old_target="" legacy="" staged_link=""
  [[ -d "$release" && -f "$release/fullchain.pem" && ! -L "$release/fullchain.pem" \
    && -f "$release/privkey.pem" && ! -L "$release/privkey.pem" ]] || {
    printf 'Refusing to promote an incomplete Hearth TLS release.\n' >&2
    return 1
  }
  [[ "$release" == "$release_root/"* && "$release" != "$release_root/" ]] || return 2
  [[ ! -e "$current" || -L "$current" || -d "$current" ]] || {
    printf 'Hearth TLS current path is neither a directory nor a symlink.\n' >&2
    return 1
  }
  if [[ -L "$current" ]]; then
    old_target="$(readlink -f "$current")"
    [[ "$old_target" == "$release_root/"* ]] || {
      printf 'Refusing to replace an unrelated Hearth TLS path.\n' >&2
      return 1
    }
  elif [[ -d "$current" ]]; then
    local old_fingerprint
    if [[ -f "$current/fullchain.pem" && ! -L "$current/fullchain.pem" ]]; then
      old_fingerprint="$(sha256sum "$current/fullchain.pem" | awk '{print $1}')"
    else
      old_fingerprint="incomplete-$(date +%s)-$$"
    fi
    legacy="$release_root/legacy-current-$old_fingerprint"
    [[ ! -e "$legacy" && ! -L "$legacy" ]] || {
      printf 'Legacy Hearth TLS bundle destination already exists; preserving current state.\n' >&2
      return 1
    }
    mv "$current" "$legacy"
  fi

  staged_link="$(dirname "$current")/.current.$(basename "$release").$$"
  if ! hearth_staging_create_tls_link "$release" "$staged_link"; then
    [[ -z "$legacy" ]] || mv "$legacy" "$current"
    return 1
  fi
  if ! hearth_staging_replace_tls_link "$staged_link" "$current"; then
    rm -f -- "$staged_link"
    [[ -z "$legacy" ]] || mv "$legacy" "$current"
    return 1
  fi
  [[ "$(readlink -f "$current")" == "$release" ]] || {
    printf 'Hearth TLS current pointer does not resolve to the validated release.\n' >&2
    return 1
  }
}
