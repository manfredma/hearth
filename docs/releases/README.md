# 发布管理

`CHANGELOG.md` 是 Hearth 的变更记录；所有用户可见、运行时、部署或配置改动，在首次 staging 前必须有非空且分类明确的 `## Unreleased` 条目。

## 不可变规则

1. 生产只能部署新的 annotated SemVer Tag：`vMAJOR.MINOR.PATCH`。
2. 不得部署 `main`、分支、裸 commit 或已部署过的 Tag。
3. Tag 指向的提交必须与 staging 验收候选及 fast-forward 后的 main HEAD 完整 SHA 一致；仅在 main 历史中不是放行条件。
4. 创建 Tag 前工作区必须干净，Maven release 事务残留必须清理。
5. 发布失败时保留原 Tag；修复后创建新的 PATCH 版本，不移动或复用旧 Tag。
6. staging 部署前冻结候选版本与 Changelog，拒绝 main（包括同 SHA 别名）和未修改 Changelog 的候选；验收后不得追加提交。生产比较上一个 annotated SemVer 发布的 Changelog（首次发布比较仓库初始提交），并保留非空分类 Unreleased 门禁。

## 发布前检查

```bash
bash scripts/run-local-quality.sh
bash scripts/check-staging-checklist.sh
```

staging 部署、集成测试、E2E、生产发布和回滚的唯一操作说明见 [`deploy/README.md`](../../deploy/README.md)。没有 staging 的完整验收证据，不得创建生产 Tag。
