#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ $# -eq 1 && $1 == staging ]] || { printf 'Usage: %s staging\n' "$0" >&2; exit 2; }

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly DOMAIN=staging-hearth.bytedepth.cn
readonly CONFIG_FILE=/etc/hearth/hearth-native.conf
readonly SOURCE_ACCOUNTS=/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory
readonly NGINX_UNIT=nginx.service
source "$CONFIG_FILE"
readonly ROOT="$HEARTH_NATIVE_STAGING_ROOT"
readonly CERTBOT_ROOT="$ROOT/letsencrypt"
readonly WEBROOT="$ROOT/acme-webroot"
readonly CERT="$CERTBOT_ROOT/live/$DOMAIN/fullchain.pem"
readonly PRIVATE_KEY="$CERTBOT_ROOT/live/$DOMAIN/privkey.pem"
command -v certbot >/dev/null || { printf 'Certbot is required on the staging host.\n' >&2; exit 1; }
systemctl is-active --quiet "$NGINX_UNIT" || { printf 'Shared staging Nginx is not active.\n' >&2; exit 1; }
[[ -r /etc/hearth/staging-tls/current/fullchain.pem && -r /etc/hearth/staging-tls/current/privkey.pem ]] || { printf 'Existing Hearth staging TLS bundle is unavailable; refusing to alter the active route.\n' >&2; exit 1; }

