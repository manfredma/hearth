# Hearth 架构概览

Hearth 是独立的统一身份服务，负责认证、身份目录、应用接入登记和应用访问授予；业务系统仍负责自己的业务权限、资源权限和数据权限。

## 技术边界

- Spring Boot 4 + Spring Security 7，OIDC 登录，服务端 Redis Session。
- React + Vite 管理端，后端提供 JSON API；不使用 Thymeleaf 页面渲染。
- MySQL 8 + Flyway 是身份数据的唯一持久化来源；浏览器不保存私人身份数据。
- staging 与生产使用不同 MySQL 数据目录、Redis namespace、Session Cookie 和 OIDC client。

## 模块和依赖方向

```text
hearth-adapter ─────▶ hearth-app ─────▶ hearth-domain
hearth-infrastructure ────────────────▶ hearth-app + hearth-domain
hearth-start ───────▶ adapter + infrastructure
```

| 模块 | 责任 |
| --- | --- |
| `hearth-domain` | `IdentitySubject`、应用标识和访问关系等纯领域模型。 |
| `hearth-app` | 身份目录、应用访问端口和用例，不依赖 Web 或数据库。 |
| `hearth-infrastructure` | MySQL、Redis、Flyway 之外的基础设施实现与配置。 |
| `hearth-adapter` | OIDC/Spring Security 边界、Session API 和 Web 适配。 |
| `hearth-start` | Spring Boot 启动、配置、迁移和打包入口。 |

## 明确不属于 Hearth 的职责

Hearth 不保存业务系统密码，不替业务系统决定“能否编辑一篇日记”，也不把各应用的业务角色合并成一个全局角色。应用通过 OIDC 识别用户，再在自己的边界内完成业务授权。

详见 [统一身份与授权边界 ADR](decisions/0001-unified-identity-and-authorization-boundary.md)、[OIDC 接入 ADR](decisions/0002-oidc-oauth2-application-integration.md) 和 [应用访问说明](../security/application-access.md)。
