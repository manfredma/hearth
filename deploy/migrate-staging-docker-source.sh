#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SOURCE_ROOT/deploy/lib/staging-dump-state.sh"
source_host="${HEARTH_STAGING_SOURCE_HOST:-124.221.143.25}"
target_host="${HEARTH_STAGING_HOST:-129.211.6.82}"
ssh_key="${HEARTH_SSH_KEY:-$HOME/.ssh/ubuntu_2.pem}"
known_hosts="${HEARTH_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
source_container=hearth-staging-hearth-mysql-1
import_root=/var/lib/hearth-native-staging-migration/import
state_root=/var/lib/hearth-native-staging-migration
dump_file="$import_root/hearth.sql.gz"
lock_file=/var/lib/hearth-staging/deployment-test.lock
transfer_id="$(openssl rand -hex 8)"
remote_dump_tmp="$import_root/.hearth.sql.gz.$transfer_id.partial"
remote_env_tmp="/etc/hearth/.staging.env.$transfer_id.partial"
remote_state_helper="$import_root/.staging-dump-state.$transfer_id.sh"
readonly SSH_OPTS=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts" -o ConnectTimeout=30)
ssh_cmd() {
  ssh "${SSH_OPTS[@]}" "$@"
}

ssh_cmd "ubuntu@$target_host" "sudo -n install -d -o ubuntu -g ubuntu -m 0700 $import_root $state_root /etc/hearth /var/lib/hearth-staging"
ssh_cmd "ubuntu@$target_host" "sudo -n getent group hearth >/dev/null || sudo -n groupadd --system hearth"
ssh_cmd "ubuntu@$target_host" "sudo -n touch $lock_file && sudo -n chown ubuntu:ubuntu $lock_file && sudo -n chmod 0600 $lock_file"
state="$(ssh_cmd "ubuntu@$target_host" "sudo -n flock -x $lock_file bash -c 'for path in $state_root/import-started $state_root/dump-ready $state_root/dump-clean $dump_file; do if test -e \"\$path\"; then printf \"1 \"; else printf \"0 \"; fi; done'")"
read -r import_started dump_ready dump_clean dump_exists <<< "$state"
dump_state="$(hearth_staging_dump_state "$import_started" "$dump_ready" "$dump_clean" "$dump_exists")"
case "$dump_state" in
  import-started)
    printf 'Hearth native import has started; refusing to create or replace its source dump.\n' >&2
    exit 1
    ;;
  ready)
    ssh_cmd "ubuntu@$target_host" "sudo -n flock -x $lock_file bash -c 'test -f $dump_file && test ! -L $dump_file && gzip -t $dump_file'"
    printf 'Hearth staging migration already prepared.\n'
    exit 0
    ;;
  recover-complete)
    ssh_cmd "ubuntu@$target_host" "sudo -n flock -x $lock_file bash -c 'test -f $dump_file && test ! -L $dump_file && gzip -t $dump_file && chown ubuntu:ubuntu $dump_file && chmod 0600 $dump_file && touch $state_root/dump-ready && chown ubuntu:ubuntu $state_root/dump-ready && chmod 0600 $state_root/dump-ready'"
    printf 'Recovered the complete, warning-free Hearth source dump for %s.\n' "$target_host"
    exit 0
    ;;
  uncertain)
    printf 'An unmarked Hearth dump exists; preserving it and refusing to overwrite uncertain migration state.\n' >&2
    exit 1
    ;;
  fresh) ;;
  *) printf 'Unknown Hearth staging dump state.\n' >&2; exit 1 ;;
esac
was_running="$(ssh_cmd "ubuntu@$source_host" "sudo -n docker inspect -f '{{.State.Running}}' $source_container")"
dump_log="$(mktemp /tmp/hearth-staging-mysqldump.XXXXXX)"
cleanup() {
  ssh_cmd "ubuntu@$target_host" "sudo -n rm -f -- '$remote_dump_tmp' '$remote_env_tmp' '$remote_state_helper'" >/dev/null 2>&1 || true
  if [[ "$was_running" != true ]]; then
    ssh_cmd "ubuntu@$source_host" "sudo -n docker stop $source_container >/dev/null" || true
  fi
  rm -f "$dump_log"
}
trap cleanup EXIT
if [[ "$was_running" != true ]]; then
  ssh_cmd "ubuntu@$source_host" "sudo -n docker start $source_container >/dev/null"
