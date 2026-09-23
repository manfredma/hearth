# Hearth 工程陷阱

这里记录已经固化为 Hearth 规则的常见问题。发现新的流程、配置、测试或部署错误时，必须同时补充文档规则和可重复的自动检查。

## 构建与测试

- Maven 必须使用 Wrapper、Java 25 和提交到仓库的 `.mvn/jvm.config`；不要依赖本机默认 `mvn`。
- 新 worktree 在任何前端测试、lint 或 Playwright 前必须先执行 `npm ci --ignore-scripts --no-audit --no-fund`。
- `mvn clean install` 不代表所有质量插件都已执行；覆盖率、PMD 和完整测试必须运行 `verify` 或统一质量入口。
- 单元测试不得连接独立 MySQL、Redis、Docker、Flyway 或浏览器；这些验证属于 staging 集成验收。

## 部署与数据

- 同机多项目的 compose service 必须带 `hearth-` 前缀，不能使用通用的 `app` 名称，避免共享 Docker 网络 DNS 别名冲突。
- staging 和生产必须使用独立数据库目录、Redis namespace、Session Cookie 和 OIDC client；前端不得用 localStorage 保存私人身份或业务数据。
- 已执行的 Flyway 迁移不可修改，schema 变化必须追加新迁移。
- 部署必须重建并启动完整 compose 服务，不能只 `up --build -d` 单个应用服务。

## 安全

- OIDC `issuer + sub` 是跨应用身份稳定键；不能用 email 代替 subject。
- Hearth 管理认证、身份目录和应用访问；业务系统管理功能权限、资源权限和数据权限。
- session 只保存服务端身份引用，浏览器通过 HttpOnly、Secure、SameSite Cookie 持有 session 标识。
- 放入 Redis HTTP Session 的 Spring Security principal 必须实现稳定的 `Serializable` 合约，并用 Java 序列化往返测试覆盖；否则登录请求虽然认证成功，提交 session 时仍会失败。
- 跨站点 OIDC 回跳后的 SPA 登录不能只依赖 session 中的 CSRF token；统一使用非 HttpOnly 的 `XSRF-TOKEN` cookie，并让 `X-CSRF-TOKEN` 请求头与之匹配。
