# ADR-0006: Hearth 自建 OIDC Provider，使用协议框架作为内核

- **状态**: Accepted
- **日期**: 2026-09-23
- **决策者**: 项目所有者

## 上下文

Hearth 的目标不是把登录页面转发给 Keycloak、ZITADEL 或云身份服务，而是练习并掌握 OAuth 2.0/OIDC 的实现，同时保留用户模型、登录流程、应用接入和审计的定制能力。直接依赖外部身份服务会增加独立组件和供应商能力边界；从零手写协议、Token 签名和密钥管理又会扩大不可接受的安全风险。

## 决策

Hearth 自己运行并对业务系统提供 OIDC Provider。业务系统只信任 Hearth 的 `issuer`，不接入外部身份提供商。Hearth 使用 Spring Authorization Server 作为进程内协议实现，使用 Spring Security 的密码、Session、CSRF 和请求安全能力；协议框架只存在于 adapter 层，领域层和应用层不依赖框架类型。

第一阶段只实现单租户、用户名/邮箱密码登录、Authorization Code + PKCE、OIDC Discovery、ID Token、Access Token、Refresh Token、JWKS、RP-Initiated Logout、应用 Client 注册、应用访问和基础审计。MFA、社交登录、LDAP、多租户、Device Authorization 和动态 Client 注册不属于第一阶段。

## 责任边界

| 能力 | Hearth | 业务系统 |
| --- | --- | --- |
| 用户身份、密码、登录 Session | 负责 | 不重复实现 |
| OIDC/OAuth 端点和 Token | 负责 | 作为 OIDC Client |
| 应用 Client、Redirect URI、Scope | 负责 | 提供接入申请和业务声明 |
| 应用访问关系 | 负责粗粒度授予 | 负责最终业务授权 |
| 日记、文章、候选人等资源权限 | 不负责 | 负责 |
| 领域角色、审批、数据权限 | 不负责 | 负责 |

## 后果

**正向**

- Hearth 成为真正的统一身份入口，不是外部 Provider 的展示层。
- 用户、应用、Session、审计和协议端点在一个可维护的产品边界内。
- 未来可以替换 Spring Authorization Server，而不改变 Hearth 的领域模型和业务系统接入契约。
- 不需要部署和维护独立的 Keycloak/ZITADEL 服务。

**负向**

- Hearth 自己承担密码安全、账户生命周期、密钥轮换、备份和恢复责任。
- 认证系统比普通业务后台更高风险，必须有严格的安全测试、审计和 staging 验收。
- Spring Authorization Server 只解决协议实现，不自动提供完整的用户管理、MFA、邮件找回和运维能力。

## 不可违反的安全约束

- 不自行实现密码学算法；签名、哈希、随机数和 Token 编解码使用成熟库。
- 只允许 Authorization Code + PKCE；禁止 Implicit Grant。
- `issuer` 必须稳定、使用 HTTPS，并与 Discovery、Token 的 `iss` 和 JWKS 配置一致。
- `issuer + subject` 是跨应用稳定身份键；邮箱和用户名不能自动合并账号。
- Client Secret、Session、Refresh Token、私钥和密码哈希不得写入浏览器 localStorage 或仓库。
- staging 与 production 使用独立数据库、Session namespace、OIDC issuer、Client 和签名密钥。

## 重评信号

| 信号 | 预设行动 |
| --- | --- |
| 需要多租户、企业联邦、复杂 MFA 或高可用集群 | 重新评估独立成熟身份平台，并保留业务系统的 Hearth issuer 契约 |
| Spring Authorization Server 无法满足协议或安全要求 | 评估其他协议内核；不直接复制协议实现 |
| 安全审计发现无法在 Hearth 内可靠修复的缺陷 | 暂停生产接入，进入独立身份平台迁移评估 |
