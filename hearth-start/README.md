# hearth-start

Spring Boot 启动与组合模块，提供运行配置、Flyway 数据库迁移、React 前端构建入口和 native staging 集成测试。

**依赖方向：** adapter, infrastructure

**责任：**
- `HearthApplication` 和 `application*.yml` profiles。
- V1–V4 身份、凭据、OAuth 持久化与旧会话兼容迁移。
- `src/main/frontend` React/Vite 管理壳与授权预览。
- 本地 Spring 测试和仅在 staging 执行的 `NativeInfrastructureIT`。

静态文件是前端构建产物，不是独立的文章/博客模板站点。
