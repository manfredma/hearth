#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ $# -eq 1 && $1 == production ]] || { printf 'Usage: %s production\n' "$0" >&2; exit 2; }
readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly DOMAIN=hearth.bytedepth.cn
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
readonly SOURCE_ACCOUNTS=/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory
readonly ACME_ROUTE=/etc/nginx/conf.d/hearth-production-acme.conf
readonly NGINX_CONFIG=/etc/bytedepth/production-green-public-nginx.conf
readonly NGINX_UNIT=bytedepth-production-green-public-nginx.service
source "$CONFIG_FILE"
readonly ROOT="$HEARTH_NATIVE_PRODUCTION_ROOT"
readonly CERTBOT_ROOT="$ROOT/letsencrypt"
readonly WEBROOT="$ROOT/acme-webroot"
readonly CERT="$CERTBOT_ROOT/live/$DOMAIN/fullchain.pem"
readonly PRIVATE_KEY="$CERTBOT_ROOT/live/$DOMAIN/privkey.pem"
command -v certbot >/dev/null || { printf 'Certbot is required on the production host.\n' >&2; exit 1; }
systemctl is-active --quiet "$NGINX_UNIT" || { printf 'Shared production Nginx is not active.\n' >&2; exit 1; }
account_id=""
for renewal in /etc/letsencrypt/renewal/*.conf; do
  [[ -f "$renewal" && ! -L "$renewal" ]] || continue
  candidate_account="$(awk -F= '$1 ~ /^[[:space:]]*account[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$renewal")"
  if [[ "$candidate_account" =~ ^[a-f0-9]{32}$ && -d "$SOURCE_ACCOUNTS/$candidate_account" ]]; then
    account_id="$candidate_account"
    break
  fi
done
[[ "$account_id" =~ ^[a-f0-9]{32}$ && -d "$SOURCE_ACCOUNTS/$account_id" ]] || { printf 'Existing production ACME account cannot be identified.\n' >&2; exit 1; }
install -d -o ubuntu -g ubuntu -m 0755 "$ROOT" "$WEBROOT"
install -d -o ubuntu -g ubuntu -m 0700 "$CERTBOT_ROOT" \
  "$CERTBOT_ROOT/accounts/acme-v02.api.letsencrypt.org/directory/$account_id" \
  "$CERTBOT_ROOT/renewal-hooks/deploy"
install -d -o ubuntu -g ubuntu -m 0750 "$ROOT/letsencrypt-work" "$ROOT/letsencrypt-logs"
account_target="$CERTBOT_ROOT/accounts/acme-v02.api.letsencrypt.org/directory/$account_id"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ACCOUNTS/$account_id/meta.json" "$account_target/meta.json"
install -o ubuntu -g ubuntu -m 0400 "$SOURCE_ACCOUNTS/$account_id/private_key.json" "$account_target/private_key.json"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ACCOUNTS/$account_id/regr.json" "$account_target/regr.json"
install -o ubuntu -g ubuntu -m 0755 "$SOURCE_ROOT/deploy/renew-production-certificate.sh" \
  "$CERTBOT_ROOT/renewal-hooks/deploy/hearth-production-reload-nginx.sh"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ROOT/deploy/systemd/hearth-production-cert-renew.service.in" \
  /etc/systemd/system/hearth-production-cert-renew.service
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ROOT/deploy/systemd/hearth-production-cert-renew.timer.in" \
  /etc/systemd/system/hearth-production-cert-renew.timer
systemctl daemon-reload

remove_acme_route() {
  if [[ -f "$ACME_ROUTE" && ! -L "$ACME_ROUTE" ]]; then
    rm -f -- "$ACME_ROUTE"
    nginx -t -c "$NGINX_CONFIG"
    systemctl reload "$NGINX_UNIT"
  fi
}
trap remove_acme_route EXIT
if [[ ! -r "$CERT" || ! -r "$PRIVATE_KEY" ]]; then
  acme_tmp="$(mktemp /etc/nginx/conf.d/.hearth-production-acme.XXXXXX)"
  cat > "$acme_tmp" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location ^~ /.well-known/acme-challenge/ {
        root $WEBROOT;
        default_type text/plain;
        try_files \$uri =404;
    }
    location / { return 404; }
}
EOF
  install -o ubuntu -g ubuntu -m 0644 "$acme_tmp" "$ACME_ROUTE"
  rm -f -- "$acme_tmp"
  nginx -t -c "$NGINX_CONFIG"
  systemctl reload "$NGINX_UNIT"
  certbot_log="$(mktemp "$ROOT/letsencrypt-logs/.hearth-certbot.XXXXXX")"
  chown ubuntu:ubuntu "$certbot_log"
  chmod 0600 "$certbot_log"
  set +e
  sudo -n -u ubuntu -- certbot \
    --config-dir "$CERTBOT_ROOT" \
    --work-dir "$ROOT/letsencrypt-work" \
    --logs-dir "$ROOT/letsencrypt-logs" \
    certonly --webroot --webroot-path "$WEBROOT" \
    --domain "$DOMAIN" --cert-name "$DOMAIN" --account "$account_id" \
    --non-interactive --agree-tos --quiet 2>&1 | tee "$certbot_log"
  certbot_status="${PIPESTATUS[0]}"
  set -e
  if rg -n -i '\bwarn(ing)?\b' "$certbot_log"; then
    printf 'Certbot emitted WARNING; refusing production deployment.\n' >&2
    exit 1
  fi
  (( certbot_status == 0 )) || exit "$certbot_status"
  rm -f -- "$certbot_log"
fi
openssl x509 -checkend 2592000 -noout -in "$CERT" >/dev/null || { printf 'Hearth production TLS certificate expires within 30 days.\n' >&2; exit 1; }
openssl x509 -checkhost "$DOMAIN" -noout -in "$CERT" >/dev/null || { printf 'Hearth production TLS hostname does not match.\n' >&2; exit 1; }
certificate_key="$(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
private_key="$(openssl pkey -in "$PRIVATE_KEY" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
[[ -n "$certificate_key" && "$certificate_key" == "$private_key" ]] || { printf 'Hearth production TLS certificate and key do not match.\n' >&2; exit 1; }
chown -R ubuntu:ubuntu "$CERTBOT_ROOT" "$ROOT/letsencrypt-work" "$ROOT/letsencrypt-logs" "$WEBROOT"
systemctl enable --now hearth-production-cert-renew.timer
printf 'Hearth production TLS certificate is valid and auto-renewal is enabled.\n'
