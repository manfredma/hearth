# 架构决策记录（ADR）

本目录记录 Hearth 的架构决策，随 Git 历史和对应 PR 一起评审。项目沿用成熟的工程规范和知识库结构，但身份领域的决策以本目录为准。

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
| [ADR-0001](0001-unified-identity-and-authorization-boundary.md) | 统一身份认证与业务授权边界 | Accepted | 2026-09-22 |
| [ADR-0002](0002-oidc-oauth2-application-integration.md) | 使用 OIDC 与 OAuth 2.0 接入业务应用 | Accepted | 2026-09-22 |
| [ADR-0003](0003-use-mature-identity-provider.md) | 认证协议核心采用成熟身份提供商 | Superseded | 2026-09-22 |
| [ADR-0004](0004-isolated-identity-environments-and-stable-subject.md) | 隔离 staging 与生产身份环境并使用稳定 subject | Accepted | 2026-09-22 |
| [ADR-0006](0006-self-hosted-oidc-provider.md) | Hearth 自建 OIDC Provider，使用协议框架作为内核 | Accepted | 2026-09-23 |
| [ADR-0007](0007-mysql-identity-lookup-indexes.md) | MySQL 身份键保留原文并使用哈希联合唯一索引 | Accepted | 2026-09-23 |
| [ADR-0008](0008-application-user-provisioning-and-identity-mapping.md) | 业务应用按稳定 subject 建立本地用户映射 | Accepted | 2026-09-23 |
| [ADR-0009](0009-central-sso-session-and-logout.md) | Hearth 管理统一 SSO Session、记住登录与统一退出 | Accepted | 2026-09-23 |
| [ADR-0010](0010-business-applications-do-not-provide-login-route.md) | 业务应用不提供自有登录入口 | Accepted | 2026-09-23 |
| [ADR-0011](0011-persistent-login-credentials.md) | 使用签名 Cookie 实现 Hearth 30 天免登录 | Accepted | 2026-09-23 |
| [ADR-0012](0012-framework-principal-for-oauth-persistence.md) | OAuth 持久化使用框架标准安全主体 | Accepted | 2026-09-24 |
| [ADR-0013](0013-agent-validation-and-owner-acceptance-boundary.md) | Agent 技术验收与项目所有者最终验收的职责边界 | Accepted | 2026-09-24 |
| [ADR-0014](0014-native-shared-host-deployment.md) | Hearth 复用共享宿主机 native 基础设施 | Proposed | 2026-09-26 |

## 维护边界

ADR 只记录 Hearth 的长期架构事实，不记录临时部署日志、个人记忆或业务应用内部权限规则。已经不适用于 Hearth 的模板内容应删除或重写，而不是继续作为隐含约束。
