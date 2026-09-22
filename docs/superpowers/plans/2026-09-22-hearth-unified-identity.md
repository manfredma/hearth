# Hearth Unified Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 bytedepth 模板收敛为一个可运行的 Hearth 统一身份服务骨架，支持标准 OIDC 登录、应用访问管理和跨环境身份隔离。

**Architecture:** Hearth 保留 bytedepth 的 Java 25、Maven Wrapper、DDD 分层、知识库和发布质量门禁，但移除博客领域、搜索、Obsidian 同步和图片能力。Hearth 通过标准 OIDC 接入外部成熟身份提供商；Hearth 自己维护身份映射、应用注册、应用访问和审计，业务系统继续执行自身功能权限、资源权限和业务规则。

**Tech Stack:** Java 25, Maven Wrapper 3.9.11, Spring Boot 4.1, Spring Security OAuth2 Client/Resource Server, MySQL 8, Redis Session, React, Vite, Vitest, Playwright, Docker Compose.

**Spec:** `docs/superpowers/specs/2026-09-22-hearth-unified-identity-design.md`

## Global Constraints

- Maven 运行时固定为 3.9.11，所有 Maven 操作使用仓库 Wrapper；Java 运行时固定为 25。
- 不新增 Maven 模块，只将 bytedepth 的既有五层模块重命名为 `hearth-domain`、`hearth-app`、`hearth-infrastructure`、`hearth-adapter`、`hearth-start`。
- 所有跨进程测试只在 staging 执行；本机只运行断网、内存数据库和进程内 mock/fake 的单元测试。
- OIDC 使用 Authorization Code + PKCE；不自定义密码、Token 或登录协议。
- 身份主键使用 `issuer + subject`；不得使用用户名或邮箱自动合并账号。
- 生产与 staging 使用独立身份提供商 realm/实例、数据库、Client、密钥和 Session。
- 私人业务数据和长期 Token 不写入浏览器 `localStorage`；浏览器会话使用 `HttpOnly`、`Secure`、`SameSite` Cookie。
- Docker Compose 服务名必须带 `hearth-` 前缀，禁止使用通用 `app` 服务名。
- 所有运行时、配置和用户可见改动必须先更新 `docs/releases/CHANGELOG.md` 的非空 `## Unreleased` 条目。
- 每个业务逻辑分支必须有单元测试，改动范围覆盖率达到 100%；所有构建和测试输出中的 `WARNING`/`WARN` 必须定位并清零或中止流程。

---

### Task 1: 将模板转换为 Hearth 工程身份

**Files:**
- Rename: `bytedepth-domain/` -> `hearth-domain/`
- Rename: `bytedepth-app/` -> `hearth-app/`
- Rename: `bytedepth-infrastructure/` -> `hearth-infrastructure/`
- Rename: `bytedepth-adapter/` -> `hearth-adapter/`
- Rename: `bytedepth-start/` -> `hearth-start/`
- Modify: `pom.xml`
- Modify: all renamed module `pom.xml` files
- Modify: `Dockerfile`, `package.json`, `playwright.config.mjs`, `.github/workflows/quality.yml`
- Modify: `AGENTS.md`, `CLAUDE.md`, `docs/README.md`, `docs/releases/CHANGELOG.md`
- Create: `scripts/check-hearth-naming.sh`
- Test: `scripts/test-hearth-naming.sh`

**Interfaces:**
- Produces Maven coordinates under `manfred.hearth` and module artifacts `hearth-*`.
- Produces runtime prefix `HEARTH_` and Compose service prefix `hearth-`.
- Produces a naming guard that fails on bytedepth identifiers in runtime code, build files, deployment scripts, package metadata, and generated asset paths; references in the template migration note are allowed only in `docs/`.

- [ ] **Step 1: Write the failing naming test.**

  Add `scripts/test-hearth-naming.sh` that creates a temporary fixture containing an illegal `bytedepth-app` service and verifies `scripts/check-hearth-naming.sh` exits non-zero; add a legal Hearth fixture and verify it exits zero.

- [ ] **Step 2: Run the naming test and verify it fails.**

  Run `bash scripts/test-hearth-naming.sh`.

  Expected: FAIL because `scripts/check-hearth-naming.sh` does not exist.

- [ ] **Step 3: Rename the modules and coordinates.**

  Rename the five module directories with `git mv`; replace `manfred.bytedepth` with `manfred.hearth`, artifact IDs with `hearth-*`, application class packages with `manfred.hearth`, and root metadata with product name `Hearth`. Update Docker COPY paths and the package name to `hearth-frontend`.

