#!/usr/bin/env bash

hearth_staging_import_state() {
  [[ $# -eq 4 && "$1" =~ ^[01]$ && "$2" =~ ^[01]$ \
    && "$3" =~ ^[01]$ && "$4" =~ ^[01]$ ]] || return 2
  if [[ "$2" == 1 ]]; then
    printf 'imported\n'
  elif [[ "$4" == 1 ]]; then
    printf 'recovery-finalize-marker\n'
  elif [[ "$3" == 1 ]]; then
    printf 'recovery-interrupted\n'
  elif [[ "$1" == 1 ]]; then
    printf 'recovery-required\n'
  else
    printf 'fresh\n'
  fi
}

hearth_rewrite_staging_dump_schema() {
  [[ $# -eq 1 && "$1" =~ ^hearth_recovery_[a-z0-9_]+$ ]] || return 2
  sed -E \
    -e "s/^CREATE DATABASE (.*) \`hearth\` (.*);$/CREATE DATABASE \\1 \`$1\` \\2;/" \
    -e "s/^USE \`hearth\`;/USE \`$1\`;/"
}

hearth_build_staging_recovery_rename_sql() {
  [[ $# -eq 4 ]] || return 2
  local backup_database="$1" recovery_database="$2"
  local partial_tables="$3" recovery_tables="$4"
  [[ "$backup_database" =~ ^hearth_partial_[a-z0-9_]+$ \
    && "$recovery_database" =~ ^hearth_recovery_[a-z0-9_]+$ ]] || return 2
  local sql='RENAME TABLE ' separator='' table
  local recovery_count=0
  local -a partial_table_names=() recovery_table_names=()
  while IFS= read -r table; do
    [[ -n "$table" ]] || continue
    [[ "$table" =~ ^[a-z0-9_]+$ ]] || return 2
    partial_table_names+=("$table")
  done <<< "$partial_tables"
  while IFS= read -r table; do
    [[ -n "$table" ]] || continue
    [[ "$table" =~ ^[a-z0-9_]+$ ]] || return 2
    recovery_table_names+=("$table")
  done <<< "$recovery_tables"
  recovery_count="${#recovery_table_names[@]}"
  (( recovery_count > 0 )) || { printf 'Recovery schema contains no tables.\n' >&2; return 1; }
  for table in "${partial_table_names[@]}"; do
    sql+="$separator\`hearth\`.\`$table\` TO \`$backup_database\`.\`$table\`"
    separator=', '
  done
  for table in "${recovery_table_names[@]}"; do
    sql+="$separator\`$recovery_database\`.\`$table\` TO \`hearth\`.\`$table\`"
    separator=', '
  done
  printf '%s;\n' "$sql"
}
