# Hearth 数据库表结构

唯一权威来源是 `hearth-start/src/main/resources/db/migration/` 下的 Flyway 迁移。当前 V1 不保存密码哈希。

| 表 | 作用 | 关键约束 |
| --- | --- | --- |
| `user_identity` | Hearth 身份目录 | `(issuer, subject)` 唯一；`subject` 是外部身份稳定标识。 |
| `application` | 已登记的业务应用 | `application_key` 唯一；回调地址必须是 HTTPS，localhost 开发地址可用 HTTP。 |
| `application_redirect_uri` | 应用允许的 OAuth 回调地址 | `(application_id, redirect_uri)` 唯一；不保存 client secret。 |
| `application_access` | 用户到应用的访问授予 | `(user_id, application_id)` 唯一；`role_key` 只作为应用侧能力提示。 |
| `audit_event` | 身份和接入操作审计 | 只保存操作摘要，不保存令牌、密码或 Cookie 原文。 |

用户的业务资料、业务角色和资源关系属于业务系统，不应写入这些表。迁移结构变化必须同时更新迁移测试与本文。