- [ ] **Step 4: Remove the copied blog runtime entry points.**

  Keep the module boundaries and shared quality/deploy assets, but remove the copied blog controllers, article templates, Obsidian sync entry points, Meilisearch integration, GeoIP/image mounts, RSS/sitemap runtime routes, and blog-only frontend tests. Do not remove the generic Spring Security, Flyway/MySQL, Redis Session, test, deploy, and knowledge-base conventions that the Hearth service reuses.

- [ ] **Step 5: Implement the naming guard.**

  Make `scripts/check-hearth-naming.sh` scan tracked runtime, build, deployment, workflow, package, Docker and Compose files. Allow historical template references only inside the explicitly marked migration paragraph in `docs/architecture/decisions/README.md` and the Hearth design spec.

- [ ] **Step 6: Run the naming test and static checks.**

  Run `bash scripts/test-hearth-naming.sh`, `bash scripts/check-hearth-naming.sh`, and `git diff --check`.

- [ ] **Step 7: Commit the template conversion.**

  ```bash
  git add -A
  git commit -m "chore: convert bytedepth template to hearth"
  ```

### Task 2: Establish the minimal Hearth DDD modules and boot application

**Files:**
- Modify: `pom.xml`
- Modify: `hearth-domain/pom.xml`, `hearth-app/pom.xml`, `hearth-infrastructure/pom.xml`, `hearth-adapter/pom.xml`, `hearth-start/pom.xml`
- Create: `hearth-domain/src/main/java/manfred/hearth/domain/identity/IdentitySubject.java`
- Create: `hearth-domain/src/main/java/manfred/hearth/domain/application/ApplicationKey.java`
- Create: `hearth-domain/src/main/java/manfred/hearth/domain/application/ApplicationRegistration.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/identity/CurrentIdentity.java`
- Create: `hearth-start/src/main/java/manfred/hearth/HearthApplication.java`
- Create: `hearth-start/src/main/resources/application.yml`
- Test: `hearth-domain/src/test/java/manfred/hearth/domain/identity/IdentitySubjectTest.java`
- Test: `hearth-domain/src/test/java/manfred/hearth/domain/application/ApplicationRegistrationTest.java`
- Test: `hearth-start/src/test/java/manfred/hearth/HearthApplicationTest.java`

**Interfaces:**
- `IdentitySubject(String issuer, String subject)` rejects blank values and exposes immutable accessors.
- `ApplicationKey(String value)` accepts lowercase names separated by `-` and rejects invalid keys.
- `ApplicationRegistration(ApplicationKey key, String displayName, Set<String> redirectUris)` validates a non-empty name and HTTPS redirect URIs except for the explicit local development URI `http://localhost`.

- [ ] **Step 1: Write domain validation tests.**

  Cover blank issuer/subject, valid subject, invalid application key, blank display name, non-HTTPS production redirect URI, and the localhost development exception.

- [ ] **Step 2: Run the focused tests to verify failure.**

  Run `./mvnw -pl hearth-domain -Dtest=IdentitySubjectTest,ApplicationRegistrationTest test`.

  Expected: FAIL because the domain types do not exist.

- [ ] **Step 3: Implement the immutable domain types.**

  Use Java records or final value objects with canonical validation. Do not add a framework dependency to `hearth-domain`.

- [ ] **Step 4: Replace the boot entry point and configuration.**

  Create `HearthApplication` and a minimal `application.yml` with environment-backed MySQL, Redis Session, OIDC issuer, and client settings. Fail closed when production settings are missing; keep a test profile with in-memory substitutes.

- [ ] **Step 5: Run module tests and architecture checks.**

  Run `./mvnw -pl hearth-domain,hearth-start -Dtest='**/*Test' test` and the existing ArchUnit test after renaming its package to `manfred.hearth`.

- [ ] **Step 6: Commit the boot skeleton.**

  ```bash
  git add pom.xml hearth-domain hearth-app hearth-infrastructure hearth-adapter hearth-start
  git commit -m "feat: add hearth domain and boot skeleton"
  ```

### Task 3: Add the identity directory and application-access schema

**Files:**
- Create: `hearth-domain/src/main/java/manfred/hearth/domain/identity/IdentityAccount.java`
- Create: `hearth-domain/src/main/java/manfred/hearth/domain/access/ApplicationAccess.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/identity/IdentityDirectoryPort.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/access/ApplicationAccessPort.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/access/GrantApplicationAccessCmd.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/access/GrantApplicationAccessCmdExe.java`
- Create: `hearth-infrastructure/src/main/resources/db/migration/V1__create_hearth_identity_tables.sql`
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/identity/MySqlIdentityDirectory.java`
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/access/MySqlApplicationAccessRepository.java`
- Test: `hearth-app/src/test/java/manfred/hearth/app/access/GrantApplicationAccessCmdExeTest.java`
- Test: `hearth-infrastructure/src/test/java/manfred/hearth/infrastructure/identity/IdentityDirectoryContractTest.java`
- Modify: `hearth-start/src/test/java/manfred/hearth/MigrationScriptsTest.java`

