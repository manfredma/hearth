# Hearth 认证与会话

Hearth 使用 OIDC 完成登录，Spring Security OAuth2 Client 处理回调，Redis 存储服务端 Session。浏览器只持有 HttpOnly Session Cookie，不持有访问令牌或身份目录数据。

## 配置

开启 OIDC 时必须显式设置 `HEARTH_OIDC_ENABLED=true`，并通过 Spring Security 标准环境变量提供 registration `hearth` 与 provider `hearth` 的 client-id、client-secret、issuer-uri、scope。不同环境必须注册不同的 OIDC client。

## 约束

- Hearth 不接收、不校验、不存储业务系统密码。
- Session Cookie 必须在 HTTPS 环境启用 Secure，并设置合适的 SameSite 策略。
- 修改 Session、CSRF 或 OIDC 回调行为时，必须补充适配层测试，并在 staging 做跨进程验收。
- 认证成功只建立“当前身份”；业务系统仍需根据稳定 subject 映射自己的用户和权限。
