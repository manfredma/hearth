#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SOURCE_ROOT/scripts/lib/java-25.sh"
cd "$SOURCE_ROOT"
changelog=docs/releases/CHANGELOG.md
check_changelog() {
  awk '
    /^## Unreleased$/ {inside=1; sections++; next}
    /^## / {inside=0}
    inside && /^### / {category=($0 ~ /^### (Added|Changed|Deprecated|Removed|Fixed|Security)$/); next}
    inside && /^[*-][[:space:]]+[^[:space:]]/ {if (!category) invalid=1; else entries++}
    END {exit(sections == 1 && entries > 0 && !invalid ? 0 : 1)}
  '
}
if [[ $# -eq 0 ]]; then
  check_changelog < "$changelog"
  base="$(git merge-base origin/main HEAD)"
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
    ! git diff --quiet "$base" -- "$changelog" || { printf 'Candidate must change Changelog.\n' >&2; exit 1; }
  fi
elif [[ $# -eq 2 && ( "$1" == --candidate || "$1" == --production ) ]]; then
  ref="$2"
  [[ "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || exit 2
  commit="$(git rev-parse --verify "$ref^{commit}")"
  main="$(git rev-parse --verify origin/main^{commit})"
  git show "$commit:$changelog" | check_changelog
  if [[ "$1" == --candidate ]]; then
    [[ "$commit" != "$main" && "$ref" != main && "$ref" != refs/heads/main ]] || { printf 'Staging requires a candidate, not main.\n' >&2; exit 1; }
    base="$(git merge-base "$main" "$commit")"
  else
    [[ "$ref" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ && "$(git cat-file -t "$ref")" == tag ]] || exit 1
    [[ "$commit" == "$main" ]] || { printf 'Production tag must equal the accepted main HEAD.\n' >&2; exit 1; }
    # Compare the first release with the repository baseline, later releases
    # with the previous immutable release, even after the candidate is merged.
    base="$(git rev-list --max-parents=0 "$commit")"
    while IFS= read -r previous; do
      [[ "$previous" != "$ref" && "$previous" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
      [[ "$(git cat-file -t "$previous")" == tag ]] || continue
      base="$(git rev-parse "$previous^{commit}")"
      break
    done < <(git tag --merged "$commit" --sort=-version:refname)
  fi
  ! git diff --quiet "$base" "$commit" -- "$changelog" || { printf 'Candidate must change Changelog.\n' >&2; exit 1; }
else
  printf 'Usage: %s [--candidate ref | --production tag]\n' "$0" >&2
  exit 2
fi
bash "$SOURCE_ROOT/scripts/check-hearth-naming.sh"
printf 'Hearth release readiness contract passed.\n'
