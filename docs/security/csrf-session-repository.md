# CSRF 与 Session

浏览器管理端使用 Cookie Session，因此所有有副作用的请求继续受 Spring Security CSRF 保护。退出接口为 `POST /api/session/logout`；前端不得用 GET 触发退出或状态修改。

Session 数据放在 Redis，Cookie 使用 HttpOnly、Secure（HTTPS 环境）和显式 SameSite 属性。身份目录和私人业务数据不进入浏览器持久化存储，详细认证边界见 [会话与认证](authentication.md)。
