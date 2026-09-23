# Changelog

Hearth 使用 Semantic Versioning。用户可见、运行时、部署或配置变化必须先记录在 `## Unreleased`，再进入 staging。

## Unreleased

### Added

- 初始化 Hearth 统一身份中心：OIDC 登录边界、服务端 Redis Session、MySQL 身份目录和应用访问数据模型。
- 确定 Hearth 自建 OIDC Provider 方向，接入 Spring Security 7 Authorization Server 边界配置与标准 Provider 路由。
- 新增 React/Vite 管理端原型，包含身份总览、应用接入、移动端抽屉导航和登录入口。
- 新增生产/staging 隔离的 Docker Compose 配置与静态环境检查。

### Changed

- 由 bytedepth 模板转换为独立的 Hearth 身份服务工程，模块、包名、运行时变量和服务名统一使用 Hearth 命名。

### Security

- Hearth 不保存业务密码；生产与 staging 必须使用不同 OIDC client、MySQL 数据目录、Redis namespace 和 Session Cookie。