fi
ssh_cmd "ubuntu@$source_host" "sudo -n cat /opt/hearth/deploy/.env" | ssh_cmd "ubuntu@$target_host" "sudo -n sh -c 'umask 077; cat > $remote_env_tmp'"
ssh_cmd "ubuntu@$target_host" "sudo -n chown ubuntu:ubuntu '$remote_env_tmp' && sudo -n chmod 0600 '$remote_env_tmp'"
ssh_cmd "ubuntu@$source_host" "sudo -n docker exec $source_container sh -lc 'MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" exec mysqldump -uroot --databases hearth --single-transaction --quick --routines --events --triggers --no-tablespaces --set-gtid-purged=OFF'" 2> "$dump_log" \
  | gzip -1 | ssh_cmd "ubuntu@$target_host" "sudo -n sh -c 'umask 077; cat > $remote_dump_tmp'"
ssh_cmd "ubuntu@$target_host" "sudo -n chown ubuntu:ubuntu '$remote_dump_tmp' && sudo -n chmod 0600 '$remote_dump_tmp'"
scp "${SSH_OPTS[@]}" "$SOURCE_ROOT/deploy/lib/staging-dump-state.sh" "ubuntu@$target_host:$remote_state_helper"
ssh_cmd "ubuntu@$target_host" "sudo -n chown ubuntu:ubuntu '$remote_state_helper' && sudo -n chmod 0600 '$remote_state_helper'"
if rg -qi 'WARNING|WARN|ERROR' "$dump_log"; then
  printf 'Hearth staging mysqldump emitted a warning or error.\n' >&2
  exit 1
fi
ssh_cmd "ubuntu@$target_host" "sudo -n env HEARTH_DUMP_TMP='$remote_dump_tmp' HEARTH_ENV_TMP='$remote_env_tmp' HEARTH_STATE_HELPER='$remote_state_helper' HEARTH_DUMP_FILE='$dump_file' HEARTH_STATE_ROOT='$state_root' HEARTH_IMPORT_ROOT='$import_root' flock -x '$lock_file' bash -s" <<'REMOTE'
set -Eeuo pipefail
dump_tmp="$HEARTH_DUMP_TMP"
env_tmp="$HEARTH_ENV_TMP"
state_helper="$HEARTH_STATE_HELPER"
dump_file="$HEARTH_DUMP_FILE"
state_root="$HEARTH_STATE_ROOT"
import_root="$HEARTH_IMPORT_ROOT"
source "$state_helper"
state="$(bash -c 'source "$1"; hearth_staging_dump_state "$2" "$3" "$4" "$5"' _ "$state_helper" \
  "$(test -e "$state_root/import-started" && printf 1 || printf 0)" \
  "$(test -e "$state_root/dump-ready" && printf 1 || printf 0)" \
  "$(test -e "$state_root/dump-clean" && printf 1 || printf 0)" \
  "$(test -e "$dump_file" && printf 1 || printf 0)")"
case "$state" in
  import-started)
    printf 'Hearth native import has started; preserving source dump state.\n' >&2
    exit 1
    ;;
  ready)
    test -f "$dump_file" && test ! -L "$dump_file" && gzip -t "$dump_file"
    printf 'Another staging migration completed while this dump was in flight; keeping the ready source dump.\n'
    exit 0
    ;;
  recover-complete)
    test -f "$dump_file" && test ! -L "$dump_file" && gzip -t "$dump_file"
    touch "$state_root/dump-ready"
    chown ubuntu:ubuntu "$state_root/dump-ready"
    chmod 0600 "$state_root/dump-ready"
    printf 'Recovered a complete Hearth source dump created by a concurrent run.\n'
    exit 0
    ;;
  uncertain)
    printf 'An unmarked Hearth dump exists; preserving it and refusing to overwrite uncertain migration state.\n' >&2
    exit 1
    ;;
  fresh) ;;
  *) printf 'Unknown Hearth migration dump state.\n' >&2; exit 1 ;;
esac
[[ -f "$dump_tmp" && ! -L "$dump_tmp" && -f "$env_tmp" && ! -L "$env_tmp" ]] || { printf 'Hearth source migration temporary files are missing.\n' >&2; exit 1; }
gzip -t "$dump_tmp"
test ! -e "$dump_file" && test ! -L "$dump_file"
mv "$env_tmp" /etc/hearth/staging.env
chown ubuntu:hearth /etc/hearth/staging.env
chmod 0640 /etc/hearth/staging.env
mv "$dump_tmp" "$dump_file"
chown ubuntu:ubuntu "$dump_file"
chmod 0600 "$dump_file"
touch "$state_root/dump-clean"
chown ubuntu:ubuntu "$state_root/dump-clean"
chmod 0600 "$state_root/dump-clean"
gzip -t "$dump_file"
touch "$state_root/dump-ready"
chown ubuntu:ubuntu "$state_root/dump-ready"
chmod 0600 "$state_root/dump-ready"
REMOTE
printf 'Hearth staging Docker source migration prepared on %s.\n' "$target_host"
