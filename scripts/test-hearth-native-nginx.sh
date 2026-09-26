#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -Fq 'server_name staging-hearth.bytedepth.cn' "$ROOT/deploy/nginx/hearth-native-staging.conf.template"
grep -Fq '127.0.0.1:18111' "$ROOT/deploy/nginx/hearth-native-staging.conf.template"
grep -Fq 'server_name hearth.bytedepth.cn' "$ROOT/deploy/nginx/hearth-native-production.conf.template"
grep -Fq '127.0.0.1:18113' "$ROOT/deploy/nginx/hearth-native-production.conf.template"
grep -Fq '/etc/hearth/staging-tls/current/fullchain.pem' "$ROOT/deploy/nginx/hearth-native-staging.conf.template"
grep -Fq '/etc/hearth/staging-tls/current/privkey.pem' "$ROOT/deploy/nginx/hearth-native-staging.conf.template"
grep -Fq '/data/hearth-native-production/letsencrypt/live/hearth.bytedepth.cn/fullchain.pem' "$ROOT/deploy/nginx/hearth-native-production.conf.template"
grep -Fq '/data/hearth-native-production/acme-webroot' "$ROOT/deploy/nginx/hearth-native-production.conf.template"
printf 'Hearth native Nginx contract passed.\n'
