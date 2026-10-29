# 发布管理

Hearth 的构建、staging/production 发布、日志、验收、重试和回滚完全由 canonical release-platform 管理。项目不创建发布 Tag，不 SSH 或执行旧部署入口。

首次提交 PR 前，必须把本次用户可见、运行时或配置变化记录到非空分类 `## Unreleased`。创建正式平台候选前，再执行本地版本准备：

```bash
python3 scripts/prepare-release.py --version v0.1.3
bash scripts/run-local-quality.sh
```

该脚本只把 Unreleased 内容冻结为 `## [0.1.3] - YYYY-MM-DD`，不提交、打 Tag 或联系服务器。使用本次实际目标 SemVer；重复版本、空变更与非法分类会失败。将准备结果提交到同一 PR，再核对 worktree HEAD 与 GitHub PR head 的完整 SHA。平台要求冻结后 Unreleased 为空，本地门禁同时接受开发中的非空分类或紧随空 Unreleased 的非空分类正式版本，拒绝空变更。

统一顺序：`PR head SHA → QUALITY/BUILD → staging → integration/E2E → 业务验收 → 平台合并同一 SHA → 同一制品 production`。具体操作以 [平台发布流程](../engineering/unified-release-pipeline.md)及 canonical Agent 手册为准。发布成功依据是平台候选、制品、任务及审计回执，不能把本地测试当作 staging 验收。
