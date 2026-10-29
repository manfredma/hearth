# ADR-0016: 授权预校验前恢复 Remember-Me 身份

- **状态**: Accepted
- **日期**: 2026-10-30

## 上下文

Spring Security 7.1.0 在 AbstractPreAuthenticatedProcessingFilter 前预校验授权请求并缓存含 principal 的 token。默认 RememberMeAuthenticationFilter 排在之后；仅有有效持久 Cookie 时，SecurityContext 恢复成功，但授权端点仍使用匿名 principal，首次请求报 invalid_request / principal。

## 决策

仅在授权服务器链提前执行框架 RememberMeAuthenticationFilter，放在 LogoutFilter 后、授权预校验前。使用专用 HttpConfigurer 按标准 RememberMeConfigurer 契约初始化，保留 provider、LogoutHandler、SecurityContextRepository、SessionAuthenticationStrategy 与事件处理；不增加第二个恢复过滤器。普通 Web 链维持标准配置。

不延长 Session、不放宽 principal 校验、不清除框架缓存、不复制 Cookie 到业务应用。PKCE、state、nonce、CSRF、issuer/subject 和退出语义保持现有契约。

## 方案比较

- 采用提前恢复：授权 token 从一开始携带有效身份，继续使用框架验证与会话持久化机制。
- 不采用删除 request attribute 或重建 token：耦合框架私有缓存细节且容易重复或绕过预校验。
- 不采用业务应用预热 /api/session：将 Hearth 的内部时序缺陷转移给每个依赖方。

## 防复发

进程内测试加载 Hearth 两条真实 SecurityFilterChain，使用真实签名 Cookie 和内存授权仓储，断言仅持久 Cookie 的首次授权、后续 Session、无/无效/过期 Cookie、已有 Session、PKCE 及两类退出。真实跨进程验收只在 staging，由 release-platform 编排。
