#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Stub only external tools; run the installed renewal entry point's checks.
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
export CALLS="$tmp/calls"
export SAN='DNS:hearth.bytedepth.cn' CERT_OK=1 KEY_MATCH=1 NGINX_OUTPUT=clean
openssl() {
  case "$*" in
    *-checkend*) [[ "$CERT_OK" == 1 ]] ;;
    *subjectAltName*) printf 'X509v3 Subject Alternative Name:\n %s\n' "$SAN" ;;
    *x509*-pubkey*) printf certificate ;;
    *pkey*-pubin*) command cat ;;
    *pkey*-pubout*) [[ "$KEY_MATCH" == 1 ]] && printf certificate || printf different ;;
    *) return 2 ;;
  esac
}
sudo() {
  printf '%s\n' "$*" >> "$CALLS"
  case "$*" in *nginx*) printf '%s\n' "$NGINX_OUTPUT" ;; esac
}
export -f openssl sudo
run() { RENEWED_DOMAINS="${1-hearth.bytedepth.cn}" RENEWED_LINEAGE="${2-/data/hearth-native-production/letsencrypt/live/hearth.bytedepth.cn}" bash "$ROOT/deploy/renew-production-certificate.sh" > "$tmp/output" 2>&1; }
reject() {
  : > "$CALLS"
  if run "$@"; then printf 'Invalid renewal accepted.\n' >&2; exit 1; fi
  if grep -F 'systemctl reload' "$CALLS" >/dev/null; then printf 'Invalid certificate reloaded.\n' >&2; exit 1; fi
}
reject other.example
reject hearth.bytedepth.cn /foreign/lineage
SAN='DNS:hearth.bytedepth.cn, DNS:other.example'; reject
SAN='DNS:*.hearth.bytedepth.cn'; reject
SAN='DNS:hearth.bytedepth.cn'; CERT_OK=0; reject
CERT_OK=1; KEY_MATCH=0; reject
KEY_MATCH=1; NGINX_OUTPUT='nginx: [warn] conflicting server name'; reject
NGINX_OUTPUT=clean; run
grep -F 'systemctl reload bytedepth-production-public-nginx.service' "$CALLS" >/dev/null
printf 'Hearth production certificate validation tests passed.\n'
