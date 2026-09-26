# Hearth 30 天免登录 Implementation Plan

> 状态：历史实施计划。Remember-Me 代码和单元测试已存在；下方未勾选项保留原始计划记录，不代表当前待办或 staging evidence。当前发布步骤以 [`deploy/README.md`](../../deploy/README.md) 为准。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task with checkpoints.

**Goal:** 让 Hearth 通过 Spring Security 无状态签名 Remember-Me Cookie 提供 30 天免登录，并让 Career 等 OIDC 接入方在 Hearth Session 过期后自动恢复登录。

**Architecture:** Redis 继续保存 60 分钟闲置过期的短期 HTTP Session；Hearth 使用 `TokenBasedRememberMeServices` 生成仅属于 Hearth 域的 HttpOnly、Secure、SameSite=Lax 签名 Cookie。Cookie 不进入 MySQL、localStorage 或业务应用，签名密钥轮换可整体使旧 Cookie 失效。

**Tech Stack:** Spring Security 7 `TokenBasedRememberMeServices`、Spring Session Redis、React/Vite、Vitest、JUnit 5、Maven Wrapper。

**Spec:** `docs/superpowers/specs/2026-09-23-hearth-persistent-login-design.md`

## Global Constraints

- 不新增 Maven 模块。
- 不新增 `persistent_logins` 表或 JDBC Remember-Me 实现。
- 前端不使用 `localStorage`、`sessionStorage` 或 URL 保存登录凭据。
- Remember-Me 签名密钥必须通过 `HEARTH_REMEMBER_ME_KEY` 注入，staging/production 不得共用。
- HTTPS 环境必须设置 `HEARTH_REMEMBER_ME_COOKIE_SECURE=true`。
- 本机只运行断网单元测试；Redis、MySQL、OIDC 和浏览器跨进程验收在 staging 执行。

---

### Task 1: 固化 Remember-Me 配置与用户详情边界

**Files:**
- Modify: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/HearthPrincipal.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/HearthRememberMeUserDetailsService.java`
- Modify: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/PasswordLoginConfiguration.java`
- Test: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/security/HearthPrincipalTest.java`
- Create: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/security/HearthRememberMeUserDetailsServiceTest.java`

**Interfaces:**
- `HearthPrincipal` implements `UserDetails` while retaining `Serializable` and existing OIDC claims fields.
- `HearthRememberMeUserDetailsService implements UserDetailsService` and loads the local password hash plus `HearthPrincipal` from `IdentityCredentialPort` and `IdentityDirectoryPort`.

- [ ] **Step 1: Write failing tests** for `HearthPrincipal` UserDetails methods and lookup of an enabled local account.
- [ ] **Step 2: Run the focused adapter tests and verify the new assertions fail.**
- [ ] **Step 3: Implement the UserDetails contract and lookup service.** Disabled/missing credentials must throw `UsernameNotFoundException`; returned principal must retain the account display name/email and expose the password hash only through `getPassword()`.
- [ ] **Step 4: Run the focused tests and verify they pass without warnings.**
- [ ] **Step 5: Commit** with `feat: add hearth remember-me user details boundary`.

### Task 2: Connect Spring Security signed Remember-Me to API login

