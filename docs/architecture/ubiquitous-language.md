# Hearth 统一语言

| 术语 | 定义 | 边界 |
| --- | --- | --- |
| 身份主体（Identity Subject） | OIDC `issuer + subject` 组成的稳定外部身份键。 | 不等同于显示名、邮箱或业务系统用户 ID。 |
| 身份账号（Identity Account） | Hearth 中可被各业务系统引用的身份目录记录。 | 不保存业务密码，不承载业务资源归属。 |
| 应用（Application） | 接入 Hearth 的业务系统，例如 daylilt、career、toolbox。 | 应用自己的业务数据和权限仍由应用管理。 |
| 应用访问（Application Access） | 某个身份进入某个应用的授予关系。 | 不是该应用内部的完整 RBAC，也不是数据权限。 |
| 认证（Authentication） | 确认“你是谁”，由 OIDC 身份提供商和 Hearth Session 完成。 | 不决定你能编辑哪条业务数据。 |
| 授权（Authorization） | 判断是否允许某个动作。 | 粗粒度的应用访问可由 Hearth 提供，功能、资源和数据权限由业务系统完成。 |
| 当前身份（Current Identity） | 当前服务端 Session 解析出的身份摘要。 | Web 层通过 API 使用，不把令牌下发给浏览器业务代码。 |
