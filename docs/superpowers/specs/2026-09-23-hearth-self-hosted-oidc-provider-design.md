# Hearth 自建 OIDC Provider 设计规格

- **状态**: Proposed
- **日期**: 2026-09-23
- **项目**: Hearth
- **关联 ADR**: [ADR-0006](../../architecture/decisions/0006-self-hosted-oidc-provider.md)

## 1. 目标

将 Hearth 从“接入上游 OIDC Provider 的身份目录”升级为独立运行的轻量 OIDC Provider。Daylilt、Career、Toolbox、Release 和 ByteDepth 等业务系统只信任 Hearth 的 `issuer`，Hearth 自己管理用户、密码、Session、应用 Client、Token、应用访问关系和认证审计。

## 2. 明确边界

### Hearth 负责

- 用户账户、密码哈希、登录失败锁定和账户状态。
- OIDC Discovery、Authorization Code + PKCE、Token、UserInfo、JWKS 和 RP-Initiated Logout。
- Authorization Server 的 Client、Redirect URI、Scope 和 Consent 配置。
- 服务端 Session、Refresh Token、Token 撤销和认证审计。
- 应用访问授予与应用级角色声明。
- React 管理界面和用户可理解的登录/授权交互。

### 业务系统负责

- 作为 OIDC Client 接入 Hearth。
- 使用 `issuer + subject` 映射本地用户。
- 执行自己的功能权限、资源权限、数据权限、审批和领域规则。
- 不把 Hearth 的应用级角色声明当作资源授权的唯一依据。

## 3. 认证流程

```text
业务系统
  → /oauth2/authorize?client_id=...&code_challenge=...
  → Hearth 登录页
  → Hearth 校验用户密码并建立 Session
  → 授权确认页（首次或 scope 变化时）
  → redirect_uri?code=...&state=...
  → 业务系统后端 /oauth2/token
  → Hearth 返回 ID Token + Access Token + 可选 Refresh Token
```

Hearth 的签名密钥通过 JWKS 发布，业务系统通过 Discovery 自动发现端点；`issuer` 必须与 Discovery、ID Token 的 `iss` 和 JWKS 配置严格一致。

## 4. 第一阶段范围

必须实现：

- 单租户用户目录。
- 管理员创建用户、启用/禁用用户和重置密码。
- Argon2id 或 BCrypt 密码哈希，禁止明文和可逆密码。
- Authorization Code + PKCE，拒绝 Implicit Grant。
- OIDC `openid` scope，以及 `profile`、`email` 的最小声明。
- ID Token、Access Token、Refresh Token 的签发和撤销。
- JWKS 密钥发布、双钥轮换和旧钥过渡窗口。
- 预注册 Client 与严格 Redirect URI 匹配。
- 服务端 Session、CSRF、登录限流和认证审计。
- staging/production 独立数据、Session namespace、issuer 和签名密钥。

明确不做：

- 外部身份提供商、社交登录、LDAP/企业联邦。
- 多租户、动态 Client 注册、Device Authorization、复杂 MFA。
- 各业务系统的资源 ACL 和数据权限。

## 5. 技术边界

Spring Authorization Server 只允许出现在 `hearth-adapter` 的协议适配层；`hearth-domain` 和 `hearth-app` 只依赖 Hearth 自己定义的端口和领域类型。MySQL 持久化用户、Client、授权记录、授权码、Refresh Token、密钥元数据和审计事件；Redis 保存短期 Session、登录限流和可撤销的短期状态。

协议框架不是业务模型。业务系统接入契约是标准 OIDC issuer、Discovery、JWKS 和 Authorization Code + PKCE，不暴露 Spring 类型。

## 6. 验收标准

- 新业务系统只配置 Hearth issuer、client_id、redirect_uri 和 scope 即可登录。
- 用户在 Hearth 登录一次后，第二个业务系统可复用 Hearth Session。
- 未登录、密码错误、账户禁用、Redirect URI 不匹配、无效 code、PKCE 不匹配和过期 token 均有明确失败行为。
- 业务系统能验证 ID Token 签名、issuer、audience、nonce、时间窗口和 subject。
- JWKS 轮换期间旧 Token 仍可在过渡窗口验证，过渡结束后旧密钥不可继续签发。
- 浏览器不保存长期 Token 或私人业务数据到 localStorage/sessionStorage。
- staging 与 production 的身份数据和签名密钥无法互相验证。

## 7. 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| 自建认证服务成为高价值攻击目标 | 使用 Spring Security/SAS、最小范围、限流、审计、staging E2E 和安全复核 |
| 协议内核升级导致兼容性变化 | 将 SAS 隔离在 adapter，固定版本并以标准端点契约测试保护 |
| 私钥丢失导致 Token 无法验证 | 密钥元数据持久化、备份与恢复演练；禁止只存在容器文件系统 |
| 业务系统错误使用角色声明 | 在接入文档中明确 Hearth 仅提供应用级访问，业务系统必须二次授权 |
