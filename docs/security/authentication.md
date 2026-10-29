# Hearth 认证与会话

Hearth 自己提供 OIDC，Spring Security 7 Authorization Server 负责协议端点和令牌协议，Redis 存储服务端 Session。业务系统只需要信任 Hearth 的 issuer；浏览器只持有 HttpOnly Session Cookie，不持有访问令牌或身份目录数据。

## 配置

每个环境必须显式设置自己的 `HEARTH_OIDC_ISSUER` 和 `HEARTH_SIGNING_KEY`。Spring 配置属性 `hearth.authorization-server.signing-key-location` 当前通过 `env:HEARTH_SIGNING_KEY` 读取 PKCS#8 RSA 私钥。issuer 必须稳定且在 staging/production 使用 HTTPS；不同环境必须使用独立的数据库、Redis namespace、Client 注册和签名密钥。

## 约束

- Hearth 的本地密码只用于 Hearth 登录，密码只以成熟密码哈希形式存储；业务系统不接收 Hearth 密码。
- Session Cookie 必须在 HTTPS 环境启用 Secure，并设置合适的 SameSite 策略。
- 第一阶段只允许 Authorization Code + PKCE；Refresh Token 不进入浏览器 JavaScript 或浏览器存储。
- OIDC `sub` 使用 Hearth 身份 UUID，`iss` 永远等于当前环境的配置 issuer；业务系统不能用邮箱作为稳定身份键。
- 修改 Session、CSRF 或 OIDC 回调行为时，必须补充适配层测试，并在 staging 做跨进程验收。
- “保持登录 30 天”只由 Hearth 实现：短期 HTTP Session 存 Redis，Remember-Me 使用 Spring Security `TokenBasedRememberMeServices` 生成签名 Cookie；业务应用不得实现或共享 Hearth 的持久 Cookie。
- Hearth 只确认“你是谁”；业务功能权限仍由各业务系统管理。

## 存储职责

- Redis 保存短期 HTTP Session、OIDC 授权过程的临时状态和限流状态，当前 Session 闲置 60 分钟过期；它也让未来的多实例 Hearth 不需要依赖粘性会话。
- MySQL 保存用户、密码哈希和 OAuth/OIDC 授权数据，不保存 Remember-Me Cookie。
- Remember-Me Cookie 自包含用户名、过期时间和 HMAC 签名。Redis Session 过期后，Spring Security 校验 Cookie 并重新建立 Session。

## 30 天免登录

登录页默认不勾选“保持登录 30 天”。勾选后创建 `hearth-remember-me` Cookie，有效期为 30 天。Cookie 使用 `HttpOnly`、HTTPS 环境 `Secure` 和 `SameSite=Lax`，签名密钥由环境变量 `HEARTH_REMEMBER_ME_KEY` 注入；生产与 staging 必须使用不同的高熵密钥。

该方案参考 bytedepth 的已验证实现，避免 JDBC `persistent_logins` 的 Token 轮换并发竞态。代价是无法只撤销某一台设备；轮换签名密钥会整体使既有 Remember-Me Cookie 失效。

## Remember-Me 与首次 OIDC 授权

Spring Security 7.1.0 会在默认 Remember-Me 过滤器之前预校验授权请求，并将包含 principal 的 token 缓存到 request attribute。授权链必须在该预校验之前完成持久 Cookie 身份恢复，否则同一请求虽已恢复 Session，授权端仍可能使用匿名 principal 返回 `invalid_request / principal`。一次失败后重试成功并不能证明生命周期正确。

授权服务器链使用 `AuthorizationServerRememberMeConfigurer` 将单个框架恢复过滤器放在 LogoutFilter 之后；保留 provider 验证、共享 SecurityContextRepository 和 SessionAuthenticationStrategy，包括会话持久化与 session ID 轮换。普通 Web 链仍使用默认 Remember-Me 配置。设计依据见 [ADR-0016](../architecture/decisions/0016-remember-me-before-authorization-validation.md)。

防复发入口为 `RememberMeAuthorizationFilterChainTest`：加载真实 Hearth 安全配置及 Spring FilterChainProxy，以 mock servlet 和内存授权仓储验证首次授权、无/无效/过期 Cookie、已有 Session 优先、Session 复用、PKCE 及 CSRF 保护的退出。`OidcLogoutFilterChainTest` 覆盖 RP logout。staging 的 `tests/e2e/native-oidc.spec.mjs` 使用只保留持久 Cookie 的新浏览器上下文，第一跳直接授权，再验证 code exchange、nonce、auth_time 和 userinfo；不得先访问 `/api/session` 掩盖时序问题。本机不执行跨进程 OIDC 验收。
