# Git 工作流

Hearth 使用 GitHub Flow：`main` 只用于集成和受控发布，开发必须在独立 worktree 的 `feat/*`、`fix/*` 或 `docs/*` 分支完成。

## 固定流程

1. 从最新 `main` 创建 worktree 和短生命周期分支。
2. 先写测试，再实现；所有生产 Java 业务分支达到 100% 变更覆盖率。
3. 更新 `docs/releases/CHANGELOG.md` 的 `## Unreleased`，运行 `bash scripts/run-local-quality.sh`。
4. 涉及页面、交互、布局或运行时的改动部署 staging，完成集成测试、E2E 和项目所有者验收。
5. 验收通过后通过 PR 合并 `main`；合并后的 worktree 和已合并分支立即清理。
6. 仅从干净的 `main` 创建新的 annotated SemVer Tag，再按部署手册发布。

## 常用命令

```bash
git worktree add ../hearth-feature -b feat/<topic> main
cd ../hearth-feature
npm ci --ignore-scripts --no-audit --no-fund
bash scripts/run-local-quality.sh
```

禁止在 `main` 直接开发、提交或发布分支/裸 commit。staging 和生产的具体主机操作以 [`deploy/README.md`](../../deploy/README.md) 为准。
