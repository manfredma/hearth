# Hearth 30 天持久登录设计

## 目标

为 Hearth 增加统一的 30 天免登录能力，保持现有 OIDC 接入方不保存长期凭据，并让 Career 等业务系统在自身 Session 过期后能够通过 Hearth 静默恢复登录。

## 现状与边界

- Hearth HTTP Session 当前由 Redis 保存，闲置超时为 60 分钟。
- Career 使用 Authorization Code + PKCE，不再提供本地密码登录页，也不再保存 Career Remember-Me Cookie。
- Hearth 的 OAuth Refresh Token 30 天配置不能替代浏览器登录态：Career 的浏览器登录流程使用授权码换取 OIDC 身份并建立自身 Session。
- 浏览器不得写入 `localStorage`、`sessionStorage` 或业务应用 Cookie；持久 Cookie 只属于 Hearth 域。

## 方案

### 登录交互

Hearth 登录页增加“保持登录 30 天”复选框，与原 Career 的用户体验保持一致，默认不勾选。前端将选择作为 `/api/login` 请求的 `rememberMe` 字段提交。

### 会话与持久凭据

1. 密码认证成功后，Hearth 仍创建 Redis HTTP Session，并保存 `HearthPrincipal`。
2. `rememberMe=true` 时，Hearth 通过 Spring Security 的 `TokenBasedRememberMeServices` 创建包含用户名、过期时间和 HMAC 签名的自包含凭据。
3. 浏览器收到 Hearth 专属持久 Cookie，Cookie 设置 `HttpOnly`、HTTPS 环境 `Secure`、`SameSite=Lax`，有效期为 30 天。
4. 后续请求发现 Redis Session 已过期时，Remember-Me 服务校验签名凭据并重新建立 Redis Session。
5. 退出登录同时清除当前 Redis Session 和浏览器持久 Cookie。

未勾选时不创建持久凭据，仍采用当前会话级登录行为。

### Redis 与 MySQL 职责

| 存储 | 保存内容 | 生命周期 |
|------|----------|----------|
| Redis | HTTP Session、OIDC 授权过程中的短期状态、限流状态 | 分钟到小时，按 Session 超时自动过期 |
| MySQL | 用户、OAuth 授权数据 | 持久化 |

30 天 Remember-Me 凭据由 Hearth 签名密钥保护；即使 Redis Session 过期，签名凭据仍可恢复登录。轮换签名密钥可以整体使旧凭据失效。

## 模块设计

- `hearth-adapter`：登录请求字段、Remember-Me 服务接入、Cookie 和 Spring Security Filter Chain 配置。
- `hearth-start`：30 天配置默认值和环境密钥注入。
- `hearth-infrastructure`：不新增 Remember-Me 持久化实现；MySQL 继续负责身份和 OAuth 数据。
- `hearth-start/src/main/frontend`：复选框、提交状态和无障碍标签。

不新增 Maven 模块，不改变 OIDC 公共端点和 Career 的 OIDC 配置。

## 测试策略

- 适配层单元测试：`rememberMe` 字段传递、Cookie 属性、30 天有效期、未勾选清除已有凭据、自动恢复为 Hearth 身份。
- 配置测试：Remember-Me 使用 `TokenBasedRememberMeServices`，TTL 必须为 30 天；Redis Session 超时仍为 60 分钟。
- 前端测试：复选框默认状态、提交 payload 和登录失败/提交中状态。
- staging E2E：勾选后关闭并重新打开浏览器仍可访问 Career；清除 Hearth Session 后再次访问能静默恢复；注销后不能恢复；未勾选仍保持会话级行为。

## 非目标

- 不把 30 天 Token 返回给 JavaScript。
- 不让业务应用共享 Hearth Cookie。
- 不实现跨设备会话管理、设备列表或全局权限系统。
