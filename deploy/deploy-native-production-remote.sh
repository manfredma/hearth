#!/usr/bin/env bash
set -Eeuo pipefail
TAG="${1:-}"
[[ "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { printf 'Usage: %s vX.Y.Z\n' "$0" >&2; exit 2; }
readonly HOST="${HEARTH_PRODUCTION_HOST:-175.24.197.202}"
readonly STAGING_HOST="${HEARTH_STAGING_HOST:-129.211.6.82}"
readonly SSH_KEY="${HEARTH_PRODUCTION_SSH_KEY:-$HOME/.ssh/ubuntu_2.pem}"
readonly KNOWN_HOSTS="${HEARTH_PRODUCTION_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
readonly DOMAIN=hearth.bytedepth.cn
readonly SSH_OPTS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS" -o ConnectTimeout=30)
[[ -r "$SSH_KEY" && -r "$KNOWN_HOSTS" ]] || { printf 'Production SSH key/known_hosts required.\n' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { printf 'Production deployment requires a clean worktree.\n' >&2; exit 1; }
git fetch --quiet origin main "refs/tags/$TAG:refs/tags/$TAG"
[[ "$(git cat-file -t "$TAG" 2>/dev/null || true)" == tag ]] || { printf 'Release must be an annotated tag.\n' >&2; exit 1; }
readonly HEARTH_COMMIT_ID="$(git rev-parse "$TAG^{commit}")"
commit="$HEARTH_COMMIT_ID"
git merge-base --is-ancestor "$commit" "$(git rev-parse origin/main)" || { printf 'Release tag is not in origin/main history.\n' >&2; exit 1; }
build_root="$(mktemp -d)"
remote_admin_hash=""
readonly remote_jar="/tmp/hearth-prod-$TAG.jar"
readonly remote_src="/tmp/hearth-prod-$TAG.tar"
remote_upload_started=0
cleanup() {
  if [[ -n "$remote_admin_hash" ]]; then
    ssh "${SSH_OPTS[@]}" -o ConnectTimeout=5 "ubuntu@$HOST" "sudo -n rm -f -- '$remote_admin_hash'" >/dev/null 2>&1 || true
  fi
  if (( remote_upload_started == 1 )); then
    ssh "${SSH_OPTS[@]}" -o ConnectTimeout=5 "ubuntu@$HOST" "sudo -n rm -f -- '$remote_jar' '$remote_src'" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$build_root"
}
trap cleanup EXIT
pom_version="$(git show "$commit:pom.xml" | sed -n 's/.*<version>\([^<]*\)<\/version>.*/\1/p' | head -1)"
ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" \
  "sudo -n bash -c 'history=/var/lib/hearth-deploy/release-history; if [[ -e \$history ]]; then [[ -f \$history && ! -L \$history ]] && cat \$history; fi'" \
  > "$build_root/production-release-history"
"$(dirname "$0")/verify-release-version.sh" "$TAG" "$pom_version" "$build_root/production-release-history"
ssh "${SSH_OPTS[@]}" "ubuntu@$STAGING_HOST" \
  'sudo -n cat /var/lib/hearth-staging/test-history/staging-integration' > "$build_root/staging-integration.evidence"
ssh "${SSH_OPTS[@]}" "ubuntu@$STAGING_HOST" \
  'sudo -n cat /var/lib/hearth-staging/test-history/staging-e2e' > "$build_root/staging-e2e.evidence"
"$(dirname "$0")/verify-staging-evidence.sh" "$commit" \
  "$build_root/staging-integration.evidence" "$build_root/staging-e2e.evidence"
git archive "$commit" | tar -x -C "$build_root"
(cd "$build_root" && npm ci --ignore-scripts --no-audit --no-fund && npm run build)
version="$(sed -n 's/.*<version>\([^<]*\)<\/version>.*/\1/p' "$build_root/pom.xml" | head -1)"
built_at="$(date -u +%FT%TZ)"
printf 'hearth.build.version=%s\nhearth.build.commit-id=%s\nhearth.build.built-at=%s\n' "$version" "$HEARTH_COMMIT_ID" "$built_at" > "$build_root/hearth-start/src/main/resources/hearth-build.properties"
java_home="${JAVA_HOME:-$('/usr/libexec/java_home' -v 25 2>/dev/null || true)}"
[[ -x "$java_home/bin/java" ]] || { printf 'Java 25 is required.\n' >&2; exit 1; }
build_log="$build_root/build.log"
set +e
(cd "$build_root" && JAVA_HOME="$java_home" ./mvnw -B -DskipTests -Dsort.skip=true clean package) 2>&1 | tee "$build_log"
build_status="${PIPESTATUS[0]}"
set -e
(( build_status == 0 )) || exit "$build_status"
if rg -Eqi '\bWARN(ING)?\b' "$build_log"; then printf 'Hearth production build emitted WARNING.\n' >&2; exit 1; fi
jar_file="$build_root/hearth-start/target/hearth-start.jar"
[[ -f "$jar_file" ]]
jar_sha="$(shasum -a 256 "$jar_file" | awk '{print $1}')"
staging_admin_hash="$(ssh "${SSH_OPTS[@]}" "ubuntu@$STAGING_HOST" \
  "sudo -n mysql --defaults-extra-file=/etc/bytedepth/staging-native-mysql-admin.cnf --protocol=tcp --host=127.0.0.1 --port=13306 --database=hearth --batch --skip-column-names --execute=\"SELECT password_hash FROM identity_credential WHERE login='admin' AND enabled=TRUE\"")"
[[ "$staging_admin_hash" =~ ^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$ ]] || { printf 'Staging admin credential hash is missing or unsupported; production bootstrap is refused.\n' >&2; exit 1; }
local_admin_hash_file="$build_root/hearth-production-admin.hash"
printf '%s\n' "$staging_admin_hash" > "$local_admin_hash_file"
chmod 0600 "$local_admin_hash_file"
unset staging_admin_hash
remote_admin_hash="/run/hearth-production-bootstrap/$TAG.admin-hash"
ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" 'sudo -n install -d -o ubuntu -g ubuntu -m 0700 /run/hearth-production-bootstrap'
scp "${SSH_OPTS[@]}" "$local_admin_hash_file" "ubuntu@$HOST:$remote_admin_hash"
ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" "sudo -n chown ubuntu:ubuntu '$remote_admin_hash' && sudo -n chmod 0600 '$remote_admin_hash'"
archive="$build_root/source.tar"
git archive "$commit" > "$archive"
remote_upload_started=1
scp "${SSH_OPTS[@]}" "$jar_file" "ubuntu@$HOST:$remote_jar"
scp "${SSH_OPTS[@]}" "$archive" "ubuntu@$HOST:$remote_src"
ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" "sudo -n env HEARTH_TAG='$TAG' HEARTH_COMMIT='$commit' HEARTH_JAR_SHA='$jar_sha' HEARTH_JAR='$remote_jar' HEARTH_SOURCE='$remote_src' HEARTH_DOMAIN='$DOMAIN' HEARTH_ADMIN_HASH_FILE='$remote_admin_hash' bash -s" <<'REMOTE'
set -Eeuo pipefail
tag="$HEARTH_TAG"
commit="$HEARTH_COMMIT"
domain="$HEARTH_DOMAIN"
admin_hash_file="${HEARTH_ADMIN_HASH_FILE:?production admin hash file required}"
[[ "$admin_hash_file" == "/run/hearth-production-bootstrap/$tag.admin-hash" && -f "$admin_hash_file" && ! -L "$admin_hash_file" ]] || { printf 'Production admin hash file is invalid.\n' >&2; exit 1; }
[[ "$(stat -c '%U:%G:%a' "$admin_hash_file")" == ubuntu:ubuntu:600 ]] || { printf 'Production admin hash file ownership/mode is invalid.\n' >&2; exit 1; }
trap 'rm -f -- "$admin_hash_file" "$HEARTH_JAR" "$HEARTH_SOURCE"' EXIT
src="/opt/hearth-native/source/$commit"
rel="/opt/hearth-native/releases/$tag"
nginx_unit=bytedepth-production-green-public-nginx.service
app_unit=hearth-production-native-app.service
edge_unit=hearth-production-native-edge.service
release_history=/var/lib/hearth-deploy/release-history
route=/etc/nginx/conf.d/hearth-production.conf
transaction_dir="/var/lib/hearth-deploy/transactions/$tag"
install -d -o ubuntu -g ubuntu -m 0700 /var/lib/hearth-deploy
touch /var/lib/hearth-deploy/production.lock
chown ubuntu:ubuntu /var/lib/hearth-deploy/production.lock
chmod 0600 /var/lib/hearth-deploy/production.lock
exec 9>>/var/lib/hearth-deploy/production.lock
flock -x 9
systemctl is-active --quiet "$nginx_unit"
[[ ! -e "$release_history" || ( -f "$release_history" && ! -L "$release_history" ) ]] || { printf 'Production release history is unsafe.\n' >&2; exit 1; }
if [[ -f "$release_history" ]] && awk -F= -v version="$tag" '$1 == "version" && $2 == version {found=1} END {exit !found}' "$release_history"; then
  printf 'Release tag is already present in production history.\n' >&2
  exit 1
fi
[[ ! -e "$src" && ! -L "$src" && ! -e "$rel" && ! -L "$rel" ]] || { printf 'Release source/artifact path already exists; refusing to reuse mutable release state.\n' >&2; exit 1; }
[[ ! -e "$transaction_dir" && ! -L "$transaction_dir" ]] || { printf 'An unfinished transaction exists for this release tag.\n' >&2; exit 1; }

shared_units=(
  bytedepth-production-green-app.service
  bytedepth-production-green-edge.service
  bytedepth-production-green-meilisearch.service
  bytedepth-production-green-mysql.service
  bytedepth-production-green-redis.service
  bytedepth-production-green-public-nginx.service
  career-production-blue-edge.service career-production-native-app.service career-production-native-edge.service
  daylilt-production-blue-edge.service daylilt-production-native-app.service daylilt-production-native-edge.service
  toolbox-production-blue-edge.service toolbox-production-native-app.service toolbox-production-native-edge.service
)
shared_route_hosts=(
  bytedepth.cn
  career.bytedepth.cn
  daylilt.bytedepth.cn
  toolbox.bytedepth.cn
)
shared_service_snapshot() {
  local unit state
  for unit in "${shared_units[@]}"; do
    state="$(systemctl is-active "$unit" 2>/dev/null || true)"
    printf '%s=%s\n' "$unit" "${state:-unknown}"
  done
}
public_route_snapshot() {
  local host code
  for host in "${shared_route_hosts[@]}"; do
    code="$(curl --silent --show-error --max-time 10 --resolve "$host:443:127.0.0.1" -o /dev/null -w '%{http_code}' "https://$host/")"
    [[ "$code" =~ ^[1-4][0-9]{2}$ ]] || { printf 'Shared public route is unhealthy: %s returned %s.\n' "$host" "$code" >&2; return 1; }
    printf '%s=%s\n' "$host" "$code"
  done
}
listener_snapshot() { ss -ltnH | awk '{print $4}' | sort -u; }
shared_services_before="$(shared_service_snapshot)"
routes_before="$(public_route_snapshot)"
listeners_before="$(listener_snapshot)"
while IFS= read -r listener; do
  port="${listener##*:}"
  [[ "$port" != 18112 && "$port" != 18113 ]] || { printf 'Hearth production port is already occupied: %s.\n' "$listener" >&2; exit 1; }
done <<< "$listeners_before"
deployment_started="$(date --iso-8601=seconds)"

install -d -o ubuntu -g ubuntu -m 0700 "$transaction_dir"
trap 'rm -f -- "$admin_hash_file" "$HEARTH_JAR" "$HEARTH_SOURCE"; rm -rf -- "$transaction_dir"' EXIT
route_was_present=0
route_changed=0
history_was_present=0
history_changed=0
release_transaction_loaded=0
release_committed=0
artifacts_created=0
if [[ -e "$route" || -L "$route" ]]; then
  [[ -f "$route" && ! -L "$route" ]] || { printf 'Hearth Nginx route is not a regular file.\n' >&2; exit 1; }
  install -o ubuntu -g ubuntu -m 0644 "$route" "$transaction_dir/previous-route.conf"
  route_was_present=1
fi
if [[ -e "$release_history" ]]; then
  install -o ubuntu -g ubuntu -m 0600 "$release_history" "$transaction_dir/previous-release-history"
  history_was_present=1
fi
cleanup_production_deployment() {
  local status=$? rollback_status=0 nginx_log
  if (( release_committed == 0 )); then
    if (( history_changed == 1 )); then
      if (( history_was_present == 1 )); then
        install -o ubuntu -g ubuntu -m 0600 "$transaction_dir/previous-release-history" "$release_history" || rollback_status=1
      else
        rm -f -- "$release_history" || rollback_status=1
      fi
    fi
    if (( route_changed == 1 )); then
      if (( route_was_present == 1 )); then
        install -o ubuntu -g ubuntu -m 0644 "$transaction_dir/previous-route.conf" "$route" || rollback_status=1
      else
        rm -f -- "$route" || rollback_status=1
      fi
      nginx_log="$transaction_dir/nginx-rollback.log"
      install -o ubuntu -g ubuntu -m 0600 /dev/null "$nginx_log"
      if nginx -t -c /etc/bytedepth/production-green-public-nginx.conf > "$nginx_log" 2>&1; then
        if rg -n -i '\bWARN(ING)?\b' "$nginx_log"; then rollback_status=1; fi
        systemctl reload "$nginx_unit" || rollback_status=1
      else
        cat "$nginx_log" >&2
        rollback_status=1
      fi
    fi
    if (( release_transaction_loaded == 1 )); then hearth_production_release_rollback || rollback_status=1; fi
    if (( rollback_status == 0 )); then
      if (( artifacts_created == 1 )); then
      [[ "$src" == "/opt/hearth-native/source/$commit" && -d "$src" && ! -L "$src" ]] && rm -rf -- "$src"
      [[ "$rel" == "/opt/hearth-native/releases/$tag" && -d "$rel" && ! -L "$rel" ]] && rm -rf -- "$rel"
      fi
      rm -rf -- "$transaction_dir"
    fi
  else
    rm -rf -- "$transaction_dir"
  fi
  rm -f -- "$admin_hash_file" "$HEARTH_JAR" "$HEARTH_SOURCE"
  (( rollback_status == 0 )) || status=1
  exit "$status"
}
trap cleanup_production_deployment EXIT

artifacts_created=1
install -d -o ubuntu -g ubuntu -m 0755 /opt/hearth-native/source /opt/hearth-native/releases "$src" "$rel"
tar -xf "$HEARTH_SOURCE" -C "$src"
chown -R ubuntu:ubuntu "$src"
printf '%s\n' "$commit" > "$src/.hearth-commit"
chown ubuntu:ubuntu "$src/.hearth-commit"
install -d -o ubuntu -g ubuntu -m 0755 /etc/hearth
install -o ubuntu -g ubuntu -m 0644 "$src/deploy/hearth-native.conf.example" /etc/hearth/hearth-native.conf
cd "$src"
./deploy/bootstrap-native-env.sh production
./deploy/bootstrap-native-mysql.sh production
./deploy/install-native-runtime.sh production
./deploy/provision-production-certificate.sh production
install -o ubuntu -g ubuntu -m 0644 "$HEARTH_JAR" "$rel/app.jar"
[[ "$(sha256sum "$rel/app.jar" | awk '{print $1}')" == "$HEARTH_JAR_SHA" ]]
source "$src/deploy/lib/production-release-transaction.sh"
hearth_production_link() { sudo -n -u ubuntu -- ln -sfn "$1" "$2"; }
release_transaction_loaded=1
hearth_production_release_begin /opt/hearth-native/current /opt/hearth-native/source/current "$rel" "$src" "$app_unit" "$edge_unit"
ready=0
for attempt in $(seq 1 60); do
  if curl --fail --silent --show-error --max-time 5 http://127.0.0.1:18112/api/health >/dev/null; then ready=1; break; fi
  sleep 2
done
(( ready == 1 )) || { printf 'Hearth production health timeout.\n' >&2; exit 1; }
./deploy/bootstrap-production-admin.sh < "$admin_hash_file"
rm -f -- "$admin_hash_file"
v="$(curl --fail --silent --show-error --max-time 10 http://127.0.0.1:18112/version)"
jq -e --arg commit "$commit" '.commitId == $commit' <<< "$v" >/dev/null
route_changed=1
install -o ubuntu -g ubuntu -m 0644 "$src/deploy/nginx/hearth-native-production.conf.template" "$route"
nginx_log="$transaction_dir/nginx-test.log"
install -o ubuntu -g ubuntu -m 0600 /dev/null "$nginx_log"
nginx -t -c /etc/bytedepth/production-green-public-nginx.conf > "$nginx_log" 2>&1 || { cat "$nginx_log" >&2; exit 1; }
if rg -n -i '\bWARN(ING)?\b' "$nginx_log"; then printf 'Production Nginx configuration test emitted WARNING.\n' >&2; exit 1; fi
chown ubuntu:ubuntu "$nginx_log"
chmod 0600 "$nginx_log"
systemctl reload "$nginx_unit"
d="$(curl --fail --silent --show-error --max-time 15 --resolve "$domain:443:127.0.0.1" "https://$domain/.well-known/openid-configuration")"
jq -e --arg issuer "https://$domain" '.issuer == $issuer' <<< "$d" >/dev/null
p="$(curl --fail --silent --show-error --max-time 15 --resolve "$domain:443:127.0.0.1" "https://$domain/version")"
jq -e --arg commit "$commit" '.commitId == $commit' <<< "$p" >/dev/null
shared_services_after="$(shared_service_snapshot)"
[[ "$shared_services_after" == "$shared_services_before" ]] || { printf 'A shared project systemd unit changed state during Hearth deployment.\n' >&2; diff -u <(printf '%s\n' "$shared_services_before") <(printf '%s\n' "$shared_services_after") >&2 || true; exit 1; }
routes_after="$(public_route_snapshot)"
[[ "$routes_after" == "$routes_before" ]] || { printf 'A shared project public route changed during Hearth deployment.\n' >&2; diff -u <(printf '%s\n' "$routes_before") <(printf '%s\n' "$routes_after") >&2 || true; exit 1; }
listeners_after="$(listener_snapshot)"
expected_listeners="$(printf '%s\n127.0.0.1:18112\n127.0.0.1:18113\n' "$listeners_before" | sort -u)"
[[ "$listeners_after" == "$expected_listeners" ]] || { printf 'Production listeners changed beyond Hearth loopback ports.\n' >&2; diff -u <(printf '%s\n' "$expected_listeners") <(printf '%s\n' "$listeners_after") >&2 || true; exit 1; }
journal="$(journalctl --unit "$app_unit" --unit "$edge_unit" --since "$deployment_started" --no-pager --output=short-iso)"
if rg -n -i '\bWARN(ING)?\b' <<< "$journal"; then printf 'Hearth production service journal emitted WARNING.\n' >&2; exit 1; fi
install -d -o ubuntu -g ubuntu -m 0700 /var/lib/hearth-deploy
history_changed=1
printf 'version=%s\ncommit=%s\ndeployed_at=%s\nruntime_mode=host-native\n---\n' "$tag" "$commit" "$(date -u +%FT%TZ)" >> /var/lib/hearth-deploy/release-history
chown ubuntu:ubuntu /var/lib/hearth-deploy/release-history
chmod 0600 /var/lib/hearth-deploy/release-history
hearth_production_release_commit
release_committed=1
printf 'Hearth native production deployment passed: %s\n' "$tag"
REMOTE
