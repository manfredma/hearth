#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
readonly DOMAIN=staging-hearth.bytedepth.cn
readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly SOURCE_HOST="${HEARTH_STAGING_SOURCE_HOST:-124.221.143.25}"
readonly TARGET_HOST="${HEARTH_STAGING_HOST:-129.211.6.82}"
readonly SSH_KEY="${HEARTH_SSH_KEY:-$HOME/.ssh/ubuntu_2.pem}"
readonly KNOWN_HOSTS="${HEARTH_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
readonly CERT_SOURCE="/etc/letsencrypt/live/$DOMAIN"
readonly SSH_OPTS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS" -o ConnectTimeout=30)
[[ -r "$SSH_KEY" && -r "$KNOWN_HOSTS" ]] || { printf 'Staging certificate sync requires the SSH key and known_hosts.\n' >&2; exit 1; }
work_dir="$(mktemp -d /tmp/hearth-staging-cert.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT
ssh "${SSH_OPTS[@]}" "ubuntu@$SOURCE_HOST" "sudo -n cat $CERT_SOURCE/fullchain.pem" > "$work_dir/fullchain.pem"
ssh "${SSH_OPTS[@]}" "ubuntu@$SOURCE_HOST" "sudo -n cat $CERT_SOURCE/privkey.pem" > "$work_dir/privkey.pem"
chmod 0600 "$work_dir/fullchain.pem" "$work_dir/privkey.pem"
openssl x509 -checkend 2592000 -noout -in "$work_dir/fullchain.pem" >/dev/null || { printf 'Staging Hearth certificate is expired or expires within 30 days.\n' >&2; exit 1; }
openssl x509 -checkhost "$DOMAIN" -noout -in "$work_dir/fullchain.pem" >/dev/null || { printf 'Staging Hearth certificate hostname does not match.\n' >&2; exit 1; }
sans="$(openssl x509 -in "$work_dir/fullchain.pem" -noout -ext subjectAltName 2>/dev/null | sed '1d' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
printf '%s\n' "$sans" | grep -Fx "DNS:$DOMAIN" >/dev/null || { printf 'Staging Hearth certificate lacks the exact DNS SAN.\n' >&2; exit 1; }
certificate_key="$(openssl x509 -in "$work_dir/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | shasum -a 256 | awk '{print $1}')"
private_key="$(openssl pkey -in "$work_dir/privkey.pem" -pubout -outform DER 2>/dev/null | shasum -a 256 | awk '{print $1}')"
[[ -n "$certificate_key" && "$certificate_key" == "$private_key" ]] || { printf 'Staging Hearth certificate and private key do not match.\n' >&2; exit 1; }
certificate_sha="$(shasum -a 256 "$work_dir/fullchain.pem" | awk '{print $1}')"
transfer_id="$(openssl rand -hex 8)"
readonly REMOTE_TMP="/run/hearth-cert-sync/$certificate_sha.$transfer_id"
ssh "${SSH_OPTS[@]}" "ubuntu@$TARGET_HOST" "sudo -n install -d -o ubuntu -g ubuntu -m 0700 /run/hearth-cert-sync && sudo -n install -d -o ubuntu -g ubuntu -m 0700 $REMOTE_TMP && sudo -n chown -R ubuntu:ubuntu $REMOTE_TMP"
scp "${SSH_OPTS[@]}" "$work_dir/fullchain.pem" "ubuntu@$TARGET_HOST:$REMOTE_TMP/fullchain.pem"
scp "${SSH_OPTS[@]}" "$work_dir/privkey.pem" "ubuntu@$TARGET_HOST:$REMOTE_TMP/privkey.pem"
scp "${SSH_OPTS[@]}" "$SOURCE_ROOT/deploy/lib/staging-certificate-current.sh" "ubuntu@$TARGET_HOST:$REMOTE_TMP/staging-certificate-current.sh"
ssh "${SSH_OPTS[@]}" "ubuntu@$TARGET_HOST" "sudo -n chown ubuntu:ubuntu '$REMOTE_TMP/staging-certificate-current.sh' && sudo -n chmod 0600 '$REMOTE_TMP/staging-certificate-current.sh'"
ssh "${SSH_OPTS[@]}" "ubuntu@$TARGET_HOST" "sudo -n env HEARTH_CERT_DOMAIN='$DOMAIN' HEARTH_CERT_SHA='$certificate_sha' HEARTH_CERT_TMP='$REMOTE_TMP' bash -s" <<'REMOTE'
set -Eeuo pipefail
domain="$HEARTH_CERT_DOMAIN"
certificate_sha="$HEARTH_CERT_SHA"
transfer_dir="$HEARTH_CERT_TMP"
[[ "$certificate_sha" =~ ^[a-f0-9]{64}$ && "$transfer_dir" =~ ^/run/hearth-cert-sync/[a-f0-9]{64}\.[a-f0-9]{16}$ ]] || { printf 'Invalid Hearth certificate transfer identity.\n' >&2; exit 1; }
[[ -f "$transfer_dir/fullchain.pem" && ! -L "$transfer_dir/fullchain.pem" && -f "$transfer_dir/privkey.pem" && ! -L "$transfer_dir/privkey.pem" ]] || { printf 'Hearth certificate transfer files are missing.\n' >&2; exit 1; }
[[ -f "$transfer_dir/staging-certificate-current.sh" && ! -L "$transfer_dir/staging-certificate-current.sh" ]] || { printf 'Hearth TLS promotion helper is missing.\n' >&2; exit 1; }
[[ "$(stat -c '%U:%G:%a' "$transfer_dir/fullchain.pem")" == ubuntu:ubuntu:600 \
  && "$(stat -c '%U:%G:%a' "$transfer_dir/privkey.pem")" == ubuntu:ubuntu:600 ]] || { printf 'Transferred Hearth TLS files have unsafe owner or mode.\n' >&2; exit 1; }
