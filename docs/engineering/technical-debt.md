# Hearth 技术债清单

这里记录已确认、暂缓处理的 Hearth 工程债务。每项说明当前 MVP 范围、影响、处理触发条件和验收标准；状态变化随代码与测试更新。

状态约定：

- `Deferred`：项目所有者确认暂缓，触发条件到来前不扩大范围。
- `In Progress`：已有处理变更，尚未完成验证。
- `Resolved`：实现、测试和所需发布验收均完成。

## TD-HEARTH-001：为 Client 管理接口补充 Hearth 内部管理员权限

- **状态**：`Deferred`（项目所有者决定在 MVP 后处理）
- **发现日期**：2026-09-26
- **范围**：`POST`、`GET`、`DELETE /api/admin/oauth-clients`。
- **当前 MVP 现状**：Hearth 尚无用户注册/创建用户 API，也没有 Client 管理页面。2026-09-26 核对 staging 时有 1 条身份、1 条启用凭据和 1 个已登记 Client；E2E 使用预置 `admin`，并在隔离的测试数据库副本里临时创建 Client。此数量是当日快照，不是永久约束。
- **当前代码行为**：接口要求登录，但没有独立的 Hearth 管理员 authority。现有预置账户边界下暂缓，不把它描述成面向公众的注册或管理功能。
- **未来风险**：如果加入注册、创建更多普通账户或开放管理页面，任何已登录身份都可能创建或撤销 OAuth Client，影响 Hearth 的 OIDC 信任关系。
- **处理触发条件**：实现用户注册/账户创建、增加非管理员可交互账户，或开放 Client 管理页面之前。
- **处理方向**：为 Hearth 自身操作建立独立管理员 authority（例如 `HEARTH_ADMIN`），仅授予明确的 Hearth 运维管理员；管理接口必须检查该 authority。它只保护 Hearth 自身的 Client 管理，不是业务系统的角色或资源权限，也不复用 `application_access.role_key`。
- **验收条件**：匿名请求与普通身份对以上管理接口均被拒绝；指定 Hearth 管理员可以按权限执行创建、查询和撤销；E2E 覆盖允许/拒绝两类身份；管理员授予方式纳入后续初始化流程。
- **边界依据**：[ADR-0001：统一身份认证与业务授权边界](../architecture/decisions/0001-unified-identity-and-authorization-boundary.md)。

## TD-HEARTH-002：支持 Hearth 退出后主动失效业务系统 Session

- **状态**：`Deferred`（当前 MVP 仅支持业务系统发起的 RP-Initiated Logout）
- **发现日期**：2026-09-28
- **范围**：Hearth 登出后通知已接入的 Career、release-platform/devops 等业务系统，清理其各自的本地 Session。
- **当前 MVP 现状**：Hearth 的 `/connect/logout` 会清理 Hearth 自身的统一登录 Session，并将用户回跳到发起登出的业务系统；业务系统的本地 `JSESSIONID` 由各业务系统独立维护。用户直接在 Hearth 页面退出时，Hearth 不会主动通知这些业务系统。
- **当前影响**：用户从 Hearth 退出后，之前已建立的业务系统本地 Session 可能在各自的 Session 空闲超时前继续有效。用户从业务系统点击退出仍可按 RP-Initiated Logout 同时清理业务系统本地 Session 与 Hearth Session。
- **处理触发条件**：要求“从 Hearth 单点退出后，所有已接入业务系统立即退出”，或出现业务系统本地 Session 与 Hearth 状态不一致导致的安全/合规要求。
- **处理方向**：评估 OIDC Back-Channel Logout、Front-Channel Logout 或受控 Session introspection；明确各业务系统的回调认证、失败重试、撤销审计和 Redis/Session 存储边界，不共享 Hearth Cookie。
- **验收条件**：Hearth 退出后，已登记并在线的业务系统在约定时限内清理本地 Session；离线、重复通知、无效签名和部分失败均可观测且不影响 Hearth 自身退出；Career、release-platform/devops 具备真实 staging E2E 证据。
- **边界依据**：[ADR-0009：Hearth 管理统一 SSO Session、记住登录与统一退出](../architecture/decisions/0009-central-sso-session-and-logout.md)。
