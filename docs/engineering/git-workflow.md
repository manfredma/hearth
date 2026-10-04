# Git 工作流

Hearth 使用 GitHub Flow：`main` 只用于集成和受控发布，开发必须在独立 worktree 的 `feat/*`、`fix/*` 或 `docs/*` 分支完成。

## 固定流程

1. 从最新 `main` 创建 worktree 和短生命周期分支。
2. 先写测试，再实现；所有生产 Java 业务分支达到 100% 变更覆盖率。
3. 更新 `docs/releases/CHANGELOG.md` 的 `## Unreleased`，运行 `bash scripts/run-local-quality.sh`。
4. 通过 PR 合并后，将分支/PR 和完整 SHA 交给 release-platform；平台完成 staging、集成测试、E2E 和项目所有者验收。
5. 验收通过后由平台将同一不可变制品提升 production；合并后的 worktree 和分支立即清理。

## 常用命令

```bash
git worktree add ../hearth-feature -b feat/<topic> main
cd ../hearth-feature
npm ci --ignore-scripts --no-audit --no-fund
bash scripts/run-local-quality.sh
```

禁止在 `main` 直接开发、提交或发布分支/裸 commit。发布、日志、重试和回滚只通过 release-platform 页面完成。
