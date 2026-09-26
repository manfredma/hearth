#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -Fqx '# Hearth' "$SOURCE_ROOT/AGENTS.md"
for decision in 0001-unified-identity-and-authorization-boundary 0002-oidc-oauth2-application-integration 0003-use-mature-identity-provider 0004-isolated-identity-environments-and-stable-subject 0006-self-hosted-oidc-provider 0007-mysql-identity-lookup-indexes; do
  grep -Fq "${decision}.md" "$SOURCE_ROOT/docs/architecture/decisions/README.md"
done
grep -Fqx '## Unreleased' "$SOURCE_ROOT/docs/releases/CHANGELOG.md"
grep -Fqx '### Added' "$SOURCE_ROOT/docs/releases/CHANGELOG.md"
grep -Fqx '### Security' "$SOURCE_ROOT/docs/releases/CHANGELOG.md"
test -s "$SOURCE_ROOT/docs/security/authentication.md"
test -s "$SOURCE_ROOT/docs/security/application-access.md"
grep -Fq 'localStorage' "$SOURCE_ROOT/AGENTS.md"
grep -Fq 'localStorage' "$SOURCE_ROOT/docs/security/authentication.md" || true
if rg -n 'bytedepth-start|BYTEDEPTH_' "$SOURCE_ROOT/deploy" "$SOURCE_ROOT/Dockerfile"; then
  printf 'Operational Hearth files contain stale template identifiers.\n' >&2
  exit 1
fi
if rg -n 'public final class .*Repository' "$SOURCE_ROOT/hearth-infrastructure/src/main/java"; then
  printf 'Spring @Repository implementations must remain proxyable (not final).\n' >&2
  exit 1
fi
printf 'Hearth documentation contract passed.\n'
