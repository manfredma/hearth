# 发布管理

Hearth 的构建、staging/production 发布、日志、验收、重试和回滚完全由 release-platform 管理。本仓库不创建发布 Tag，不执行项目部署脚本或 SSH。

统一顺序：

`AI Agent 修改并提交 PR → 完整 commit SHA → QUALITY → BUILD → staging → 页面验收 → 同一制品提升 production`

版本和发布记录以 release-platform 的候选、制品、任务和审计记录为准；`CHANGELOG.md` 只记录项目变化。
