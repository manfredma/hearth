# Hearth

Hearth 是个人项目的统一身份服务 MVP：提供本地登录、OIDC/OAuth 2.0 接入、Session 和受控的应用 Client 初始化。用户注册、用户管理控制台和多管理员权限仍未实现。

## 项目结构

- `hearth-domain`：身份、应用和应用访问领域模型。
- `hearth-app`：身份与应用访问用例及端口。
- `hearth-infrastructure`：MySQL 持久化和基础设施配置。
- `hearth-adapter`：HTTP、Spring Security 与 OIDC 协议适配。
- `hearth-start`：Spring Boot 启动、Flyway、前端和集成测试。

## 开发与发布

- 项目知识库入口：[docs/README.md](docs/README.md)
- 当前唯一部署说明：[deploy/README.md](deploy/README.md)
- 本机质量门禁：`bash scripts/run-local-quality.sh`
- 当前 native 改造的实施状态见 [native shared infrastructure 计划](docs/superpowers/plans/2026-09-26-hearth-native-shared-infrastructure.md)。

本机只运行纯单元测试和静态检查；跨进程 MySQL、Redis、Flyway、OIDC、Nginx 与浏览器验证在 staging 执行。
