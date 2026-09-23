# Hearth 认证与会话

Hearth 自己提供 OIDC，Spring Security 7 Authorization Server 负责协议端点和令牌协议，Redis 存储服务端 Session。业务系统只需要信任 Hearth 的 issuer；浏览器只持有 HttpOnly Session Cookie，不持有访问令牌或身份目录数据。

## 配置

每个环境必须显式设置自己的 `HEARTH_OIDC_ISSUER` 和签名密钥来源 `HEARTH_SIGNING_KEY_LOCATION`。issuer 必须稳定且在 staging/production 使用 HTTPS；不同环境必须使用独立的数据库、Redis namespace、Client 注册和签名密钥。

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