account_id=""
for renewal in /etc/letsencrypt/renewal/*.conf; do
  [[ -f "$renewal" && ! -L "$renewal" ]] || continue
  candidate_account="$(awk -F= '$1 ~ /^[[:space:]]*account[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$renewal")"
  if [[ "$candidate_account" =~ ^[a-f0-9]{32}$ && -d "$SOURCE_ACCOUNTS/$candidate_account" ]]; then account_id="$candidate_account"; break; fi
done
[[ "$account_id" =~ ^[a-f0-9]{32}$ && -d "$SOURCE_ACCOUNTS/$account_id" ]] || { printf 'Existing staging ACME account cannot be identified.\n' >&2; exit 1; }

install -d -o ubuntu -g ubuntu -m 0755 "$ROOT" "$WEBROOT"
install -d -o ubuntu -g ubuntu -m 0700 "$CERTBOT_ROOT" \
  "$CERTBOT_ROOT/accounts/acme-v02.api.letsencrypt.org/directory/$account_id" \
  "$CERTBOT_ROOT/renewal-hooks/deploy"
install -d -o ubuntu -g ubuntu -m 0750 "$ROOT/letsencrypt-work" "$ROOT/letsencrypt-logs"
account_target="$CERTBOT_ROOT/accounts/acme-v02.api.letsencrypt.org/directory/$account_id"
for account_file in meta.json private_key.json regr.json; do
  [[ -f "$SOURCE_ACCOUNTS/$account_id/$account_file" && ! -L "$SOURCE_ACCOUNTS/$account_id/$account_file" ]] || { printf 'Staging ACME account file is missing: %s\n' "$account_file" >&2; exit 1; }
done
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ACCOUNTS/$account_id/meta.json" "$account_target/meta.json"
install -o ubuntu -g ubuntu -m 0400 "$SOURCE_ACCOUNTS/$account_id/private_key.json" "$account_target/private_key.json"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ACCOUNTS/$account_id/regr.json" "$account_target/regr.json"
install -o ubuntu -g ubuntu -m 0755 "$SOURCE_ROOT/deploy/renew-staging-certificate.sh" \
  "$CERTBOT_ROOT/renewal-hooks/deploy/hearth-staging-reload-nginx.sh"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ROOT/deploy/lib/staging-certificate-current.sh" \
  "$CERTBOT_ROOT/hearth-staging-certificate-current.sh"
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ROOT/deploy/systemd/hearth-staging-cert-renew.service.in" \
  /etc/systemd/system/hearth-staging-cert-renew.service
install -o ubuntu -g ubuntu -m 0644 "$SOURCE_ROOT/deploy/systemd/hearth-staging-cert-renew.timer.in" \
  /etc/systemd/system/hearth-staging-cert-renew.timer
systemctl daemon-reload

renewal_conf="$CERTBOT_ROOT/renewal/$DOMAIN.conf"
live_root="$CERTBOT_ROOT/live/$DOMAIN"
archive_root="$CERTBOT_ROOT/archive/$DOMAIN"
adoption_marker="$CERTBOT_ROOT/.hearth-lineage-adopted"
if [[ ! -e "$renewal_conf" && ! -L "$renewal_conf" ]]; then
  cert_source=/etc/hearth/staging-tls/current/fullchain.pem
  key_source=/etc/hearth/staging-tls/current/privkey.pem
  [[ -r "$cert_source" && -r "$key_source" ]] || { printf 'Existing Hearth staging certificate is unavailable; refusing to request a duplicate certificate.\n' >&2; exit 1; }
  [[ ! -e "$live_root" && ! -L "$live_root" && ! -e "$archive_root" && ! -L "$archive_root" ]] || {
    printf 'Partial Hearth staging Certbot lineage exists; preserving it for investigation.\n' >&2
    exit 1
  }
  openssl x509 -checkend 2592000 -noout -in "$cert_source" >/dev/null
  openssl x509 -checkhost "$DOMAIN" -noout -in "$cert_source" >/dev/null
  sans="$(openssl x509 -in "$cert_source" -noout -ext subjectAltName 2>/dev/null | sed '1d' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  printf '%s\n' "$sans" | grep -Fx "DNS:$DOMAIN" >/dev/null || { printf 'Existing Hearth staging certificate lacks its exact DNS SAN.\n' >&2; exit 1; }
  current_cert_key="$(openssl x509 -in "$cert_source" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
  current_private_key="$(openssl pkey -in "$key_source" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
  [[ -n "$current_cert_key" && "$current_cert_key" == "$current_private_key" ]] || { printf 'Existing Hearth staging certificate and key do not match.\n' >&2; exit 1; }

  install -d -o ubuntu -g ubuntu -m 0700 "$CERTBOT_ROOT/archive" "$CERTBOT_ROOT/renewal" "$archive_root" "$live_root"
  cert_tmp="$archive_root/.cert1.pem.$$"
  chain_tmp="$archive_root/.chain1.pem.$$"
  fullchain_tmp="$archive_root/.fullchain1.pem.$$"
  key_tmp="$archive_root/.privkey1.pem.$$"
  renewal_tmp="$CERTBOT_ROOT/renewal/.$DOMAIN.conf.$$"
  trap 'rm -f -- "${cert_tmp:-}" "${chain_tmp:-}" "${fullchain_tmp:-}" "${key_tmp:-}" "${renewal_tmp:-}"' EXIT
  awk 'BEGIN { n=0 } /-----BEGIN CERTIFICATE-----/ { n++ } n == 1 { print }' "$cert_source" > "$cert_tmp"
  awk 'BEGIN { n=0 } /-----BEGIN CERTIFICATE-----/ { n++ } n >= 2 { print }' "$cert_source" > "$chain_tmp"
  [[ -s "$cert_tmp" && -s "$chain_tmp" ]] || { printf 'Existing Hearth staging fullchain is incomplete; refusing lineage adoption.\n' >&2; exit 1; }
  cp "$cert_source" "$fullchain_tmp"
  cp "$key_source" "$key_tmp"
  chown ubuntu:ubuntu "$cert_tmp" "$chain_tmp" "$fullchain_tmp" "$key_tmp"
  chmod 0644 "$cert_tmp" "$chain_tmp" "$fullchain_tmp"
  chmod 0600 "$key_tmp"
  version="$(certbot --version | awk '{print $2}')"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Unable to determine Certbot version for the Hearth lineage.\n' >&2; exit 1; }
  sudo -n -u ubuntu -- tee "$renewal_tmp" >/dev/null <<EOF
# renew_before_expiry = 30 days
version = $version
archive_dir = $archive_root
cert = $live_root/cert.pem
privkey = $live_root/privkey.pem
chain = $live_root/chain.pem
fullchain = $live_root/fullchain.pem

[renewalparams]
account = $account_id
authenticator = webroot
server = https://acme-v02.api.letsencrypt.org/directory
key_type = rsa
webroot_path = $WEBROOT,
[[webroot_map]]
$DOMAIN = $WEBROOT
EOF
  mv "$cert_tmp" "$archive_root/cert1.pem"
  mv "$chain_tmp" "$archive_root/chain1.pem"
  mv "$fullchain_tmp" "$archive_root/fullchain1.pem"
  mv "$key_tmp" "$archive_root/privkey1.pem"
  sudo -n -u ubuntu -- ln -s "../../archive/$DOMAIN/cert1.pem" "$live_root/cert.pem"
  sudo -n -u ubuntu -- ln -s "../../archive/$DOMAIN/privkey1.pem" "$live_root/privkey.pem"
  sudo -n -u ubuntu -- ln -s "../../archive/$DOMAIN/chain1.pem" "$live_root/chain.pem"
  sudo -n -u ubuntu -- ln -s "../../archive/$DOMAIN/fullchain1.pem" "$live_root/fullchain.pem"
  mv "$renewal_tmp" "$renewal_conf"
  chown ubuntu:ubuntu "$renewal_conf"

elif [[ ! -f "$renewal_conf" || -L "$renewal_conf" || ! -f "$CERT" || ! -f "$PRIVATE_KEY" ]]; then
  printf 'Hearth staging Certbot lineage is incomplete; preserving state and refusing renewal setup.\n' >&2
  exit 1
fi

if [[ ! -f "$adoption_marker" || -L "$adoption_marker" ]]; then
  certbot_log="$(mktemp "$ROOT/letsencrypt-logs/.hearth-certbot-dry-run.XXXXXX")"
  chown ubuntu:ubuntu "$certbot_log"; chmod 0600 "$certbot_log"
  set +e
  sudo -n -u ubuntu -- certbot --config-dir "$CERTBOT_ROOT" --work-dir "$ROOT/letsencrypt-work" \
    --logs-dir "$ROOT/letsencrypt-logs" renew --cert-name "$DOMAIN" --dry-run 2>&1 | tee "$certbot_log"
  certbot_statuses=("${PIPESTATUS[@]}")
  set -e
  [[ ${#certbot_statuses[@]} -eq 2 && ${certbot_statuses[0]} -eq 0 && ${certbot_statuses[1]} -eq 0 ]] || { printf 'Hearth staging Certbot dry-run or log capture failed.\n' >&2; exit 1; }
  if grep -n -E -i '(^|[^[:alnum:]_])WARN(ING)?([^[:alnum:]_]|$)' "$certbot_log"; then
    printf 'Certbot dry-run emitted WARNING; refusing staging deployment.\n' >&2
    exit 1
  fi
  rm -f -- "$certbot_log"
  sudo -n -u ubuntu -- touch "$adoption_marker"
  chown ubuntu:ubuntu "$adoption_marker"
  chmod 0600 "$adoption_marker"
fi
certificate_inventory="$(sudo -n -u ubuntu -- certbot --config-dir "$CERTBOT_ROOT" --work-dir "$ROOT/letsencrypt-work" \
  --logs-dir "$ROOT/letsencrypt-logs" certificates)"
grep -Fq "Certificate Name: $DOMAIN" <<< "$certificate_inventory" || { printf 'Hearth staging certificate is not registered in its Certbot inventory.\n' >&2; exit 1; }

openssl x509 -checkend 2592000 -noout -in "$CERT" >/dev/null || { printf 'Hearth staging certificate expires within 30 days.\n' >&2; exit 1; }
openssl x509 -checkhost "$DOMAIN" -noout -in "$CERT" >/dev/null || { printf 'Hearth staging certificate hostname does not match.\n' >&2; exit 1; }
certificate_key="$(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
private_key="$(openssl pkey -in "$PRIVATE_KEY" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
[[ -n "$certificate_key" && "$certificate_key" == "$private_key" ]] || { printf 'Hearth staging certificate and key do not match.\n' >&2; exit 1; }
chown -R ubuntu:ubuntu "$CERTBOT_ROOT" "$ROOT/letsencrypt-work" "$ROOT/letsencrypt-logs" "$WEBROOT"
systemctl enable --now hearth-staging-cert-renew.timer
timer_link=/etc/systemd/system/timers.target.wants/hearth-staging-cert-renew.timer
[[ -L "$timer_link" ]] || { printf 'Hearth staging certificate timer link was not created.\n' >&2; exit 1; }
chown -h ubuntu:ubuntu "$timer_link"
printf 'Hearth staging TLS certificate is valid and auto-renewal is enabled on 129.\n'
