# Remember-Me OIDC 顺序修复 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 仅持久 Cookie 时首次授权成功，并通过当前 release-platform 发布流程验证。
**Architecture:** 授权链使用框架恢复过滤器，在预校验捕获 principal 前执行，标准 Web 链不变。
**Tech Stack:** Java 25、Maven Wrapper 3.9.11、Spring Security 7.1.0。
**Spec:** docs/superpowers/specs/2026-10-30-remember-me-oidc-order-design.md

## Global Constraints

本机仅进程内单元测试；保持 PKCE/state/nonce/CSRF/退出与环境隔离；不 SSH、不执行旧发布脚本。

## Review Focus

- 没有持久 Cookie 时仍跳转登录。
- 无效及过期 Cookie 不得建立认证。
- 已有 Session 不被持久 Cookie 覆盖。
- 恢复后的 Session 可独立复用；session fixation 防护有效。
- 本地与 RP logout 后不能依靠已清除 Cookie 重新登录。

### Task 1: 实际安全链回归及最小修复

**Files:** AuthorizationServerSecurityConfig.java、AuthorizationServerRememberMeConfigurer.java、RememberMeAuthorizationFilterChainTest.java。
**Interfaces:** 使用现有 HearthRememberMeServices；共享 AuthenticationManager、SecurityContextRepository、SessionAuthenticationStrategy。

- [x] 建立进程内上下文，以仅持久 Cookie 的首次 /oauth2/authorize 请求断言 code。
- [x] 使用 Wrapper 离线执行，确认失败是 invalid_request/principal。
- [x] 实现提前恢复，覆盖无/无效/过期 Cookie、Session 优先/复用、PKCE 与退出。
- [x] 更新认证文档、ADR 索引、Changelog；执行完整本地质量门禁和独立审查。
- [ ] 提交、推送、创建 PR。

### Task 2: 当前发布流程与 staging 验证

**Files:** docs/engineering/unified-release-pipeline.md、deploy/README.md、docs/engineering/git-workflow.md。

- [ ] 核对 ByteDepth 接入与 canonical Agent 手册，纠正旧合并顺序。
- [ ] 按当前 PR head 完整 SHA 创建/复用候选，核对项目绑定及制品摘要。
- [ ] 跟踪 QUALITY/BUILD/staging/integration/E2E，保留平台回执；有阻塞则定位。
- [ ] 所有技术证据齐全后按 ADR-0013 请求最终业务放行；获准后由平台合并和生产晋级，清理 worktree。

## 验证记录

实际链首次授权回归在修复前返回 invalid_request/principal，修复后通过。2026-10-30 完整本地质量门禁通过，变更 Java 类行/分支/方法覆盖率均 100%。独立审查无新正确性发现。发布准备兼容门禁先增加失败用例，再修复；存在的实际发布前置差异是 staging binding 缺失及 GitHub 默认分支仍为历史 docs 分支，按 canonical API 核对。
