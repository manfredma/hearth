# Remember-Me 首次 OIDC 授权修复

依据 ADR-0016 和 ByteDepth 2026-10-30 离线证据，仅调整授权链身份恢复时机。目标是两站无短期 Session、仅 Hearth 有有效 30 天 Cookie 时，首次授权直接生成 code；不能依赖重试或预热。

先以真实 Hearth 配置和 Spring FilterChainProxy 建立失败回归，再通过专用 HttpConfigurer 提前注册同一个框架恢复过滤器，沿用标准 provider/logout 与共享 context repository/session strategy。覆盖没有 Cookie、签名无效、过期、已有 Session、恢复后 Session 复用、PKCE 拒绝及 CSRF/退出边界。

修复不涉及模块、协议参数、Cookie 生命周期、数据库或线上配置。发布接入按 ByteDepth 当前模式：完整 PR head SHA → canonical release-platform → staging 集成/E2E → 业务验收 → 平台同 SHA 合并及同制品 production。人工放行遵守 ADR-0013，不将自动测试冒充用户验收。
