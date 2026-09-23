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

应用登记、访问授予和审计 API 会在对应应用例完成后追加；不能为了让页面“看起来可用”而虚构接口。

## 访问规则

- 静态管理端、健康检查、OIDC discovery、JWK 和授权入口按协议要求公开；令牌、UserInfo 和管理 API 按认证状态保护。
- Session API 和未来的管理 API 要求已认证身份。
- Hearth 是 OIDC Provider，不再把外部身份提供商作为运行时前提；生产必须显式配置 issuer、签名密钥、MySQL 和 Redis。