openssl x509 -checkend 2592000 -noout -in "$transfer_dir/fullchain.pem" >/dev/null
openssl x509 -checkhost "$domain" -noout -in "$transfer_dir/fullchain.pem" >/dev/null
certificate_key="$(openssl x509 -in "$transfer_dir/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
private_key="$(openssl pkey -in "$transfer_dir/privkey.pem" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
[[ -n "$certificate_key" && "$certificate_key" == "$private_key" ]] || { printf 'Transferred Hearth certificate/key mismatch.\n' >&2; exit 1; }
[[ "$(sha256sum "$transfer_dir/fullchain.pem" | awk '{print $1}')" == "$certificate_sha" ]] || { printf 'Transferred Hearth certificate checksum mismatch.\n' >&2; exit 1; }
install -d -o ubuntu -g ubuntu -m 0700 /var/lib/hearth-staging
touch /var/lib/hearth-staging/deployment-test.lock
chown ubuntu:ubuntu /var/lib/hearth-staging/deployment-test.lock
chmod 0600 /var/lib/hearth-staging/deployment-test.lock
exec 9>>/var/lib/hearth-staging/deployment-test.lock
flock -x 9
release_root=/etc/hearth/staging-tls/releases
current=/etc/hearth/staging-tls/current
release="$release_root/$certificate_sha"
release_staging=""
cleanup_tls_sync() {
  local status=$?
  if [[ -n "$release_staging" && "$release_staging" == "$release_root/.staging-$certificate_sha-"* \
    && -d "$release_staging" && ! -L "$release_staging" ]]; then rm -rf -- "$release_staging"; fi
  rm -rf -- "$transfer_dir"
  exit "$status"
}
trap cleanup_tls_sync EXIT
if [[ -e "$release" || -L "$release" ]]; then
  [[ -d "$release" && ! -L "$release" && -f "$release/fullchain.pem" && ! -L "$release/fullchain.pem" \
    && -f "$release/privkey.pem" && ! -L "$release/privkey.pem" ]] || { printf 'Existing Hearth TLS release is incomplete or unsafe.\n' >&2; exit 1; }
  [[ "$(sha256sum "$release/fullchain.pem" | awk '{print $1}')" == "$certificate_sha" ]] || { printf 'Existing Hearth TLS release checksum does not match its name.\n' >&2; exit 1; }
  existing_key="$(openssl x509 -in "$release/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
  existing_private="$(openssl pkey -in "$release/privkey.pem" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
  [[ -n "$existing_key" && "$existing_key" == "$existing_private" ]] || { printf 'Existing Hearth TLS release certificate/key mismatch.\n' >&2; exit 1; }
else
  release_staging="$release_root/.staging-$certificate_sha-$$"
  [[ ! -e "$release_staging" && ! -L "$release_staging" ]] || { printf 'Hearth TLS staging directory already exists.\n' >&2; exit 1; }
  install -d -o ubuntu -g ubuntu -m 0700 /etc/hearth/staging-tls "$release_root" "$release_staging"
  install -o ubuntu -g ubuntu -m 0644 "$transfer_dir/fullchain.pem" "$release_staging/fullchain.pem"
  install -o ubuntu -g ubuntu -m 0600 "$transfer_dir/privkey.pem" "$release_staging/privkey.pem"
  [[ "$(sha256sum "$release_staging/fullchain.pem" | awk '{print $1}')" == "$certificate_sha" ]] || { printf 'Staged Hearth TLS certificate checksum mismatch.\n' >&2; exit 1; }
  mv "$release_staging" "$release"
  release_staging=""
fi
if [[ -d "$current" && ! -L "$current" && -f /etc/nginx/conf.d/hearth-staging.conf ]]; then
  printf 'Refusing to migrate an active Hearth TLS directory while its public route is installed.\n' >&2
  exit 1
fi
source "$transfer_dir/staging-certificate-current.sh"
hearth_staging_create_tls_link() { sudo -n -u ubuntu -- ln -s "$1" "$2"; }
hearth_staging_promote_tls_current "$current" "$release_root" "$release"
openssl x509 -checkend 2592000 -noout -in "$current/fullchain.pem" >/dev/null
openssl x509 -checkhost "$domain" -noout -in "$current/fullchain.pem" >/dev/null
installed_cert_key="$(openssl x509 -in "$current/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
installed_privkey="$(openssl pkey -in "$current/privkey.pem" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
[[ -n "$installed_cert_key" && "$installed_cert_key" == "$installed_privkey" ]] || { printf 'Installed Hearth TLS current pointer does not resolve to a matching bundle.\n' >&2; exit 1; }
[[ "$(stat -c '%U:%G:%a' "$current/fullchain.pem")" == ubuntu:ubuntu:644 \
  && "$(stat -c '%U:%G:%a' "$current/privkey.pem")" == ubuntu:ubuntu:600 ]] || { printf 'Installed Hearth TLS bundle has unsafe owner or mode.\n' >&2; exit 1; }
[[ "$(stat -c '%U:%G' "$current")" == ubuntu:ubuntu ]] || { printf 'Hearth TLS current pointer is not ubuntu-owned.\n' >&2; exit 1; }
rm -rf -- "$transfer_dir"
printf 'Installed Hearth staging TLS certificate bundle %s.\n' "$certificate_sha"
REMOTE
printf 'Synchronized validated Hearth staging TLS certificate to %s.\n' "$TARGET_HOST"