**Interfaces:**
- `IdentityDirectoryPort.findOrCreate(IdentitySubject subject, IdentityProfile profile): IdentityAccount`.
- `ApplicationAccessPort.grant(UUID userId, ApplicationKey application, String roleKey): ApplicationAccess`.
- `ApplicationAccessPort.hasAccess(UUID userId, ApplicationKey application): boolean`.
- The schema uses `user_identity(issuer, subject)` as a unique key, `application`, `application_access`, and `audit_event`; it stores no password hash and no business resource ACL.

- [ ] **Step 1: Write the application-service tests.**

  Test first grant, duplicate grant idempotency, missing identity, invalid role key, and access lookup. Use in-memory fakes only.

- [ ] **Step 2: Run the tests to verify failure.**

  Run `./mvnw -pl hearth-app -Dtest=GrantApplicationAccessCmdExeTest test`.

  Expected: FAIL because the command and ports do not exist.

- [ ] **Step 3: Implement the domain and application service.**

  Keep `roleKey` namespaced, such as `release:operator`; reject blank or unnamespaced keys. The service must not interpret release, career, article, diary, or candidate rules.

- [ ] **Step 4: Write the Flyway migration and MySQL adapters.**

  Create tables with UUID primary keys, UTC timestamps, unique `(issuer, subject)`, unique `(user_id, application_id, role_key)`, foreign keys, and indexes for subject lookup and application access lookup. Use parameterized MyBatis statements or the existing repository pattern; never build SQL from role or application input.

- [ ] **Step 5: Run database-independent adapter tests and migration static checks.**

  Run the fake-backed adapter contract tests locally and `./mvnw -pl hearth-start -Dtest=MigrationScriptsTest test`. The real MySQL migration test belongs to staging integration.

- [ ] **Step 6: Commit the identity data layer.**

  ```bash
  git add hearth-domain hearth-app hearth-infrastructure hearth-start/src/test
  git commit -m "feat: add hearth identity directory"
  ```

### Task 4: Integrate OIDC login and application session boundaries

**Files:**
- Modify: `hearth-adapter/pom.xml`, `hearth-start/pom.xml`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/SecurityConfig.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/OidcIdentityMapper.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/security/CurrentIdentityArgumentResolver.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/identity/SessionController.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/identity/LogoutController.java`
- Modify: `hearth-start/src/main/resources/application.yml`
- Test: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/security/SecurityRoutingTest.java`
- Test: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/security/OidcIdentityMapperTest.java`
- Test: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/identity/SessionControllerTest.java`

**Interfaces:**
- `GET /oauth2/authorization/hearth` starts the configured OIDC flow.
- `GET /login/oauth2/code/hearth` is the Spring Security callback.
- `GET /api/session` returns `{ authenticated, userId, displayName, applications }` and never returns access or refresh tokens.
- `POST /logout` invalidates the local session and initiates the configured OIDC logout flow.
- `OidcIdentityMapper.map(OidcUser): IdentitySubject` uses the verified `iss` and `sub` claims and rejects missing claims.

- [ ] **Step 1: Write security routing tests.**

  Verify unauthenticated `/api/session` returns 401, the OIDC authorization endpoint is reachable, protected API routes require authentication, logout is POST-only, and no password-login route exists.

- [ ] **Step 2: Run focused security tests to verify failure.**

  Run `./mvnw -pl hearth-adapter -Dtest=SecurityRoutingTest,OidcIdentityMapperTest,SessionControllerTest test`.

  Expected: FAIL because the Hearth security configuration does not exist.

- [ ] **Step 3: Add Spring Security OIDC dependencies and configuration.**

  Use `spring-boot-starter-oauth2-client`, `spring-boot-starter-oauth2-resource-server`, and Spring Session Redis. Configure issuer discovery from `HEARTH_OIDC_ISSUER_URI`, client ID/secret from environment, Authorization Code + PKCE, and strict redirect URI validation.

- [ ] **Step 4: Implement identity mapping and local session creation.**

  On successful OIDC login, call `IdentityDirectoryPort.findOrCreate`, store only the stable identity and display profile in the local session, and set `HttpOnly`, `Secure`, and `SameSite=Lax` cookie attributes. Do not persist tokens in localStorage or return them from the session API.

