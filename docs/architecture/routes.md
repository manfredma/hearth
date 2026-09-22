# Hearth 路由一览

## 管理端

| 路径 | 方法 | 说明 |
| --- | --- | --- |
| `/` | GET | React 管理端壳层。 |
| `/api/health` | GET | 健康检查，不要求登录。 |
| `/api/session` | GET | 返回当前服务端 Session 对应的身份摘要。 |
| `/api/session/logout` | POST | 清理服务端 Session，受 CSRF 保护。 |
| `/oauth2/authorization/hearth` | GET | 发起 OIDC 登录，由 Spring Security 生成。 |
| `/login/oauth2/code/hearth` | GET | OIDC 回调，由 Spring Security 处理。 |

应用登记、访问授予和审计 API 会在对应应用例完成后追加；不能为了让页面“看起来可用”而虚构接口。

## 访问规则

- 静态管理端、健康检查和 OAuth2 发起/回调入口公开。
- Session API 和未来的管理 API 要求已认证身份。
- OIDC 关闭时，Hearth 不提供本地密码登录入口；生产必须显式配置 OIDC。
