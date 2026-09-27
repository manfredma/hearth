#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/scripts/lib" "$tmp/deploy/lib" "$tmp/docs/releases"
cp "$ROOT/scripts/check-release-readiness.sh" "$tmp/scripts/"
cp "$ROOT/scripts/lib/"*.sh "$tmp/scripts/lib/"
cp "$ROOT/deploy/lib/"*.sh "$tmp/deploy/lib/"
printf '#!/bin/bash\nexit 0\n' > "$tmp/scripts/check-hearth-naming.sh"
cd "$tmp"
git init -q -b main
git config user.email fixture@example.test
git config user.name Fixture
git config commit.gpgsign false
git config tag.gpgsign false
printf '# Changelog\n\n## Unreleased\n\n### Fixed\n\n- Baseline.\n' > docs/releases/CHANGELOG.md
git add .
git commit -qm baseline
git update-ref refs/remotes/origin/main HEAD
git checkout -qb fix/candidate
reject() { if bash scripts/check-release-readiness.sh "$@" > "$tmp/result" 2>&1; then printf 'Unsafe release accepted: %s\n' "$*" >&2; exit 1; fi; }
printf '## Unreleased\n### Fixed\n' > docs/releases/CHANGELOG.md
reject
printf '## Unreleased\n### Whatever\n- Invalid category.\n' > docs/releases/CHANGELOG.md
reject
printf '## Unreleased\n### Fixed\n- Candidate fix.\n' > docs/releases/CHANGELOG.md
bash scripts/check-release-readiness.sh > /dev/null
reject --candidate main
reject --candidate origin/main
reject --candidate "$(git rev-parse main)"
reject --candidate fix/candidate
git add docs/releases/CHANGELOG.md
git commit -qm candidate
bash scripts/check-release-readiness.sh --candidate fix/candidate > /dev/null
git tag v1.0.0
reject --production v1.0.0
git tag -a v1.0.1 -m release
reject --production v1.0.1
git update-ref refs/remotes/origin/main HEAD
bash scripts/check-release-readiness.sh --production v1.0.1 > /dev/null
printf other > other
git add other
git commit -qm newer
git update-ref refs/remotes/origin/main HEAD
reject --production v1.0.1
printf 'Hearth release readiness tests passed.\n'