- [ ] **Step 5: Implement logout and session invalidation.**

  Invalidate the local session first, then redirect to the provider's RP-initiated logout endpoint when configured. Treat missing provider logout configuration as a safe local logout, not as a successful global logout claim.

- [ ] **Step 6: Run tests and commit the OIDC boundary.**

  Run the focused security tests, `./mvnw -pl hearth-adapter,hearth-start test`, and `git diff --check`; then commit:

  ```bash
  git add hearth-adapter hearth-start/pom.xml hearth-start/src/main/resources/application.yml
  git commit -m "feat: add hearth oidc session boundary"
  ```

### Task 5: Add application registry and React administration shell

**Files:**
- Modify: `package.json`, `package-lock.json`
- Create: `hearth-start/src/main/frontend/index.html`
- Create: `hearth-start/src/main/frontend/src/main.jsx`
- Create: `hearth-start/src/main/frontend/src/app/App.jsx`
- Create: `hearth-start/src/main/frontend/src/app/session.js`
- Create: `hearth-start/src/main/frontend/src/styles/tokens.css`
- Create: `hearth-start/src/main/frontend/src/styles/app.css`
- Create: `hearth-start/src/main/frontend/src/app/App.test.jsx`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/application/ApplicationController.java`
- Test: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/application/ApplicationControllerTest.java`
- Create: `hearth-start/src/main/resources/static/index.html`
- Create: `vite.config.mjs`

**Interfaces:**
- `GET /api/applications` returns registered applications visible to the current user.
- `GET /api/applications/{applicationKey}` returns display metadata and login URL, never client secrets.
- `session.js` calls `/api/session` with cookies and keeps session state in memory only.

- [ ] **Step 1: Add React test dependencies and write the shell test.**

  Add pinned React, React DOM, Vite, and testing-library dependencies. Test loading, authenticated session rendering, unauthenticated redirect affordance, and API failure rendering with a mocked `fetch`.

- [ ] **Step 2: Run frontend setup and test to verify failure.**

  Run `npm ci --ignore-scripts --no-audit --no-fund` followed by `npm test -- --run hearth-start/src/main/frontend/src/app/App.test.jsx`.

  Expected: FAIL because the React source files do not exist.

- [ ] **Step 3: Implement the minimal React shell.**

  Render Hearth branding, current user, available applications, login/logout controls, and a clear error state. Use same-origin fetch with credentials; do not use localStorage, IndexedDB, or client-side private-data persistence.

- [ ] **Step 4: Implement application registry endpoints.**

  Add controller tests for authenticated access, empty registry, application metadata, missing application, and secret redaction. Delegate lookup to `ApplicationAccessPort` and `ApplicationRegistrationRepository` rather than querying the database from the controller.

- [ ] **Step 5: Configure the frontend build output.**

  Build into `hearth-start/src/main/resources/static/` and configure Spring fallback routing for the React shell. Keep the application-independent CSS in the shell's own stylesheet and add an asset ownership check for the static output.

- [ ] **Step 6: Run frontend and backend tests and commit.**

  Run `npm ci --ignore-scripts --no-audit --no-fund`, `npm test`, `npm run lint`, and the focused Maven adapter tests. Commit:

  ```bash
  git add package.json package-lock.json vite.config.mjs hearth-start/src/main/frontend hearth-start/src/main/resources/static hearth-adapter
  git commit -m "feat: add hearth application console"
  ```

### Task 6: Replace deployment assets with isolated Hearth environments

**Files:**
- Modify: `Dockerfile`
- Create: `deploy/docker-compose.single-host.yml`
- Create: `deploy/docker-compose.staging.yml`
- Create: `deploy/.env.example`
- Create: `deploy/.env.staging.example`
- Modify: `deploy/README.md`
- Create: `deploy/check-environment-isolation.sh`
- Test: `scripts/test-deploy-hearth-config.sh`
- Modify: `scripts/check-staging-checklist.sh`, `scripts/test-staging-checklist.sh`, `scripts/run-local-quality.sh`

**Interfaces:**
- Runtime environment variables use `HEARTH_` and `SPRING_` prefixes only.
- Compose services are `hearth-app`, `hearth-mysql`, and `hearth-redis`; no `app` alias is defined.
- `deploy/check-environment-isolation.sh` rejects production issuer/database/Redis values in staging configuration and rejects missing OIDC issuer, client, cookie, or database secrets.

- [ ] **Step 1: Write deployment configuration tests.**

  Add fixtures for valid staging, missing staging issuer, staging pointing to production issuer, generic `app` service, and shared production database URL. Assert the checker fails closed for each invalid fixture.

