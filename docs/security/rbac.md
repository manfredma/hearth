# 权限边界

Hearth 当前解决的是统一认证和应用级访问，不提供跨业务系统的全局功能 RBAC。

- Hearth 可以记录某个用户是否被授予某个应用的访问，以及应用命名空间下的角色提示。
- daylilt、career、toolbox 等业务系统负责自己的功能权限、资源权限和数据权限。
- 业务系统不能仅因为用户能登录 Hearth 就允许其访问全部业务数据。
- 页面隐藏不是授权；业务系统必须在自己的 API/用例边界再次判定权限。

这个边界由 [ADR-0001](../architecture/decisions/0001-unified-identity-and-authorization-boundary.md) 固化。
