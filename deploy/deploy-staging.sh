#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 || -z "${1:-}" ]]; then
    printf 'Usage: %s <candidate-branch-or-tag>\n' "$0" >&2
    exit 2
fi

readonly REF="$1"
if [[ ! "$REF" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    printf 'Refusing unsafe candidate ref.\n' >&2
    exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
    readonly STAGING_HOST="${HEARTH_STAGING_HOST:-124.221.143.25}"
    readonly SSH_KEY="${HEARTH_SSH_KEY:-$HOME/.ssh/ubuntu_2.pem}"
    readonly SSH_KNOWN_HOSTS="${HEARTH_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
    if [[ ! -r "$SSH_KEY" ]]; then
        printf 'HEARTH_SSH_KEY is missing or unreadable: %s\n' "$SSH_KEY" >&2
        exit 1
    fi
    if [[ ! -r "$SSH_KNOWN_HOSTS" ]]; then
        printf 'HEARTH_SSH_KNOWN_HOSTS is missing or unreadable: %s\n' "$SSH_KNOWN_HOSTS" >&2
        exit 1
    fi
    exec ssh -i "$SSH_KEY" -o BatchMode=yes \
        -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" -o StrictHostKeyChecking=yes \
        "ubuntu@$STAGING_HOST" "sudo /opt/hearth/deploy/deploy-staging.sh '$REF'"
fi

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly REPOSITORY_URL="${HEARTH_REPOSITORY_URL:-git@github.com:manfredma/hearth.git}"
readonly STAGING_DOMAIN="staging-hearth.bytedepth.cn"
readonly COMPOSE_PROJECT="hearth-staging"
readonly ENV_FILE="$SOURCE_ROOT/deploy/.env"
readonly LOG_FILE="/var/log/hearth-staging-deploy.log"
readonly MAVEN_CACHE_DIR="${HEARTH_MAVEN_CACHE_DIR:-/opt/shared-maven/repository}"
readonly MAVEN_CACHE_LOCK="${HEARTH_MAVEN_CACHE_LOCK:-/opt/shared-maven/repository.lock}"
readonly MAVEN_IMAGE="${HEARTH_MAVEN_IMAGE:-maven:3.9.11-eclipse-temurin-25}"
readonly COMPOSE=(docker compose --project-name "$COMPOSE_PROJECT" --env-file "$ENV_FILE" \
    -f "$SOURCE_ROOT/deploy/docker-compose.single-host.yml" \
    -f "$SOURCE_ROOT/deploy/docker-compose.staging.yml")

if [[ ! -d "$SOURCE_ROOT/.git" ]]; then
    printf 'Refusing: source root is not a Git checkout: %s\n' "$SOURCE_ROOT" >&2
    exit 1
fi
if [[ ! -r "$ENV_FILE" ]]; then
    printf 'Refusing: staging env file is missing: %s\n' "$ENV_FILE" >&2
    exit 1
fi
if grep -Eq 'replace-with|inject-at-deploy-time|base64-pkcs8-rsa-private-key' "$ENV_FILE"; then
    printf 'Refusing: staging env file still contains a placeholder.\n' >&2
    exit 1
fi

cd "$SOURCE_ROOT"
git remote set-url origin "$REPOSITORY_URL"
git fetch --force --no-recurse-submodules origin "$REF"
readonly COMMIT="$(git rev-parse FETCH_HEAD^{commit})"
# Keep the host checkout on a named deployment branch so Git does not emit a
# detached-HEAD advice message during an otherwise successful rollout.
git checkout --quiet -B hearth-staging-deploy "$COMMIT"
export HEARTH_COMMIT_ID="$COMMIT"
export HEARTH_BUILT_AT="$(date -u +%FT%TZ)"

if ! docker network inspect bytedepth_default >/dev/null 2>&1; then
    printf 'Refusing: shared bytedepth_default network is missing.\n' >&2
    exit 1
fi

prepare_maven_cache() {
    install -d -o root -g root -m 0755 "$MAVEN_CACHE_DIR"
    (
        flock -x 8
        local maven_log
        maven_log="$(mktemp)"
        trap 'rm -f "$maven_log"' RETURN
        set +e
        docker run --rm --network host \
            -v "$SOURCE_ROOT:/workspace" \
            -v "$MAVEN_CACHE_DIR:/root/.m2/repository" \
            -w /workspace "$MAVEN_IMAGE" \
            ./mvnw -B clean install -DskipTests -Dsort.skip=true 2>&1 | tee "$maven_log"
        local maven_status="${PIPESTATUS[0]}"
        set -e
        if [[ "$maven_status" -ne 0 ]]; then
            printf 'Maven dependency prewarm failed; see %s\n' "$LOG_FILE" >&2
            return "$maven_status"
        fi
        if ! warning_policy_check_file "$maven_log"; then
            printf 'Maven dependency prewarm emitted an unallowlisted warning.\n' >&2
            return 1
        fi
    ) 8>"$MAVEN_CACHE_LOCK" >>"$LOG_FILE" 2>&1
}

install -d -m 0700 "$(dirname "$LOG_FILE")"
source "$SOURCE_ROOT/deploy/lib/warning-policy.sh"
if ! prepare_maven_cache; then
    printf 'Hearth staging Maven cache preparation failed; see %s\n' "$LOG_FILE" >&2
    exit 1
fi

set +e
"${COMPOSE[@]}" config --quiet >"$LOG_FILE" 2>&1
config_status=$?
set -e
if [[ "$config_status" -ne 0 ]]; then
    printf 'Compose configuration failed; see %s\n' "$LOG_FILE" >&2
    exit "$config_status"
fi

set +e
"${COMPOSE[@]}" up -d --build --force-recreate >>"$LOG_FILE" 2>&1
rollout_status=$?
set -e
if [[ "$rollout_status" -ne 0 ]]; then
    printf 'Hearth staging rollout failed; see %s\n' "$LOG_FILE" >&2
    exit "$rollout_status"
fi

for attempt in {1..60}; do
    if curl --fail --silent --show-error --max-time 5 http://127.0.0.1:18083/api/health >/dev/null; then
        break
    fi
    if [[ "$attempt" -eq 60 ]]; then
        printf 'Hearth staging health check timed out; see %s\n' "$LOG_FILE" >&2
        exit 1
    fi
    sleep 2
done

if ! curl --fail --silent --show-error --max-time 10 \
    --resolve "$STAGING_DOMAIN:443:127.0.0.1" "https://$STAGING_DOMAIN/.well-known/openid-configuration" \
    -o /dev/null; then
    printf 'Hearth staging HTTPS discovery check failed; see %s\n' "$LOG_FILE" >&2
    exit 1
fi

printf 'Hearth staging deployed ref=%s commit=%s\n' "$REF" "$COMMIT"
