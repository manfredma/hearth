# ADR-0017: 将静默认证交给 OIDC 协议处理器

- 状态: Accepted
- 日期: 2026-11-04

## 根因与证据

Hearth 的 Spring Boot 4.1.0 管理 Spring Security 7.1.0。完整真实安全链的新增无 Cookie 回归期望回调 login_required，实际进入 /login。AuthorizationFilter 在 OAuth2AuthorizationEndpointFilter 前执行，外层 authenticated 使匿名请求提前进入 HearthLoginAuthenticationEntryPoint。7.1.0 Provider 已在客户端、redirect_uri、scope、PKCE 和 prompt 校验之后实现 login_required、consent_required；不需要项目重写错误跳转。

参考 Spring Security 官方讨论 https://github.com/spring-projects/spring-security/issues/18647 ，以本项目实际测试为准。

## 决策

仅对配置的授权端点 GET/POST 且 prompt 精确为 none 的请求允许通过外层门禁。前置验证过滤器和协议端点继续运行，允许请求到达不代表允许签发授权码。所有客户端和回调校验、认证、consent、账号与访问策略仍由原安全链执行。保留 ADR-0016 的提前 Remember-Me 恢复顺序；不改变其他端点和普通交互请求。

备选：公开整个授权端点会改变普通匿名请求的登录行为；在 entry point 手写错误回调会重复框架校验并引入开放重定向风险；新过滤器翻译异常会增加重复协议实现。均不采用。

## 行为及边界

有效 Session 或有效签名 Cookie 且已有所需授权时签发 code；匿名、无效或过期 Cookie 返回 login_required；需要同意返回 consent_required。错误仅使用框架验证过的回调，并保留 state。非法客户端/回调在本地安全失败，不访问不可信 URI。交互式登录、CSRF、PKCE、state、nonce 和环境隔离保持原契约。

退出测试遵循浏览器 Cookie 删除语义：普通退出和 RP logout 使 Session 无效并清除浏览器 Remember-Me，再次静默请求应 login_required。现有签名 Cookie 是无状态凭据；服务器无法单独吊销被外部复制的旧 Cookie，此次不新增撤销存储，也不宣称防重放。若产品要求让复制品也立即失效，需要另行设计凭据撤销机制。

## 验证与防复发

真实安全链覆盖 Session、Cookie-only、匿名、错误/过期签名、consent、client/redirect/PKCE/prompt 拒绝、普通登录和两种退出。staging 通过真实登记客户端的正常入口生成 state/nonce/PKCE，新增 prompt=none；隔离上下文只保留 Remember-Me、首个请求直接授权，禁止预热 /api/session。错误与成功均只输出布尔断言或固定诊断，不输出 Cookie、state、nonce、code、Token 和凭据。仅 staging，不发布生产。

## Staging 验证发现

无效 client 与未登记 redirect_uri 的框架 sendError(400) 在完整 Servlet 容器经受保护的 ERROR 分派后表现为本地 403，无 Location；mock FilterChainProxy 则直接保留 400。二者均安全拒绝，E2E 检查本地 400/403 且禁止重定向；PKCE/prompt 等已可安全回调的错误仍严格校验标准错误与 state。不要为统一错误状态放宽普通 Web 错误路径的访问规则。
