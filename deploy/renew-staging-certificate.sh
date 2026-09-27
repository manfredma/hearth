#!/usr/bin/env bash
set -Eeuo pipefail

readonly DOMAIN=staging-hearth.bytedepth.cn
readonly CURRENT=/etc/hearth/staging-tls/current
readonly RELEASE_ROOT=/etc/hearth/staging-tls/releases
readonly NGINX_CONFIG=/etc/nginx/nginx.conf
readonly NGINX_UNIT=nginx.service
readonly CURRENT_HELPER=/data/hearth-native-staging/letsencrypt/hearth-staging-certificate-current.sh

[[ "${RENEWED_DOMAINS:-}" == "$DOMAIN" ]] || { printf 'Unexpected Hearth staging renewal domain set.\n' >&2; exit 1; }
[[ "${RENEWED_LINEAGE:-}" == "/data/hearth-native-staging/letsencrypt/live/$DOMAIN" ]] || { printf 'Unexpected Hearth staging renewal lineage.\n' >&2; exit 1; }
cert="$RENEWED_LINEAGE/fullchain.pem"
key="$RENEWED_LINEAGE/privkey.pem"
openssl x509 -checkend 2592000 -noout -in "$cert" >/dev/null
openssl x509 -checkhost "$DOMAIN" -noout -in "$cert" >/dev/null
sans="$(openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null | sed '1d' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
printf '%s\n' "$sans" | grep -Fx "DNS:$DOMAIN" >/dev/null || { printf 'Hearth staging certificate lacks its exact DNS SAN.\n' >&2; exit 1; }
certificate_key="$(openssl x509 -in "$cert" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
private_key="$(openssl pkey -in "$key" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
[[ -n "$certificate_key" && "$certificate_key" == "$private_key" ]] || { printf 'Hearth staging certificate and private key do not match.\n' >&2; exit 1; }

certificate_sha="$(sha256sum "$cert" | awk '{print $1}')"
release="$RELEASE_ROOT/$certificate_sha"
install -d -o ubuntu -g ubuntu -m 0700 /etc/hearth/staging-tls "$RELEASE_ROOT"
if [[ ! -e "$release" && ! -L "$release" ]]; then
  stage="$RELEASE_ROOT/.staging-$certificate_sha-$$"
  install -d -o ubuntu -g ubuntu -m 0700 "$stage"
  trap 'rm -rf -- "${stage:-}"' EXIT
  install -o ubuntu -g ubuntu -m 0644 "$cert" "$stage/fullchain.pem"
  install -o ubuntu -g ubuntu -m 0600 "$key" "$stage/privkey.pem"
  [[ "$(sha256sum "$stage/fullchain.pem" | awk '{print $1}')" == "$certificate_sha" ]]
  mv "$stage" "$release"
  stage=""
else
  [[ -d "$release" && ! -L "$release" && -f "$release/fullchain.pem" && -f "$release/privkey.pem" ]]
  [[ "$(sha256sum "$release/fullchain.pem" | awk '{print $1}')" == "$certificate_sha" ]]
fi

source "$CURRENT_HELPER"
hearth_staging_promote_tls_current "$CURRENT" "$RELEASE_ROOT" "$release"
nginx_check="$(sudo -n /usr/sbin/nginx -t -c "$NGINX_CONFIG" 2>&1)"
printf '%s\n' "$nginx_check"
if grep -Eiq '(^|[^[:alnum:]_])WARN(ING)?([^[:alnum:]_]|$)' <<< "$nginx_check"; then
  printf 'Shared Nginx emitted WARNING while validating the renewed Hearth certificate.\n' >&2
  exit 1
fi
sudo -n /usr/bin/systemctl reload "$NGINX_UNIT"
printf 'Hearth staging TLS renewed and shared Nginx reloaded for %s.\n' "$DOMAIN"
