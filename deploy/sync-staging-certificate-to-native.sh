#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
readonly DOMAIN=staging-hearth.bytedepth.cn
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
readonly REMOTE_TMP="/run/hearth-cert-sync/$certificate_sha"
ssh "${SSH_OPTS[@]}" "ubuntu@$TARGET_HOST" "sudo -n install -d -o ubuntu -g ubuntu -m 0700 /run/hearth-cert-sync && sudo -n install -d -o ubuntu -g ubuntu -m 0700 $REMOTE_TMP && sudo -n chown -R ubuntu:ubuntu $REMOTE_TMP"
scp "${SSH_OPTS[@]}" "$work_dir/fullchain.pem" "ubuntu@$TARGET_HOST:$REMOTE_TMP/fullchain.pem"
scp "${SSH_OPTS[@]}" "$work_dir/privkey.pem" "ubuntu@$TARGET_HOST:$REMOTE_TMP/privkey.pem"
ssh "${SSH_OPTS[@]}" "ubuntu@$TARGET_HOST" "sudo -n env HEARTH_CERT_DOMAIN='$DOMAIN' HEARTH_CERT_SHA='$certificate_sha' HEARTH_CERT_TMP='$REMOTE_TMP' bash -s" <<'REMOTE'
set -Eeuo pipefail
domain="$HEARTH_CERT_DOMAIN"
certificate_sha="$HEARTH_CERT_SHA"
transfer_dir="$HEARTH_CERT_TMP"
[[ "$certificate_sha" =~ ^[a-f0-9]{64}$ && "$transfer_dir" == "/run/hearth-cert-sync/$certificate_sha" ]] || { printf 'Invalid Hearth certificate transfer identity.\n' >&2; exit 1; }
[[ -f "$transfer_dir/fullchain.pem" && ! -L "$transfer_dir/fullchain.pem" && -f "$transfer_dir/privkey.pem" && ! -L "$transfer_dir/privkey.pem" ]] || { printf 'Hearth certificate transfer files are missing.\n' >&2; exit 1; }
trap 'rm -rf -- "$transfer_dir"' EXIT
openssl x509 -checkend 2592000 -noout -in "$transfer_dir/fullchain.pem" >/dev/null
openssl x509 -checkhost "$domain" -noout -in "$transfer_dir/fullchain.pem" >/dev/null
certificate_key="$(openssl x509 -in "$transfer_dir/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
private_key="$(openssl pkey -in "$transfer_dir/privkey.pem" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
[[ -n "$certificate_key" && "$certificate_key" == "$private_key" ]] || { printf 'Transferred Hearth certificate/key mismatch.\n' >&2; exit 1; }
[[ "$(sha256sum "$transfer_dir/fullchain.pem" | awk '{print $1}')" == "$certificate_sha" ]] || { printf 'Transferred Hearth certificate checksum mismatch.\n' >&2; exit 1; }
release_root=/etc/hearth/staging-tls/releases
current=/etc/hearth/staging-tls/current
release="$release_root/$certificate_sha"
install -d -o ubuntu -g ubuntu -m 0700 /etc/hearth/staging-tls "$release_root" "$release"
staged_fullchain="$(mktemp "$release/.fullchain.XXXXXX")"
staged_privkey="$(mktemp "$release/.privkey.XXXXXX")"
install -o ubuntu -g ubuntu -m 0644 "$transfer_dir/fullchain.pem" "$staged_fullchain"
install -o ubuntu -g ubuntu -m 0600 "$transfer_dir/privkey.pem" "$staged_privkey"
mv -f "$staged_fullchain" "$release/fullchain.pem"
mv -f "$staged_privkey" "$release/privkey.pem"
if [[ -L "$current" ]]; then
  old_target="$(readlink -f "$current")"
  [[ "$old_target" == "$release_root/"* ]] || { printf 'Refusing to replace an unrelated Hearth TLS path.\n' >&2; exit 1; }
  rm -f -- "$current"
fi
[[ ! -e "$current" || ( -d "$current" && ! -L "$current" ) ]] || { printf 'Hearth TLS current path is not a directory.\n' >&2; exit 1; }
install -d -o ubuntu -g ubuntu -m 0700 "$current"
staged_fullchain="$(mktemp "$current/.fullchain.XXXXXX")"
staged_privkey="$(mktemp "$current/.privkey.XXXXXX")"
install -o ubuntu -g ubuntu -m 0644 "$release/fullchain.pem" "$staged_fullchain"
install -o ubuntu -g ubuntu -m 0600 "$release/privkey.pem" "$staged_privkey"
mv -f "$staged_fullchain" "$current/fullchain.pem"
mv -f "$staged_privkey" "$current/privkey.pem"
chown ubuntu:ubuntu "$release/fullchain.pem" "$release/privkey.pem"
chmod 0644 "$release/fullchain.pem"
chmod 0600 "$release/privkey.pem"
rm -rf -- "$transfer_dir"
printf 'Installed Hearth staging TLS certificate bundle %s.\n' "$certificate_sha"
REMOTE
printf 'Synchronized validated Hearth staging TLS certificate to %s.\n' "$TARGET_HOST"
