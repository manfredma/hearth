# Hearth 发布流程

Hearth 将无凭据的本机质量门禁与 staging/生产受控操作分离。任何构建、测试、部署或发布输出出现 `WARNING`/`WARN`，都必须停止并处理。

## 顺序

```text
独立 worktree
  → 单元测试与本机质量门禁
  → staging 部署、集成测试、E2E 与验收
  → PR 合并 main
  → 创建新的 annotated SemVer Tag
  → 发布该 Tag 并做生产验收
```

staging 是唯一的跨进程验收环境；本机不能替代 MySQL、Redis、Flyway、OIDC 或浏览器验收。生产只接受新的不可变 Tag，不接受 `main`、分支或裸 commit。

发布前必须满足：

- `CHANGELOG.md` 有非空、分类明确的 `## Unreleased` 或对应版本条目。
- Java 变更覆盖率、前端测试/lint、PMD 和配置契约全部通过。
- staging 集成与 E2E 证据绑定待发布提交的完整 SHA。
- compose 完整重建并启动，不能只更新单个服务。

具体命令、凭据注入、环境隔离和回滚规则只写在 [`deploy/README.md`](../../deploy/README.md) 与版本说明中。
