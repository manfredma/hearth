# Hearth 数据库表结构

唯一权威来源是 `hearth-start/src/main/resources/db/migration/` 下的 Flyway 迁移。当前结构由 V1–V4 共同构成：V1 建身份与应用表，V2 增加 Hearth 本地登录凭据，V3 增加 Spring Authorization Server 持久化表，V4 清理由旧认证主体格式生成的临时授权记录。

| 表 | 作用 | 关键约束 |
| --- | --- | --- |
| `user_identity` | Hearth 身份目录 | `(issuer, subject)` 唯一；`subject` 是外部身份稳定标识。 |
| `application` | 已登记的业务应用 | `application_key` 唯一；回调地址必须是 HTTPS，localhost 开发地址可用 HTTP。 |
| `application_redirect_uri` | 应用允许的 OAuth 回调地址 | `(application_id, redirect_uri)` 唯一；不保存 client secret。 |
| `application_access` | 用户到应用的访问授予 | `(user_id, application_id)` 唯一；`role_key` 只作为应用侧能力提示。 |
| `audit_event` | 身份和接入操作审计 | 只保存操作摘要，不保存令牌、密码或 Cookie 原文。 |
| `identity_credential` | Hearth 本地登录凭据 | 每个登录名唯一；只保存密码哈希、启用状态和失败锁定信息，不保存明文密码。 |
| `oauth2_registered_client` | OIDC/OAuth Client 注册 | 保存编码后的 Client Secret、授权方式、回调 URI、scope 和 token 配置。 |
| `oauth2_authorization` | 授权码及 Token 状态 | 保存授权流程和 token 序列化字段；敏感值由协议框架处理。 |
| `oauth2_authorization_consent` | 用户对 Client 的 Consent | 以 Client 与主体为键保存已同意的 authority。 |

用户的业务资料、业务角色和资源关系属于业务系统，不应写入这些表。`application_access.role_key` 是应用命名空间下的访问提示，不是 Hearth 管理员角色，也不是业务资源授权。迁移结构变化必须同时更新迁移测试与本文。
