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
- Hearth 只确认“你是谁”；业务功能权限仍由各业务系统管理。
