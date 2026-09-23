# Changelog

Hearth 使用 Semantic Versioning。用户可见、运行时、部署或配置变化必须先记录在 `## Unreleased`，再进入 staging。

## Unreleased

### Added

- 初始化 Hearth 统一身份中心：OIDC 登录边界、服务端 Redis Session、MySQL 身份目录和应用访问数据模型。
- 确定 Hearth 自建 OIDC Provider 方向，接入 Spring Security 7 Authorization Server 边界配置与标准 Provider 路由。
- 新增本地密码凭据、服务端登录 Session，以及 OAuth Client、授权码、Consent 的 MySQL 持久化表。
- 接入 Spring Security 7 的 Authorization Server filter chain、RSA JWK、OIDC claims 和 OAuth Client 管理 API。
- 新增 React/Vite 管理端原型，包含身份总览、应用接入、移动端抽屉导航和登录入口。
- 新增生产/staging 隔离的 Docker Compose 配置与静态环境检查。
- 修复 MySQL utf8mb4 身份联合索引超长问题，并移除未使用的 MyBatis 启动依赖。

### Changed

- 由 bytedepth 模板转换为独立的 Hearth 身份服务工程，模块、包名、运行时变量和服务名统一使用 Hearth 命名。
- 基础设施 JDBC 仓储保持可代理，避免 Spring Repository 异常转换在启动阶段失败。
- 修正 Spring Security 7 Authorization Server endpoint matcher 绑定，并移除未使用的 Thymeleaf 模板依赖。
- 修正登录页 CSRF 请求头名称，使服务端会话登录请求能够通过 Spring Security 校验。
- 登录页在 CSRF token 准备完成前禁用提交，避免快速操作触发 403。
- 显式启用 Redis-backed HTTP Session，并按环境使用隔离的 Redis namespace。
- JSON 登录 API 使用跨请求稳定的非掩码 CSRF token handler，继续保留服务端 CSRF 校验。

### Security

- Hearth 不保存业务密码；生产与 staging 必须使用不同 OIDC client、MySQL 数据目录、Redis namespace 和 Session Cookie。
