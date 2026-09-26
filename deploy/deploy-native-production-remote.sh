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
cleanup() {
  if [[ -n "$remote_admin_hash" ]]; then
    ssh "${SSH_OPTS[@]}" -o ConnectTimeout=5 "ubuntu@$HOST" "sudo -n rm -f -- '$remote_admin_hash'" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$build_root"
}
trap cleanup EXIT
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
remote_jar="/tmp/hearth-prod-$TAG.jar"
remote_src="/tmp/hearth-prod-$TAG.tar"
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
trap 'rm -f -- "$admin_hash_file"' EXIT
src="/opt/hearth-native/source/$commit"
rel="/opt/hearth-native/releases/$tag"
nginx_unit=bytedepth-production-green-public-nginx.service
systemctl is-active --quiet "$nginx_unit"
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
if [[ -d /opt/hearth-native/current && ! -L /opt/hearth-native/current ]]; then rmdir /opt/hearth-native/current; fi
sudo -n -u ubuntu -- ln -sfn "$src" /opt/hearth-native/source/current
sudo -n -u ubuntu -- ln -sfn "$rel" /opt/hearth-native/current
systemctl start hearth-production-native-app.service hearth-production-native-edge.service
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
install -o ubuntu -g ubuntu -m 0644 "$src/deploy/nginx/hearth-native-production.conf.template" /etc/nginx/conf.d/hearth-production.conf
nginx -t -c /etc/bytedepth/production-green-public-nginx.conf
systemctl reload "$nginx_unit"
d="$(curl --fail --silent --show-error --max-time 15 --resolve "$domain:443:127.0.0.1" "https://$domain/.well-known/openid-configuration")"
jq -e --arg issuer "https://$domain" '.issuer == $issuer' <<< "$d" >/dev/null
p="$(curl --fail --silent --show-error --max-time 15 --resolve "$domain:443:127.0.0.1" "https://$domain/version")"
jq -e --arg commit "$commit" '.commitId == $commit' <<< "$p" >/dev/null
install -d -o ubuntu -g ubuntu -m 0700 /var/lib/hearth-deploy
printf 'version=%s\ncommit=%s\ndeployed_at=%s\nruntime_mode=host-native\n---\n' "$tag" "$commit" "$(date -u +%FT%TZ)" >> /var/lib/hearth-deploy/release-history
chown ubuntu:ubuntu /var/lib/hearth-deploy/release-history
chmod 0600 /var/lib/hearth-deploy/release-history
rm -f "$HEARTH_JAR" "$HEARTH_SOURCE"
printf 'Hearth native production deployment passed: %s\n' "$tag"
REMOTE
