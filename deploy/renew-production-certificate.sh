#!/usr/bin/env bash
set -Eeuo pipefail

hearth_validate_production_certificate() {
  local lineage="$1" cert key sans certificate_key private_key
  [[ "$lineage" == /data/hearth-native-production/letsencrypt/live/hearth.bytedepth.cn ]] || return 1
  cert="$lineage/fullchain.pem"
  key="$lineage/privkey.pem"
  openssl x509 -checkend 2592000 -noout -in "$cert" >/dev/null || return 1
  sans="$(openssl x509 -in "$cert" -noout -ext subjectAltName | sed '1d' | tr -d '[:space:]')" || return 1
  [[ "$sans" == DNS:hearth.bytedepth.cn ]] || return 1
  certificate_key="$(openssl x509 -in "$cert" -pubkey -noout | openssl pkey -pubin -outform DER | shasum -a 256)" || return 1
  private_key="$(openssl pkey -in "$key" -pubout -outform DER | shasum -a 256)" || return 1
  [[ -n "$certificate_key" && "$certificate_key" == "$private_key" ]]
}

hearth_production_nginx_reload() {
  local output
  output="$(sudo -n /usr/sbin/nginx -t -c /etc/bytedepth/production-public-nginx.conf 2>&1)" || return 1
  printf '%s\n' "$output"
  if [[ "$output" =~ (^|[^[:alnum:]_])[Ww][Aa][Rr][Nn]([Ii][Nn][Gg])?([^[:alnum:]_]|$) ]]; then
    printf 'Production Nginx emitted a blocking diagnostic.\n' >&2
    return 1
  fi
  sudo -n /usr/bin/systemctl reload bytedepth-production-public-nginx.service
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  [[ "${RENEWED_DOMAINS:-}" == hearth.bytedepth.cn ]] || { printf 'Unexpected production renewal domains.\n' >&2; exit 1; }
  hearth_validate_production_certificate "${RENEWED_LINEAGE:-}" || { printf 'Invalid production certificate lineage, SAN, validity or key.\n' >&2; exit 1; }
  hearth_production_nginx_reload
fi
