# ADR-0011: 使用签名 Cookie 实现 Hearth 30 天免登录

- **状态**: Accepted
- **日期**: 2026-09-23
- **决策者**: 项目所有者

## 上下文

Hearth 的统一登录需要支持“保持登录 30 天”，以便 Career、发布服务等业务应用接入后不再各自实现 Remember-Me。当前 Redis 只保存短期 HTTP Session，Session 闲置超时后浏览器必须重新输入密码；仅把 Redis Session 延长到 30 天会增加短期会话的暴露窗口，也无法可靠区分会话级登录和用户明确选择的持久登录。bytedepth 已使用 Spring Security 的无状态 Remember-Me 方案稳定运行。

## 决策

Hearth 使用 Spring Security 的 `TokenBasedRememberMeServices`：浏览器通过 Hearth 专属的 `HttpOnly`、`Secure` Cookie 持有包含用户名、过期时间和 HMAC 签名的自包含凭据；Redis 继续只保存短期 HTTP Session、登录过程中的临时状态和限流状态，不新增 `persistent_logins` 表。

登录页提供“保持登录 30 天”选项。未勾选时维持会话级登录；勾选后创建 30 天签名凭据。退出登录时清除 Cookie；Remember-Me 签名密钥轮换可以整体使既有凭据失效。业务应用不得读取、共享或持久化该 Cookie。

放弃以下方案：

- 将 Hearth HTTP Session 的超时直接改为 30 天：会让所有登录都成为长期会话，无法表达用户选择，且扩大 Redis 会话暴露窗口。
- 使用 JDBC `PersistentTokenRepository`：需要额外表和 Token 轮换状态；bytedepth 已验证并发请求下轮换 Token 可能误触发盗用检测，导致正常用户被整体注销。
- 让每个业务应用各自实现 Remember-Me：造成重复实现、不同安全策略和跨应用体验不一致。

## 后果

**正向**

- 统一实现 30 天免登录能力，业务应用不重复建设。
- Redis 会话保持短期边界；无状态 Cookie 不需要新增数据库表或数据库查询。
- 方案与 bytedepth 已验证实现一致，具备低延迟、无跨实例状态同步和良好的并发稳定性。
- Career、bytedepth 和发布服务只需通过 OIDC 接入，不保存 Hearth 密码或长期 Token。

**负向**

- 签名密钥一旦泄露，攻击者可以伪造有效期内的 Remember-Me Cookie，因此生产环境必须使用独立高熵密钥并限制访问。
- 无状态凭据不能单独撤销某一设备；需要设备级撤销时必须升级为独立的设备会话模型。

## 假设

| 假设 | 可证伪信号（出现时重评） |
|------|--------------------------|
| 业务应用可以继续使用自己的服务端 Session | 主要接入方改为纯前端、无法保存本地 Session |
| 无状态签名 Cookie 满足当前的统一登录需求 | 需要设备级高频撤销且当前无状态方案能力不足 |
| 30 天是内部系统可接受的默认持久期限 | 安全事件或合规要求更短期限，则按 Client 或设备策略收紧 |

## 退出条件

| 信号 | 预设行动 |
|------|----------|
| 需要设备列表和单设备管理 | 增加设备会话实体、管理接口和审计事件 |
| 需要跨应用即时撤销本地 Session | 评估 OIDC Back-Channel Logout 或 Session introspection |