**Files:**
- Modify: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/SecurityConfig.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/HearthRememberMeServices.java`
- Modify: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/login/LoginController.java`
- Modify: `hearth-start/src/main/resources/application.yml`
- Modify: `deploy/docker-compose.staging.yml`
- Modify: `deploy/docker-compose.single-host.yml`
- Modify: `deploy/.env.example`
- Modify: `deploy/.env.staging.example`
- Test: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/login/LoginControllerTest.java`
- Create: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/security/HearthRememberMeServicesTest.java`
- Modify: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/security/SecurityRoutingTest.java`

**Interfaces:**
- `HearthRememberMeServices` extends `TokenBasedRememberMeServices` and exposes `onInteractiveLogin(request, response, authentication, rememberMe)`; true creates the signed token and false clears an old token.
- `LoginRequest` gains `boolean rememberMe` with JSON-compatible default false.

- [ ] **Step 1: Write failing tests** for 30-day TTL, cookie name/HttpOnly/SameSite, secure flag, selected login issuing a cookie, and unselected login clearing/not issuing one.
- [ ] **Step 2: Run the focused tests and verify they fail for the missing service/configuration.**
- [ ] **Step 3: Implement `HearthRememberMeServices` with `30 * 24 * 60 * 60` seconds, cookie name `hearth-remember-me`, SHA-256 default signing, configurable key/secure flag, and `SameSite=Lax`.**
- [ ] **Step 4: Configure `SecurityFilterChain.rememberMe(...)` with the same service so expired Redis Sessions can be auto-authenticated.**
- [ ] **Step 5: Call the service from `LoginController` after saving the authenticated context, based on `rememberMe`; preserve the existing saved-request/continue redirect logic.**
- [ ] **Step 6: Add required staging/production secret injection and fail-closed compose variables.**
- [ ] **Step 7: Run focused adapter tests and verify they pass without warnings.**
- [ ] **Step 8: Commit** with `feat: add hearth thirty-day remember-me`.

### Task 3: Add the login control and frontend regression coverage

**Files:**
- Modify: `hearth-start/src/main/frontend/main.jsx`
- Modify: `hearth-start/src/main/frontend/styles.css`
- Modify: `hearth-start/src/main/frontend/App.test.jsx`

- [ ] **Step 1: Write the failing Vitest assertion** for the visible “保持登录 30 天” checkbox and `rememberMe: true` payload when checked.
- [ ] **Step 2: Run the focused frontend test and verify it fails.**
- [ ] **Step 3: Add controlled checkbox state, accessible label, and payload field; keep unchecked as the default.**
- [ ] **Step 4: Add isolated styles that remain readable on desktop and mobile.**
- [ ] **Step 5: Run frontend tests and lint; verify coverage and no warnings.**
- [ ] **Step 6: Commit** with `feat: add hearth remember-me login option`.

### Task 4: Record the final architecture and local quality

**Files:**
- Modify: `docs/architecture/decisions/0011-persistent-login-credentials.md`
- Modify: `docs/architecture/decisions/README.md`
- Modify: `docs/security/authentication.md`
- Modify: `docs/architecture/overview.md`
- Modify: `AGENTS.md`
- Modify: `docs/releases/CHANGELOG.md`

- [ ] **Step 1: Document the bytedepth reference, benefits, limitations, Redis responsibility, key rotation, and why JDBC persistence is not used.**
- [ ] **Step 2: Run `bash scripts/run-local-quality.sh`.**
- [ ] **Step 3: Resolve every WARNING/WARN and test failure before deployment.**
- [ ] **Step 4: Commit** with `docs: record hearth remember-me architecture`.

### Task 5: Deploy and validate staging integration

**Files:**
- Modify only if deployment validation exposes a concrete configuration issue; otherwise no source changes.

- [ ] **Step 1: Deploy the branch with `bash deploy/deploy-staging.sh fix/hearth-login-csrf-race`.**
- [ ] **Step 2: Verify `/api/health`, the staging container status, and absence of `ERROR`/`WARN` in recent application logs.**
- [ ] **Step 3: Run Career staging integration and full E2E against `https://staging-career.bytedepth.cn`.**
- [ ] **Step 4: Verify the evidence commit remains bound to Career SHA `129a5b375ad07b1b96f6119ca68204c8641c806d`.**
- [ ] **Step 5: Manually validate the 30-day flow in staging using browser evidence: check the box, confirm `hearth-remember-me` has Max-Age 30 days, expire the short Session, revisit Career, and confirm no password prompt; then logout and confirm the Cookie is cleared.**
- [ ] **Step 6: Do not modify production.**
