# Hearth 统一身份中心设计规格

- **状态**: Proposed
- **日期**: 2026-09-22
- **项目**: Hearth

## 1. 目标

Hearth 为 toolbox、release、career、bytedepth、daylilt 等独立应用提供统一身份入口和单点登录能力。Hearth 解决用户身份认证、应用访问和跨应用的粗粒度授权，不接管各业务系统的资源权限和业务规则。

## 2. 非目标

- 不自行实现密码协议、OAuth 令牌签发或 OIDC 核心协议。
- 不把日记、文章、候选人、发布环境等业务数据权限集中到 Hearth。
- 不让所有应用共享一个业务 Session Cookie。
- 不让 staging 访问生产身份数据或生产业务数据。

## 3. 总体架构

```text
浏览器
  -> 业务应用（toolbox / release / career / bytedepth / daylilt）
  -> Hearth OIDC 入口
  -> 外部成熟身份提供商（首选评估 Keycloak，保留 ZITADEL 选项）
```

每个应用注册独立 OIDC Client，使用 Authorization Code + PKCE 完成登录。应用验证 ID Token 后创建自身的 HttpOnly、Secure、SameSite 会话；访问业务 API 时使用服务端会话或受控 Access Token，不将私人数据或长期 Token 写入浏览器 localStorage。

## 4. 责任边界

### Hearth 负责

- 全局用户身份和不可变用户标识。
- 登录、退出、密码策略、MFA、账号生命周期和认证审计。
- 应用注册、回调地址和环境级 Client 配置。
- 用户是否能访问某个应用。
- 跨应用的粗粒度角色或功能授权声明。
- 授权变更的管理和审计。

### 业务系统负责

- 本系统功能权限的具体定义和服务端执行。
- 资源、租户、项目、文章、候选人、日记等数据权限。
- 审批、环境、所有权、状态机和其他业务规则。
- 高风险操作的实时授权检查，不能只依赖 Token 中可能过期的声明。

统一角色只表达应用级能力，例如 `release:operator`；`release` 自己决定该角色是否可以发布 staging、是否可以发布 production，以及是否需要审批。

## 5. 环境隔离

生产和 staging 使用独立的身份提供商实例或 realm、独立数据库、独立 Client 和独立密钥。两个环境不得共享用户表、Session、Refresh Token 或权限变更数据。环境内使用身份提供商的 `issuer + subject` 作为稳定身份键，禁止用用户名或邮箱自动合并账号。

## 6. 初始项目结构

Hearth 以 bytedepth 的 DDD 分层、知识库、质量门禁和部署约束为模板，但会清理博客领域代码并改为 Hearth 的身份领域：

```text
hearth/
├── hearth-domain
├── hearth-app
├── hearth-adapter
├── hearth-infrastructure
├── hearth-start
├── docs/
├── deploy/
└── scripts/
```

第一阶段优先完成认证接入、应用注册、环境配置、用户同步和审计骨架；权限管理只实现应用访问与粗粒度角色的基础接口，不实现各业务系统的资源权限。

## 7. 验收标准

- 任一接入应用可以跳转 Hearth 完成登录，并在其他接入应用中复用登录状态。
- 应用能稳定获得不可变的 `issuer + subject` 身份标识。
- 生产和 staging 的身份、会话、Client、密钥和数据完全隔离。
- 业务系统可以独立执行自己的功能权限和数据权限。
- 浏览器不存在私人业务数据 localStorage 持久化方案。
- 认证协议、会话、权限边界和环境隔离均有单元测试、集成测试或契约检查覆盖。

## 8. 需要后续单独决策的事项

- Keycloak 与 ZITADEL 的最终选型及运维拓扑。
- 统一用户资料字段和账号迁移匹配规则。
- 跨应用角色命名空间与 Token Claim 约定。
- 生产认证中心的备份、恢复、可用性和应急管理员流程。
