# ADR-0012：OAuth 持久化使用框架标准安全主体

- 状态：Accepted
- 日期：2026-09-24

## 背景

Spring Authorization Server 会把当前 `Authentication` 写入
`oauth2_authorization.attributes`。Spring Security 7 的 Jackson 多态类型校验只允许框架已知的安全主体类型。Hearth 原先把包含用户资料的 `HearthPrincipal` 写入登录会话，授权确认提交时读取该授权记录会因类型不在 allow-list 中而返回 HTTP 403。

## 决策

本地密码登录和 Remember-Me 恢复统一使用 Spring Security 的 `User` 作为安全主体，只在主体中保留登录名和必要的认证信息。显示名、邮箱和稳定用户 ID 通过 Hearth 的服务端身份目录按登录名解析。OIDC Token 的 `sub` 仍使用身份目录中的稳定用户 ID。

旧 Redis 会话在进入安全过滤链时转换为标准 `User`；数据库迁移删除已经写入旧主体的临时 OAuth 授权记录，但保留用户的 consent 授权记录。

## 结果

- OAuth 授权码流程可以被 Spring Authorization Server 的 JDBC 服务安全地读写。
- 用户资料不会复制到 OAuth 序列化主体中，资料变更无需强制刷新会话。
- 一次性迁移会使已有的进行中授权失效，客户端需要重新发起登录授权；这不会删除 Hearth 身份或 consent 数据。
- `HearthPrincipal` 暂时保留用于兼容旧会话和旧序列化数据的迁移边界，不再用于创建新的认证主体。
