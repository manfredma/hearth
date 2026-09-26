#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

source_host="${HEARTH_STAGING_SOURCE_HOST:-124.221.143.25}"
target_host="${HEARTH_STAGING_HOST:-129.211.6.82}"
ssh_key="${HEARTH_SSH_KEY:-$HOME/.ssh/ubuntu_2.pem}"
known_hosts="${HEARTH_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
source_container=hearth-staging-hearth-mysql-1
import_root=/var/lib/hearth-native-staging-migration/import
state_root=/var/lib/hearth-native-staging-migration
dump_file="$import_root/hearth.sql.gz"
ssh_cmd() {
  ssh -i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes \
    -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts" \
    -o ConnectTimeout=30 "$@"
}

ssh_cmd "ubuntu@$target_host" "sudo -n install -d -o ubuntu -g ubuntu -m 0700 $import_root $state_root /etc/hearth"
ssh_cmd "ubuntu@$target_host" 'sudo -n getent group hearth >/dev/null || sudo -n groupadd --system hearth'
if ssh_cmd "ubuntu@$target_host" "sudo -n test -e $state_root/import-started"; then
  printf 'Hearth native import has started; refusing to create or replace its source dump.\n' >&2
  exit 1
fi
if ssh_cmd "ubuntu@$target_host" "sudo -n test -e $state_root/dump-ready"; then
  ssh_cmd "ubuntu@$target_host" "sudo -n test -f $dump_file && sudo -n test ! -L $dump_file && sudo -n gzip -t $dump_file"
  printf 'Hearth staging migration already prepared.\n'
  exit 0
fi
if ssh_cmd "ubuntu@$target_host" "sudo -n test -e $state_root/dump-clean"; then
  ssh_cmd "ubuntu@$target_host" "sudo -n gzip -t $dump_file"
  ssh_cmd "ubuntu@$target_host" "sudo -n chown ubuntu:ubuntu $dump_file && sudo -n chmod 0600 $dump_file && sudo -n touch $state_root/dump-ready && sudo -n chown ubuntu:ubuntu $state_root/dump-ready && sudo -n chmod 0600 $state_root/dump-ready"
  printf 'Recovered the complete, warning-free Hearth source dump for %s.\n' "$target_host"
  exit 0
fi
if ssh_cmd "ubuntu@$target_host" "sudo -n test -e $dump_file"; then
  ssh_cmd "ubuntu@$target_host" "sudo -n test -f $dump_file && sudo -n test ! -L $dump_file && sudo -n rm -f -- $dump_file"
fi
was_running="$(ssh_cmd "ubuntu@$source_host" "sudo -n docker inspect -f '{{.State.Running}}' $source_container")"
dump_log="$(mktemp /tmp/hearth-staging-mysqldump.XXXXXX)"
cleanup() {
  if [[ "$was_running" != true ]]; then
    ssh_cmd "ubuntu@$source_host" "sudo -n docker stop $source_container >/dev/null" || true
  fi
  rm -f "$dump_log"
}
trap cleanup EXIT
if [[ "$was_running" != true ]]; then
  ssh_cmd "ubuntu@$source_host" "sudo -n docker start $source_container >/dev/null"
fi
ssh_cmd "ubuntu@$source_host" "sudo -n cat /opt/hearth/deploy/.env" | ssh_cmd "ubuntu@$target_host" "sudo -n sh -c 'umask 077; cat > /etc/hearth/staging.env'"
ssh_cmd "ubuntu@$target_host" "sudo -n chown ubuntu:hearth /etc/hearth/staging.env && sudo -n chmod 0640 /etc/hearth/staging.env"
ssh_cmd "ubuntu@$source_host" "sudo -n docker exec $source_container sh -lc 'MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" exec mysqldump -uroot --databases hearth --single-transaction --quick --routines --events --triggers --no-tablespaces --set-gtid-purged=OFF'" 2> "$dump_log" \
  | gzip -1 | ssh_cmd "ubuntu@$target_host" "sudo -n sh -c 'umask 077; cat > $import_root/hearth.sql.gz'"
if rg -qi 'WARNING|WARN|ERROR' "$dump_log"; then
  printf 'Hearth staging mysqldump emitted a warning or error.\n' >&2
  exit 1
fi
ssh_cmd "ubuntu@$target_host" "sudo -n chown ubuntu:ubuntu $dump_file && sudo -n chmod 0600 $dump_file && sudo -n touch $state_root/dump-clean && sudo -n chown ubuntu:ubuntu $state_root/dump-clean && sudo -n chmod 0600 $state_root/dump-clean"
ssh_cmd "ubuntu@$target_host" "sudo -n gzip -t $dump_file && sudo -n touch $state_root/dump-ready && sudo -n chown ubuntu:ubuntu $state_root/dump-ready && sudo -n chmod 0600 $state_root/dump-ready"
printf 'Hearth staging Docker source migration prepared on %s.\n' "$target_host"
