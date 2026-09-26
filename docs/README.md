# Hearth 项目知识库

这里记录 Hearth 的当前架构、身份安全边界、工程约束、技术债、发布记录和可复现的设计决策。入口只保留稳定结论，具体实现按链接渐进式展开。

## 从这里开始

- 架构和模块边界：[架构概览](architecture/overview.md)
- 领域术语：[统一语言](architecture/ubiquitous-language.md)
- 数据库模型：[数据库表结构](architecture/database-schema.md)
- 路由和 API：[路由一览](architecture/routes.md)
- 前端视觉与布局：[前端设计语言](architecture/frontend-design-language.md)、[管理端布局](architecture/admin-layout.md)
- 认证与会话：[认证说明](security/authentication.md)、[CSRF 与 Session](security/csrf-session-repository.md)
- 应用访问与授权边界：[应用访问模型](security/application-access.md)、[权限边界](security/rbac.md)
- 架构决策：[ADR 索引](architecture/decisions/README.md)
- 产品后续事项：[MVP Backlog](backlog.md)
- 已确认的工程债务：[技术债清单](engineering/technical-debt.md)
- 构建与测试：[Maven 指南](agent-guides/maven.md)、[代码质量](agent-guides/code-quality.md)
- Git、staging 与发布：[Git 工作流](engineering/git-workflow.md)、[统一发布流程](engineering/unified-release-pipeline.md)、[发布记录](releases/README.md)
- 部署和环境隔离：只读 [部署手册](../deploy/README.md)

## 目录边界

| 目录 | 内容 |
| --- | --- |
| `architecture/` | 模块、领域、数据、路由和前端设计约束。 |
| `engineering/` | 可复现的开发、测试、发布和故障处理规则。 |
| `security/` | OIDC、Session、CSRF、应用访问和运维安全边界。 |
| `releases/` | 版本策略和变更记录。 |
| `superpowers/` | 设计与实施历史记录；历史计划中的勾选项和旧环境命令不是当前待办或发布入口。当前架构、运行规则和部署步骤以 ADR、工程指南和 `deploy/README.md` 为准。 |

## 维护原则

架构决策、长期约束和故障复盘随代码一起提交；不写入 agent 私有记忆，不提交密钥、真实账号或机器私有部署日志。模板继承的通用规则必须经过 Hearth 语义审查，不能保留已经失效的博客领域事实。
