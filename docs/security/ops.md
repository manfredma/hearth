# Hearth 运维安全边界

Hearth 运维只允许通过受控部署流程执行，不提供网页端任意 SQL、Redis、容器或宿主机命令入口。数据库迁移由 Flyway 随应用启动执行，真实 MySQL/Redis 连通性和 OIDC 配置只能在 staging 验证。

身份审计需要记录谁在什么时间对哪个应用执行了什么操作，但禁止记录密码、令牌、Session Cookie 或完整 OIDC 响应。
