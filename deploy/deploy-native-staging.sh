#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 1 && -n "$1" ]] || { printf 'Usage: %s <ref>\n' "$0" >&2; exit 2; }
readonly REF="$1"
readonly HOST="${HEARTH_STAGING_HOST:-129.211.6.82}"
readonly SSH_KEY="${HEARTH_SSH_KEY:-$HOME/.ssh/ubuntu_2.pem}"
readonly KNOWN_HOSTS="${HEARTH_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
readonly DOMAIN=staging-hearth.bytedepth.cn
readonly SSH_OPTS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS" -o ConnectTimeout=30)
[[ -r "$SSH_KEY" && -r "$KNOWN_HOSTS" ]] || { printf 'SSH key and known_hosts required.\n' >&2; exit 1; }
readonly HEARTH_COMMIT_ID="$(git rev-parse --verify "$REF^{commit}")"
commit="$HEARTH_COMMIT_ID"
build_root="$(mktemp -d)"
trap 'rm -rf "$build_root"' EXIT
git archive "$commit" | tar -x -C "$build_root"
(cd "$build_root" && npm ci --ignore-scripts --no-audit --no-fund && npm run build)
version="$(sed -n 's/.*<version>\([^<]*\)<\/version>.*/\1/p' "$build_root/pom.xml" | head -1)"
built_at="$(date -u +%FT%TZ)"
printf 'hearth.build.version=%s\nhearth.build.commit-id=%s\nhearth.build.built-at=%s\n' "$version" "$HEARTH_COMMIT_ID" "$built_at" > "$build_root/hearth-start/src/main/resources/hearth-build.properties"
java_home="${JAVA_HOME:-$('/usr/libexec/java_home' -v 25 2>/dev/null || true)}"
[[ -x "$java_home/bin/java" ]] || { printf 'Java 25 required.\n' >&2; exit 1; }
build_log="$build_root/build.log"
set +e
(cd "$build_root" && JAVA_HOME="$java_home" ./mvnw -B -DskipTests -Dsort.skip=true clean package) 2>&1 | tee "$build_log"
build_status="${PIPESTATUS[0]}"
set -e
(( build_status == 0 )) || exit "$build_status"
if rg -Eqi '\bWARN(ING)?\b' "$build_log"; then printf 'Build emitted WARNING.\n' >&2; exit 1; fi
jar_file="$build_root/hearth-start/target/hearth-start.jar"
[[ -f "$jar_file" ]]
jar_sha="$(shasum -a 256 "$jar_file" | awk '{print $1}')"
archive="$build_root/source.tar"
git archive "$commit" > "$archive"
remote_jar="/tmp/hearth-staging-$commit.jar"
remote_src="/tmp/hearth-staging-$commit.tar"
scp "${SSH_OPTS[@]}" "$jar_file" "ubuntu@$HOST:$remote_jar"
scp "${SSH_OPTS[@]}" "$archive" "ubuntu@$HOST:$remote_src"
HEARTH_STAGING_HOST="$HOST" HEARTH_SSH_KEY="$SSH_KEY" HEARTH_SSH_KNOWN_HOSTS="$KNOWN_HOSTS" "$build_root/deploy/migrate-staging-docker-source.sh"
HEARTH_STAGING_SOURCE_HOST="${HEARTH_STAGING_SOURCE_HOST:-124.221.143.25}" HEARTH_STAGING_HOST="$HOST" \
  HEARTH_SSH_KEY="$SSH_KEY" HEARTH_SSH_KNOWN_HOSTS="$KNOWN_HOSTS" \
  "$build_root/deploy/sync-staging-certificate-to-native.sh"
ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" 'sudo -n install -d -o ubuntu -g ubuntu -m 0700 /var/lib/hearth-staging'
ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" 'sudo -n touch /var/lib/hearth-staging/deployment-test.lock && sudo -n chown ubuntu:ubuntu /var/lib/hearth-staging/deployment-test.lock && sudo -n chmod 0600 /var/lib/hearth-staging/deployment-test.lock'
ssh "${SSH_OPTS[@]}" "ubuntu@$HOST" "sudo -n env HEARTH_COMMIT='$commit' HEARTH_JAR_SHA='$jar_sha' HEARTH_JAR='$remote_jar' HEARTH_SOURCE='$remote_src' HEARTH_DOMAIN='$DOMAIN' flock -x /var/lib/hearth-staging/deployment-test.lock bash -s" <<'REMOTE'
set -Eeuo pipefail
c="$HEARTH_COMMIT"
s="/opt/hearth-native/source/$c"
r="/opt/hearth-native/releases/$c"
state=/var/lib/hearth-staging
rm -f "$state/test-history/staging-integration" "$state/test-history/staging-e2e"
install -d -o ubuntu -g ubuntu -m 0755 "$s" "$r" /opt/hearth-native/source /opt/hearth-native/releases
tar -xf "$HEARTH_SOURCE" -C "$s"
chown -R ubuntu:ubuntu "$s"
printf '%s\n' "$c" > "$s/.hearth-commit"
chown ubuntu:ubuntu "$s/.hearth-commit"
install -d -o ubuntu -g ubuntu -m 0755 /etc/hearth
install -o ubuntu -g ubuntu -m 0644 "$s/deploy/hearth-native.conf.example" /etc/hearth/hearth-native.conf
install -o ubuntu -g ubuntu -m 0644 "$HEARTH_JAR" "$r/app.jar"
[[ "$(sha256sum "$r/app.jar" | awk '{print $1}')" == "$HEARTH_JAR_SHA" ]]
cd "$s"
./deploy/bootstrap-native-env.sh staging
./deploy/bootstrap-native-mysql.sh staging
./deploy/migrate-staging-docker-to-native.sh prepare
./deploy/install-native-runtime.sh staging
if [[ -d /opt/hearth-native/current && ! -L /opt/hearth-native/current ]]; then rmdir /opt/hearth-native/current; fi
sudo -n -u ubuntu -- ln -sfn "$s" /opt/hearth-native/source/current
sudo -n -u ubuntu -- ln -sfn "$r" /opt/hearth-native/current
./deploy/bootstrap-staging-runtime.sh --lock-held
systemctl restart hearth-staging-native-app.service hearth-staging-native-edge.service
ready=0
for attempt in $(seq 1 60); do
  if curl --fail --silent --show-error --max-time 5 http://127.0.0.1:18110/api/health >/dev/null; then ready=1; break; fi
  sleep 2
done
(( ready == 1 ))
v="$(curl --fail --silent --show-error --max-time 10 http://127.0.0.1:18110/version)"
jq -e --arg commit "$c" '.commitId == $commit' <<< "$v" >/dev/null
install -d -o ubuntu -g ubuntu -m 0700 "$state/test-history"
install -o ubuntu -g ubuntu -m 0644 "$s/deploy/nginx/hearth-native-staging.conf.template" /etc/nginx/conf.d/hearth-staging.conf
nginx -t
systemctl reload nginx.service
d="$(curl --fail --silent --show-error --max-time 15 --resolve "$HEARTH_DOMAIN:443:127.0.0.1" "https://$HEARTH_DOMAIN/.well-known/openid-configuration")"
jq -e --arg issuer "https://$HEARTH_DOMAIN" '.issuer == $issuer' <<< "$d" >/dev/null
printf 'commit=%s\ndeployed_at=%s\n---\n' "$c" "$(date -u +%FT%TZ)" >> "$state/deploy-history"
chown ubuntu:ubuntu "$state/deploy-history"
chmod 0600 "$state/deploy-history"
rm -f "$HEARTH_JAR" "$HEARTH_SOURCE"
printf 'Hearth native staging deployed %s\n' "$c"
REMOTE
