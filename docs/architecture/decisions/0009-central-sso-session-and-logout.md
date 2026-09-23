# ADR-0009: Hearth 管理统一 SSO Session、记住登录与统一退出

- **状态**: Accepted
- **日期**: 2026-09-23
- **决策者**: 项目所有者

## 上下文

Career、bytedepth、daylilt 等 Web 应用需要单点登录。若每个应用分别实现“记住我 30 天”，用户仍会在不同系统重复输入密码，且各系统会形成不同的长期凭据和安全策略。若直接共享跨应用 Session Cookie，又会扩大 Cookie 信任域并让应用之间产生强耦合。

退出登录也有两层状态：应用自己的业务 Session，以及 Hearth 的统一登录 Session。只清除应用 Session 会导致用户再次访问时被 Hearth 静默登录，看起来像退出失败。

## 决策

Hearth 负责浏览器级统一 SSO Session、持久登录（例如“记住我 30 天”）和 OIDC RP-Initiated Logout；每个业务应用继续维护自己的本地 Session，禁止共享 Session Cookie。

登录和访问流程：

1. 用户在任一应用发起 OIDC 登录。
2. Hearth 建立或复用自己的登录 Session。
3. Hearth 返回授权结果，业务应用创建自己的本地 Session。
4. 业务应用本地 Session 过期时，重新跳转 Hearth；若 Hearth 的持久登录 Session 仍有效，则无需再次输入密码。

退出流程：

1. 业务应用先清除自己的 Session。
2. 业务应用通过 `end_session_endpoint` 跳转 Hearth。
3. Hearth 清除统一登录 Session，并校验 `id_token_hint` 与 `post_logout_redirect_uri`。
4. Hearth 将用户安全地返回业务应用登录页。

长期登录凭据必须由 Hearth 使用服务端 Session/安全 Cookie 保存；不得写入业务应用的 `localStorage`，也不得把 Hearth Session Cookie 共享给业务应用。敏感操作仍可要求重新认证。

## 后果

**正向**

- “记住登录 30 天”只需实现和审计一套。
- 多个应用可以获得单点登录体验，同时保持各自 Session 和故障边界。
- 统一退出可以同时结束中央登录状态和当前应用状态。
- 应用不需要保存 Hearth 密码或长期身份凭据。

**负向**

- 需要正确配置每个应用的 Client、回调地址和退出回调地址。
- Hearth Session 失效、Redis 故障或密钥轮换会影响所有接入应用。
- 当前应用 Session 不会因为 Hearth Session 失效而立即全部消失；敏感应用需要额外的重新校验或后通道登出策略。

## 假设

| 假设 | 可证伪信号（出现时重评） |
|------|--------------------------|
| 业务应用可以使用服务端 Session 保存本地登录态 | 主要应用转为无法安全保存服务端 Session 的纯客户端形态 |
| Hearth 可以可靠保存和失效 Redis Session | 需要跨区域高可用或集中会话审计且当前实现无法满足 |
| 30 天持久登录是内部应用可接受的默认安全期限 | 发生账号被盗或合规要求更短期限，则收紧默认期限并增加设备管理 |

## 退出条件

| 信号 | 预设行动 |
|------|----------|
| 需要在 Hearth 退出后立即失效所有应用 Session | 评估 OIDC Back-Channel Logout 或应用 Session introspection |
| 不同应用需要不同的持久登录期限 | Hearth 支持按 Client 配置期限，仍保持中央会话归属 |
| 需要设备级会话管理 | 增加 Hearth 的设备列表、单设备撤销和安全审计能力 |
