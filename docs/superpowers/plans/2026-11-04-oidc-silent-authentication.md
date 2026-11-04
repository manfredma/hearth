# OIDC Silent Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 支持 prompt=none 协议恢复和安全错误响应。
**Architecture:** 限定外层 matcher；复用现有前置校验、Provider、错误处理和提前 Remember-Me。
**Tech Stack:** Java 25, Wrapper 3.9.11, Boot 4.1.0, Security 7.1.0, mock Servlet chain, Playwright staging.
**Spec:** docs/superpowers/specs/2026-11-04-oidc-silent-authentication-design.md

## Global Constraints

- 仅 Hearth；不生产部署；不放宽协议检查；不输出认证工件。
- 本机仅断网 mock/fake，真实 OIDC 仅 staging。

## Review Focus

- 配置化授权路径及 GET/POST 匹配范围。
- 不可信 redirect_uri 绝不能成为错误跳转目标。
- Cookie-only 必须没有 Session，首请求不能预热。
- consent 不得自动批准，退出应由浏览器应用删除 Cookie。
- 静默失败保留 state 且不写 SavedRequest/循环进入登录。

### Task 1: 完整安全链与最小配置

- [x] 新增匿名 prompt=none 回归并见 RED：实际跳 /login。
- [x] 扩展 Session、Cookie、无效输入、consent、普通登录和退出回归。
- [x] 在 AuthorizationServerSecurityConfig 增加精确 matcher，见 GREEN。
- [x] Wrapper 断网测试与完整本地质量门禁，无 WARN。

### Task 2: 真实 staging 和交接

- [x] 扩展现有 Playwright 隔离测试，保留真实 ByteDepth 请求生成和回调，逐场景固定诊断。
- [x] 更新权威认证文档、CHANGELOG 和 ByteDepth 接入错误/回退说明。
- [ ] 独立审查，提交 PR；按平台版本准备同一候选，QUALITY/BUILD/DEPLOY_STAGING/VERIFY_STAGING。
- [ ] 核对 SHA/digest/清理回执，明确真实与未验证场景，不提交 acceptance。
