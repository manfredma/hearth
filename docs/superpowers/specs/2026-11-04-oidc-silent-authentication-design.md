# OIDC 静默认证设计

依据 ADR-0017。初始范围为 Hearth 修复、PR 和真实 staging 证据。2026-11-04 项目所有者追加授权：由 Agent 完成验收，staging 全部门禁通过后，通过 canonical release-platform 提交 acceptance 并将同一 SHA/制品晋级 production；必要时可配套修改 ByteDepth。现有 ByteDepth 标准入口与真实回调可用于本次协议互通验证，未扩大业务端功能。

在已有 Authorization Code + PKCE 请求中使用 scope=openid 和 prompt=none。仅精确匹配的授权端点请求越过外层 authenticated，协议前置验证和 Provider 不变。Session 和 Remember-Me 均须来自对应 Hearth 环境；需要 consent 时返回错误，不静默批准。未知 client、未登记 redirect、缺少 PKCE、非 S256、none 与 login/consent/select_account 组合必须拒绝。普通无 Cookie 请求仍跳登录页。

实现位置为 AuthorizationServerSecurityConfig 的 matcher；完整安全链测试扩展 RememberMeAuthorizationFilterChainTest 和 OidcLogoutFilterChainTest；真实测试位于 tests/e2e，复用隔离 test-slot 和平台不可变制品回执。错误断言先解析回调，仅比较布尔值，不在失败信息输出协议参数。

staging 使用 ByteDepth 正常授权入口生成请求，以独立上下文阻止自动跟随回调来检查错误，再走真实成功回调验证业务会话。Session-only 与 Cookie-only 分开；无效和过期 Cookie 只操作测试上下文。退出后按 Set-Cookie 清理，验证 Session 不再有效且静默失败。无状态签名 Cookie 的复制品撤销不在本修复能力内，不能把 Cookie 删除描述为服务器吊销。