- [ ] **Step 2: Run deployment tests to verify failure.**

  Run `bash scripts/test-deploy-hearth-config.sh`.

  Expected: FAIL because the Hearth deployment checker and Compose files do not exist.

- [ ] **Step 3: Create the minimal Compose topology.**

  Define MySQL and Redis with persistent named volumes, the app with the `hearth-app` service name, and required environment variables. Do not include Meilisearch, image mounts, Obsidian mounts, or generic shared service names.

- [ ] **Step 4: Add environment isolation checks and documentation.**

  Make staging require a distinct issuer, database name, Redis namespace, cookie name, and Client ID from production. Document that a future Keycloak/ZITADEL realm must be provisioned separately per environment and that credentials are injected by the deployment host, never committed.

- [ ] **Step 5: Build and test the container locally.**

  Run `bash scripts/test-deploy-hearth-config.sh`, `docker compose --env-file deploy/.env.example -f deploy/docker-compose.single-host.yml config`, and the Docker build with the repository's fixed Maven 25 image. Any warning or configuration error stops the task.

- [ ] **Step 6: Commit the isolated deployment topology.**

  ```bash
  git add Dockerfile deploy scripts
  git commit -m "feat: add isolated hearth deployment topology"
  ```

### Task 7: Complete documentation, quality gates, and staging handoff

**Files:**
- Modify: `AGENTS.md`, `CLAUDE.md`, `docs/README.md`
- Create: `docs/architecture/overview.md`
- Create: `docs/security/authentication.md`
- Create: `docs/security/application-access.md`
- Modify: `docs/releases/CHANGELOG.md`
- Modify: `scripts/check-changelog-order.sh`, `scripts/check-staging-changelog-change.sh`
- Test: `scripts/test-hearth-documentation.sh`

**Interfaces:**
- Documentation names Hearth as the project and links to the approved spec and ADRs.
- `docs/security/authentication.md` defines OIDC identity mapping, cookie behavior, logout, and token handling.
- `docs/security/application-access.md` defines the central-vs-business authorization boundary with examples for all five consuming systems.

- [ ] **Step 1: Write documentation checks.**

  Verify the project name is Hearth in operational docs, the four ADRs are indexed, the Unreleased changelog entry is non-empty, and no document instructs agents to store private data in browser storage or share production and staging identity data.

- [ ] **Step 2: Run the documentation test to verify failure.**

  Run `bash scripts/test-hearth-documentation.sh`.

  Expected: FAIL while copied bytedepth operational documents and missing Hearth security guides remain.

- [ ] **Step 3: Update operational documentation and Changelog.**

  Replace template-specific commands and service names with Hearth equivalents, record the initial identity-service change under `## Unreleased` with `### Added` and `### Security`, and link the approved spec and ADR index.

- [ ] **Step 4: Run the complete local quality gate.**

  Run in this order:

  ```bash
  npm ci --ignore-scripts --no-audit --no-fund
  ./mvnw clean install -DskipTests -Dsort.skip=true
  ./mvnw test
  npm test
  npm run lint
  bash scripts/check-hearth-naming.sh
  bash scripts/test-hearth-documentation.sh
  bash scripts/run-local-quality.sh
  ```

  Treat every `WARNING`/`WARN` as a failure requiring remediation.

- [ ] **Step 5: Run staging-only integration preparation.**

  Do not run MySQL, Redis, Flyway, Docker, or external OIDC-provider integration tests locally. Add the staging commands and explicit credential/issuer injection to `deploy/README.md`; the staging runner must record the deployed full SHA and produce integration evidence only after all tests and warning checks pass.

- [ ] **Step 6: Commit the documentation and quality gate.**

  ```bash
  git add AGENTS.md CLAUDE.md docs scripts
  git commit -m "docs: define hearth operations and security boundaries"
  ```

- [ ] **Step 7: Prepare the staging handoff.**

  Run `git status --short`, `bash scripts/check-staging-checklist.sh`, and the complete local quality gate again. Report the branch, commit SHA, remaining external prerequisite (OIDC provider provisioning), and exact staging deployment command without claiming staging success before the remote run completes.

## Self-review

- Spec goal and non-goals are covered by Tasks 1–5.
- OIDC, `issuer + subject`, Cookie-only browser session, and no localStorage are covered by Tasks 2–5.
- MySQL identity storage and no password hashes are covered by Task 3.
- Production/staging isolation and prefixed services are covered by Task 6.
- Naming, operational documentation, Changelog, warning policy, and staging handoff are covered by Task 7.
- No task selects Keycloak or ZITADEL prematurely; Task 6 only creates a provider-neutral configuration boundary.
