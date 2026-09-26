# hearth-adapter

Hearth 的外部协议与 Web 适配层：将 OIDC/OAuth、登录、Session 和应用 Client 管理请求接到应用用例或协议框架。

**依赖方向：** app（不直接使用持久化或 Redis API）

**责任：**
- OIDC Authorization Server 配置、Discovery、Token、JWKS、UserInfo 与退出。
- 登录页、CSRF、Session API 和健康/版本端点。
- 应用元数据与 OAuth Client HTTP 适配。
- Spring Security 路由与身份适配。

这里不承载业务应用的功能、资源或数据权限。MVP 中 Client 管理接口的管理员权限属于已记录的技术债，见 [技术债清单](../docs/engineering/technical-debt.md)。
