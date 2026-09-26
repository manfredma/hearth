#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/deploy/lib/staging-import-recovery.sh"

dump_sql=$'CREATE DATABASE /*!32312 IF NOT EXISTS*/ `hearth` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION=\x27N\x27 */;\nUSE `hearth`;\nCREATE TABLE `application` (`id` bigint);'
rewritten_dump="$(hearth_rewrite_staging_dump_schema hearth_recovery_test <<< "$dump_sql")"
expected_dump=$'CREATE DATABASE /*!32312 IF NOT EXISTS*/ `hearth_recovery_test` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION=\x27N\x27 */;\nUSE `hearth_recovery_test`;\nCREATE TABLE `application` (`id` bigint);'
[[ "$rewritten_dump" == "$expected_dump" ]]

[[ "$(hearth_staging_import_state 0 0 0 0)" == fresh ]]
[[ "$(hearth_staging_import_state 1 0 0 0)" == recovery-required ]]
[[ "$(hearth_staging_import_state 1 0 1 0)" == recovery-interrupted ]]
[[ "$(hearth_staging_import_state 1 0 1 1)" == recovery-finalize-marker ]]
[[ "$(hearth_staging_import_state 1 1 1 1)" == imported ]]
[[ "$(hearth_staging_import_state 1 0 1 0 1)" == recovery-resume ]]
[[ "$(hearth_quote_mysql_identifier hearth_recovery_test)" == '`hearth_recovery_test`' ]]
if hearth_quote_mysql_identifier 'hearth` DROP DATABASE hearth' >/dev/null 2>&1; then
  printf 'Recovery accepted an unsafe MySQL identifier.\n' >&2
  exit 1
fi

rename_sql="$(hearth_build_staging_recovery_rename_sql hearth_partial_run_1 hearth_recovery_run_1 $'application\n' $'application\nidentity_credential')"
[[ "$rename_sql" == 'RENAME TABLE `hearth`.`application` TO `hearth_partial_run_1`.`application`, `hearth_recovery_run_1`.`application` TO `hearth`.`application`, `hearth_recovery_run_1`.`identity_credential` TO `hearth`.`identity_credential`;' ]]
if hearth_build_staging_recovery_rename_sql hearth_partial_run_1 hearth_recovery_run_1 '' '' >/dev/null 2>&1; then
  printf 'Recovery accepted an empty validated source schema.\n' >&2
  exit 1
fi
if hearth_build_staging_recovery_rename_sql hearth_partial_run_1 hearth_recovery_run_1 $'bad`name' application >/dev/null 2>&1; then
  printf 'Recovery accepted an unsafe table identifier.\n' >&2
  exit 1
fi
printf 'Hearth staging import recovery tests passed.\n'
