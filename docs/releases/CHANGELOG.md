# Changelog

Hearth 使用 Semantic Versioning。用户可见、运行时、部署或配置变化必须先记录在 `## Unreleased`，再进入 staging。

## Unreleased

### Added

- 初始化 Hearth 统一身份中心：OIDC 登录边界、服务端 Redis Session、MySQL 身份目录和应用访问数据模型。
- 增加 Hearth 统一的 30 天免登录：复用 bytedepth 已验证的 Spring Security 无状态签名 Remember-Me Cookie。
- 确定 Hearth 自建 OIDC Provider 方向，接入 Spring Security 7 Authorization Server 边界配置与标准 Provider 路由。
- 新增本地密码凭据、服务端登录 Session，以及 OAuth Client、授权码、Consent 的 MySQL 持久化表。
- 接入 Spring Security 7 的 Authorization Server filter chain、RSA JWK、OIDC claims 和 OAuth Client 管理 API。
- 新增 React/Vite 管理端原型，包含身份总览、应用接入、移动端抽屉导航和登录入口。
- 新增 Hearth 品牌化 OAuth 授权确认视觉原型，展示来源应用、来源域名、当前账号和可审阅的权限项，并适配移动端。
- 优化 OAuth 授权确认视觉稿：强化来源应用与 Hearth 的连接关系，收紧版式层级并细化权限清单与操作区。
- 修复授权确认页手机端操作区的按钮宽度冲突，避免主按钮文字在窄屏下竖排。
- 新增生产/staging 隔离的 Docker Compose 配置与静态环境检查。
- 修复 MySQL utf8mb4 身份联合索引超长问题，并移除未使用的 MyBatis 启动依赖。

### Changed

- 修复 OAuth 授权确认页提交时缺少 CSRF Token 导致授权请求返回 403 的问题：页面显式提交 Token，OAuth 专用过滤链复用统一的 Cookie CSRF 策略，并在 Token 未加载完成前禁用提交按钮。
- 修复 OAuth 授权码换 Token 时缺少 `auth_time` 导致 Career 回调失败并重复发起登录的问题：本地密码登录、Remember-Me 和旧会话迁移均携带带时间戳的 Spring Security 认证因子。
- 修复 OAuth 授权确认在登录后返回 403 的问题：认证会话改用 Spring Security 可持久化的标准用户主体，兼容旧 HearthPrincipal 会话，并清理已写入旧主体的失效授权记录。
- 收敛 OAuth 授权确认页的身份上下文展示：合并 Career 来源与当前账号信息，移除重复的 Hearth 身份块，并优化域名、权限说明和移动端布局。
- 将授权确认原型接入真实 OAuth 流程：Career 授权请求使用 Hearth 中文 consent 页面，支持动态应用/账号信息、权限选择、同意与取消提交。
- 修复授权确认页原生表单提交时 `client_id`、`state`、`user_code` 和 `scope` 参数丢失，确保同意与取消都能正确回到 OAuth 授权端点。
- 由 bytedepth 模板转换为独立的 Hearth 身份服务工程，模块、包名、运行时变量和服务名统一使用 Hearth 命名。
- 基础设施 JDBC 仓储保持可代理，避免 Spring Repository 异常转换在启动阶段失败。
- 修正 Spring Security 7 Authorization Server endpoint matcher 绑定，并移除未使用的 Thymeleaf 模板依赖。
- 修正登录页 CSRF 请求头名称，使服务端会话登录请求能够通过 Spring Security 校验。
- 登录页在 CSRF token 准备完成前禁用提交，避免快速操作触发 403。
- 显式启用 Redis-backed HTTP Session，并按环境使用隔离的 Redis namespace。
- JSON 登录 API 使用跨请求稳定的非掩码 CSRF token handler，继续保留服务端 CSRF 校验。
- SPA 登录使用非 HttpOnly 的 `XSRF-TOKEN` CSRF cookie，并继续通过 `X-CSRF-TOKEN` 请求头校验。
- OIDC 未登录请求显式携带 `/login?continue=...`，登录后可稳定回到原始授权请求。
- Redis HTTP Session 中的 HearthPrincipal 支持 Java 序列化，修复登录成功后无法持久化会话的问题。

### Security

- Hearth 不保存业务密码；生产与 staging 必须使用不同 OIDC client、MySQL 数据目录、Redis namespace 和 Session Cookie。
- Remember-Me 签名密钥由 `HEARTH_REMEMBER_ME_KEY` 注入，HTTPS 环境使用 HttpOnly、Secure、SameSite=Lax Cookie；业务应用不共享该 Cookie。
