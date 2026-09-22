#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="${HEARTH_CHECK_ROOT:-$(cd "${script_dir}/.." && pwd -P)}"

if [[ ! -d "$project_root" ]]; then
  printf 'Hearth naming check root does not exist: %s\n' "$project_root" >&2
  exit 1
fi

mapfile -t files < <(
  cd "$project_root"
  rg --files --hidden \
    -g '!.git/**' \
    -g '!docs/**' \
    -g '!target/**' \
    -g '!node_modules/**' \
    -g '!.worktrees/**' \
    -g '!.idea/**' \
    -g '!scripts/check-hearth-naming.sh' \
    -g '!scripts/test-hearth-naming.sh' \
    -g '!scripts/test-hearth-documentation.sh' \
    -g '!*.md' \
    -g '!*.svg' \
    -g '!*.ico'
)

if ((${#files[@]} == 0)); then
  printf 'Hearth naming check found no runtime files under %s\n' "$project_root" >&2
  exit 1
fi

violations=()
for relative_file in "${files[@]}"; do
  absolute_file="$project_root/$relative_file"
  if matches=$(rg -n -i 'bytedepth|BYTEDEPTH' "$absolute_file" 2>/dev/null); then
    violations+=("$relative_file:$matches")
  fi
done

if ((${#violations[@]} > 0)); then
  printf 'Hearth naming check failed; forbidden bytedepth identifiers remain:\n' >&2
  printf '%s\n' "${violations[@]}" >&2
  exit 1
fi

printf 'Hearth naming check passed for %s\n' "$project_root"
