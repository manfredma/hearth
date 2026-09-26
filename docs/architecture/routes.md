# Hearth 路由一览

## 管理端

| 路径 | 方法 | 说明 |
| --- | --- | --- |
| `/` | GET | React 管理端壳层。 |
| `/api/health` | GET | 健康检查，不要求登录。 |
| `/api/session` | GET | 返回当前服务端 Session 对应的身份摘要。 |
| `/api/session/logout` | POST | 清理服务端 Session，受 CSRF 保护。 |
| `/api/csrf` | GET | 返回当前服务端 CSRF token，供登录表单提交使用。 |
| `/api/login` | POST | 使用 Hearth 本地账号建立服务端 Session。 |
| `/.well-known/openid-configuration` | GET | Hearth OIDC Provider 元数据。 |
| `/oauth2/authorize` | GET | Authorization Code 授权入口，要求登录并支持 PKCE。 |
| `/oauth2/token` | POST | Authorization Code/Refresh Token 交换入口。 |
| `/oauth2/jwks` | GET | 当前与轮换重叠期的公钥集合。 |
| `/userinfo` | GET | 按 scope 返回当前身份信息。 |
| `/connect/logout` | GET | OIDC RP-Initiated Logout 入口。 |
| `/api/applications` | GET | 返回当前应用登记元数据。 |
| `/api/applications/{applicationKey}` | GET | 返回指定应用的公开登记元数据。 |
| `/api/admin/oauth-clients` | POST | 注册 OAuth Client；Client Secret 只在创建响应中返回一次。 |
| `/api/admin/oauth-clients` | GET | 列出已登记 Client 的非敏感摘要。 |
| `/api/admin/oauth-clients/{clientId}` | DELETE | 撤销 Client 及其 Consent/授权记录。 |

当前 MVP 未实现用户注册/创建用户和 Client 管理页面。Client 管理 API 的内部管理员权限已列为技术债，见 [TD-HEARTH-001](../engineering/technical-debt.md)。

## 访问规则

- 静态管理端、健康检查、OIDC discovery、JWK 和授权入口按协议要求公开；令牌、UserInfo 和管理 API 按认证状态保护。
- Session API 和 Client 管理 API 要求已认证身份；Client 管理 API 尚未区分 Hearth 内部管理员与其他身份，按技术债触发条件处理。
- Hearth 是 OIDC Provider，不再把外部身份提供商作为运行时前提；生产必须显式配置 issuer、签名密钥、MySQL 和 Redis。
