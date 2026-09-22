# 架构决策记录（ADR）

本目录记录 Hearth 的架构决策，随 Git 历史和对应 PR 一起评审。Hearth 使用 bytedepth 的工程规范和知识库结构作为模板，但身份领域的决策以本目录为准。

## 编号与状态

- 编号递增：`ADR-0001`、`ADR-0002`……；文件名为 `NNNN-kebab-title.md`。
- 从 [0000-template.md](0000-template.md) 创建新记录。
- 状态为 **Proposed**、**Accepted**、**Deprecated** 或 **Superseded**。替代既有决策时保留旧 ADR，并互相链接以维持可追溯性。

## 流程

1. 写设计 spec 前，先判断决策是否影响模块边界、外部接口或长期约束，或是否存在不易回退的方案取舍。
2. 项目所有者确认是否需要 ADR。
3. 需要时，先写 ADR，再写 spec；ADR 随同实现 PR 评审，不得事后补录。

小改动可只在提交信息和 PR 描述中说明。

## Hearth 决策索引

| 编号 | 标题 | 状态 | 日期 |
|------|------|------|------|
| [ADR-0001](0001-unified-identity-and-authorization-boundary.md) | 统一身份认证与业务授权边界 | Proposed | 2026-09-22 |
| [ADR-0002](0002-oidc-oauth2-application-integration.md) | 使用 OIDC 与 OAuth 2.0 接入业务应用 | Proposed | 2026-09-22 |
| [ADR-0003](0003-use-mature-identity-provider.md) | 认证协议核心采用成熟身份提供商 | Proposed | 2026-09-22 |
| [ADR-0004](0004-isolated-identity-environments-and-stable-subject.md) | 隔离 staging 与生产身份环境并使用稳定 subject | Proposed | 2026-09-22 |

## 模板继承记录

从 bytedepth 模板导入的通用工程、质量和发布文档仍保留在仓库中；博客领域专属 ADR 在 Hearth 完成领域清理时移除或重新评估，不作为 Hearth 身份领域决策的依据。
