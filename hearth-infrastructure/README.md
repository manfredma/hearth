# hearth-infrastructure

Hearth 应用端口的基础设施实现，当前以 JDBC/MySQL 身份持久化为主，并提供 Redis Session 所需的 Spring 配置。

**依赖方向：** app, domain

**责任：**
- 身份目录与本地密码凭据 JDBC 仓储。
- 应用登记与应用访问 JDBC 仓储。
- Spring Boot 所需的基础设施配置。

OAuth Client、授权和 Consent 持久化使用 Spring Authorization Server 的 JDBC 适配，定义于 `hearth-adapter`；Hearth 不使用 MyBatis-Plus、MeiliSearch、GeoIP 或文章统计设施。
