# Hearth Self-Hosted OIDC Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Hearth 改造成自建、轻量、可替换协议内核的 OIDC Provider，让 Daylilt、Career、Toolbox、Release 和 ByteDepth 直接信任 Hearth，而不依赖第三方身份提供商。

**Architecture:** Hearth 自己拥有用户、密码、Session、应用 Client、Token 和审计；Spring Authorization Server 只在 `hearth-adapter` 提供 OAuth/OIDC 协议端点。领域层和应用层不依赖 Spring Authorization Server 类型，MySQL 保存长期身份与授权数据，Redis 保存 Session、限流和短期状态。

**Tech Stack:** Java 25, Maven Wrapper 3.9.11, Spring Boot 4.1, Spring Security 7, Spring Authorization Server, MySQL 8, Redis Session, React, Vite, Vitest.

**Spec:** `docs/superpowers/specs/2026-09-23-hearth-self-hosted-oidc-provider-design.md`

## Global Constraints

- 不新增 Maven 模块；继续使用 `hearth-domain`、`hearth-app`、`hearth-infrastructure`、`hearth-adapter`、`hearth-start`。
- 所有 Maven 命令使用仓库 Wrapper、Maven 3.9.11 和 Java 25。
- 本机只运行无独立进程的单元测试；MySQL、Redis、Flyway、容器、浏览器和完整 OAuth 流程在 staging 验证。
- 第一阶段只实现单租户、用户名/邮箱密码、Authorization Code + PKCE、OIDC、应用 Client、Session、基础审计；不实现上游身份提供商、社交登录、MFA、多租户、LDAP、Device Authorization 和动态 Client 注册。
- 禁止自行实现密码学算法；密码哈希、JWT、JWK、随机数和协议状态使用成熟库。
- `issuer + subject` 是稳定身份键；邮箱和用户名不能自动合并账号。
- Refresh Token、签名私钥、Session 和私人数据不得写入浏览器 localStorage/sessionStorage。
- staging 与 production 使用独立数据库、Redis namespace、issuer、Client 和签名密钥。
- 所有构建、测试、静态分析和部署输出中的 `WARNING`/`WARN` 必须定位并清零或中止。
- 所有运行时和配置变更必须先更新 `docs/releases/CHANGELOG.md` 的 `## Unreleased`。

---

### Task 1: Replace external OIDC client decision with self-hosted provider boundary

**Files:**
- Modify: `hearth-adapter/pom.xml`
- Modify: `hearth-start/pom.xml`
- Modify: `hearth-start/src/main/resources/application.yml`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/oauth/OidcProviderConfiguration.java`
- Create: `hearth-adapter/src/test/java/manfred/hearth/adapter/oauth/OidcProviderConfigurationTest.java`
- Modify: `docs/security/authentication.md`
- Modify: `docs/architecture/routes.md`

**Interfaces:**
- `GET /.well-known/openid-configuration` publishes Hearth endpoints.
- `GET /oauth2/jwks` publishes active verification keys.
- `HearthAuthorizationServerProperties(issuer, signingKeyLocation, accessTokenTtl, refreshTokenTtl)` is configuration-only and has no domain dependency.

- [ ] **Step 1: Write the failing configuration test.**

  Assert the provider requires an HTTPS issuer outside the test profile, rejects a missing signing-key source, and exposes an explicit short-lived access-token configuration.

- [ ] **Step 2: Run the focused test to verify failure.**

  Run `./mvnw -pl hearth-adapter -Dtest=OidcProviderConfigurationTest test`.

  Expected: FAIL because the provider configuration does not exist.

- [ ] **Step 3: Replace the client-only dependencies with the authorization-server dependency.**

  Add the pinned Spring Authorization Server dependency; remove the unused external-provider client/resource-server path from the active configuration. Do not add a separate provider service or Maven module.

- [ ] **Step 4: Implement provider configuration and endpoint metadata.**

  Configure the standard authorization, token, JWK, UserInfo, revocation, and OIDC logout endpoints with a fixed HTTPS issuer. Keep provider-specific types inside the adapter.

- [ ] **Step 5: Run the focused test and static checks.**

  Run the focused Maven test and `git diff --check`; treat all warnings as failures.

- [ ] **Step 6: Commit the protocol boundary.**

  ```bash
  git add hearth-adapter hearth-start docs/security/authentication.md docs/architecture/routes.md
  git commit -m "feat: define hearth oidc provider boundary"
  ```

### Task 2: Add local user credentials and password login

**Files:**
- Modify: `hearth-domain/src/main/java/manfred/hearth/domain/identity/IdentityAccount.java`
- Create: `hearth-domain/src/main/java/manfred/hearth/domain/identity/PasswordCredential.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/identity/IdentityCredentialPort.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/identity/PasswordLoginService.java`
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/identity/MySqlIdentityCredentialRepository.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/login/LoginController.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/login/LoginRateLimitFilter.java`
- Create: `hearth-domain/src/test/java/manfred/hearth/domain/identity/PasswordCredentialTest.java`
- Create: `hearth-app/src/test/java/manfred/hearth/app/identity/PasswordLoginServiceTest.java`
- Create: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/login/LoginControllerTest.java`
- Create: `hearth-start/src/main/resources/db/migration/V2__add_local_credentials.sql`

**Interfaces:**
- `PasswordLoginService.authenticate(String login, CharSequence rawPassword): AuthenticatedIdentity`.
- `IdentityCredentialPort.findByLogin(String login): Optional<CredentialRecord>`.
- Password hashes are never returned by controllers, session APIs, or OIDC claims.

- [ ] **Step 1: Write domain and application failing tests.**

  Cover blank login, disabled account, wrong password, successful password verification, and lockout after the configured failure threshold. Use an in-memory credential fake and Spring `PasswordEncoder` in the test.

- [ ] **Step 2: Run tests to verify failure.**

  Run `./mvnw -pl hearth-domain,hearth-app -am -Dtest=PasswordCredentialTest,PasswordLoginServiceTest test`.

- [ ] **Step 3: Implement credential validation and password hashing.**

  Use Argon2id when supported by the runtime; otherwise use BCrypt with an explicit work factor. Store only the hash and credential metadata. Do not implement hashing manually.

- [ ] **Step 4: Add migration and MySQL repository.**

  Add login identifier, password hash, enabled state, failed-attempt counter, lock-until timestamp, created/updated timestamps, and uniqueness constraints. Keep credential data separate from `user_identity` so OIDC subject mapping remains stable.

- [ ] **Step 5: Implement the login endpoint and rate limit.**

  Use server-side Session and CSRF protection; return a generic authentication error for unknown user and wrong password; record an audit event without recording raw credentials.

- [ ] **Step 6: Run tests and commit.**

  Run focused tests, `./mvnw verify -Dsort.skip=true`, and `git diff --check`, then commit:

  ```bash
  git add hearth-domain hearth-app hearth-infrastructure hearth-adapter hearth-start/src/main/resources/db/migration
  git commit -m "feat: add hearth local credentials"
  ```

### Task 3: Implement OAuth/OIDC authorization-code flow

**Files:**
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/oauth/AuthorizationServerSecurityConfig.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/oauth/HearthUserConsentService.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/oauth/HearthOidcUserInfoService.java`
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/oauth/MySqlRegisteredClientRepository.java`
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/oauth/MySqlOAuth2AuthorizationService.java`
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/oauth/MySqlOAuth2AuthorizationConsentService.java`
- Create: `hearth-start/src/main/resources/db/migration/V3__add_oauth_authorization_tables.sql`
- Create: `hearth-adapter/src/test/java/manfred/hearth/adapter/oauth/AuthorizationCodeFlowContractTest.java`
- Create: `hearth-infrastructure/src/test/java/manfred/hearth/infrastructure/oauth/OAuthPersistenceMappingTest.java`

**Interfaces:**
- Registered clients are loaded through `RegisteredClientRepository`; no controller directly queries OAuth tables.
- Authorization state is persisted through `OAuth2AuthorizationService`; in-memory authorization storage is test-only.
- The OIDC UserInfo response includes only scopes explicitly granted by the Client and current user.

- [ ] **Step 1: Write failing contract tests.**

  Cover authorization request validation, exact redirect URI matching, state preservation, PKCE challenge verification, token exchange, invalid/expired code rejection, audience validation, and scope-limited UserInfo.

- [ ] **Step 2: Run the contract tests to verify failure.**

  Run `./mvnw -pl hearth-adapter,hearth-infrastructure -am -Dtest=AuthorizationCodeFlowContractTest,OAuthPersistenceMappingTest test`.

- [ ] **Step 3: Configure Spring Authorization Server.**

  Register the authorization-server filter chain before the application chain. Enable OIDC provider configuration, UserInfo, logout, token revocation, and JWK endpoints; allow only Authorization Code + PKCE for first-party Clients.

- [ ] **Step 4: Implement Client and authorization persistence.**

  Persist registered clients, authorization codes, access/refresh tokens, consents, timestamps, scopes, and code challenge metadata with encrypted-at-rest secret handling where required. Never log token values.

- [ ] **Step 5: Implement claims and identity mapping.**

  Generate `sub` from the Hearth identity UUID, keep `iss` equal to the configured issuer, include `aud`, `nonce`, `auth_time`, and only approved `profile`/`email` claims.

- [ ] **Step 6: Run focused tests and commit.**

  Run the contract tests and module verification, then commit:

  ```bash
  git add hearth-adapter hearth-infrastructure hearth-start/src/main/resources/db/migration
  git commit -m "feat: implement hearth authorization code flow"
  ```

### Task 4: Add application Client management and admin APIs

**Files:**
- Modify: `hearth-domain/src/main/java/manfred/hearth/domain/application/ApplicationRegistration.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/application/RegisterOAuthClientCmd.java`
- Create: `hearth-app/src/main/java/manfred/hearth/app/application/RevokeOAuthClientCmd.java`
- Modify: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/application/ApplicationController.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/web/application/OAuthClientController.java`
- Create: `hearth-adapter/src/test/java/manfred/hearth/adapter/web/application/OAuthClientControllerTest.java`
- Modify: `hearth-start/src/main/resources/db/migration/V3__add_oauth_authorization_tables.sql`

**Interfaces:**
- `POST /api/admin/oauth-clients` creates a Client and returns the secret exactly once.
- `GET /api/admin/oauth-clients` redacts secrets and lists scopes/redirect URIs.
- `DELETE /api/admin/oauth-clients/{clientId}` revokes a Client and its active grants.

- [ ] **Step 1: Write failing controller and use-case tests.**

  Cover creation, exact redirect URI validation, duplicate client key rejection, one-time secret response, redaction, and revocation.

- [ ] **Step 2: Implement Client management behind application ports.**

  Keep Client identifiers separate from application keys; never accept arbitrary redirect URIs from an unauthenticated request.

- [ ] **Step 3: Add admin authorization and audit events.**

  Only an authenticated Hearth administrator may create/revoke Clients. Record the actor, application, operation, and result, never secrets.

- [ ] **Step 4: Run focused tests and commit.**

  Run adapter/application tests and changed coverage, then commit:

  ```bash
  git add hearth-domain hearth-app hearth-adapter hearth-start/src/main/resources/db/migration
  git commit -m "feat: add hearth oauth client management"
  ```

### Task 5: Replace the React shell with a real login and consent experience

**Files:**
- Modify: `hearth-start/src/main/frontend/main.jsx`
- Modify: `hearth-start/src/main/frontend/App.test.jsx`
- Modify: `hearth-start/src/main/frontend/styles.css`
- Create: `hearth-start/src/main/frontend/LoginPreview.jsx`
- Create: `hearth-start/src/main/frontend/ConsentPreview.jsx`

**Interfaces:**
- The browser uses the Hearth Session Cookie and never receives a Refresh Token in JavaScript.
- Login UI displays generic authentication errors and does not reveal whether an account exists.
- Consent UI shows Client name, redirect origin, and requested scopes before approval.

- [ ] **Step 1: Add failing frontend tests.**

  Cover login form states, generic error state, consent scope rendering, cancel behavior, mobile layout, and absence of localStorage/sessionStorage writes.

- [ ] **Step 2: Implement login/consent pages and navigation.**

  Keep the existing Hearth visual language, provide visible focus/error states, and make all actions usable on mobile.

- [ ] **Step 3: Run frontend tests, lint and build.**

  Run `npm ci --ignore-scripts --no-audit --no-fund`, `npm test`, `npm run lint`, and `npm run build`.

- [ ] **Step 4: Commit the authentication UI.**

  ```bash
  git add hearth-start/src/main/frontend
  git commit -m "feat: add hearth login and consent experience"
  ```

### Task 6: Add key rotation, environment configuration, and audit safety

**Files:**
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/oauth/SigningKeyRepository.java`
- Create: `hearth-infrastructure/src/main/java/manfred/hearth/infrastructure/oauth/MySqlSigningKeyRepository.java`
- Create: `hearth-adapter/src/main/java/manfred/hearth/adapter/oauth/SigningKeyConfiguration.java`
- Modify: `hearth-start/src/main/resources/application.yml`
- Modify: `deploy/docker-compose.single-host.yml`
- Modify: `deploy/docker-compose.staging.yml`
- Modify: `deploy/.env.example`, `deploy/.env.staging.example`
- Create: `hearth-start/src/main/resources/db/migration/V4__add_signing_keys_and_audit_indexes.sql`
- Create: `hearth-adapter/src/test/java/manfred/hearth/adapter/oauth/SigningKeyConfigurationTest.java`
- Modify: `scripts/check-hearth-documentation.sh`, `scripts/test-deploy-hearth-config.sh`

**Interfaces:**
- `SigningKeyRepository.activeSigningKeys(Instant now): List<SigningKeyRecord>` returns current and overlap-window public keys.
- Environment configuration refuses production startup without an issuer, key source, database password, and Redis password.

- [ ] **Step 1: Write failing key/configuration tests.**

  Cover no private key in logs, active/retiring key selection, production missing-secret failure, staging namespace separation, and invalid issuer rejection.

- [ ] **Step 2: Implement durable signing-key metadata and rotation.**

  Store encrypted private material or an explicitly mounted root-only key source, publish only public JWKs, rotate without immediately invalidating still-valid tokens, and audit every rotation.

- [ ] **Step 3: Update Compose and documentation contracts.**

  Add issuer, key source, token TTL, and environment-specific values; ensure staging and production cannot share key paths or Redis namespaces.

- [ ] **Step 4: Run configuration checks and commit.**

  Run deployment/documentation contracts and changed coverage, then commit:

  ```bash
  git add hearth-infrastructure hearth-adapter hearth-start deploy scripts docs
  git commit -m "feat: add hearth signing key lifecycle"
  ```

### Task 7: Stage the provider with end-to-end evidence

**Files:**
- Modify: `deploy/README.md`
- Create: `deploy/deploy-staging.sh`
- Create: `deploy/run-staging-oidc-smoke.sh`
- Create: `scripts/test-deploy-staging.sh`
- Modify: `scripts/check-staging-checklist.sh`
- Modify: `docs/releases/CHANGELOG.md`

**Interfaces:**
- `deploy/deploy-staging.sh <named-ref>` validates the remote origin, full SHA, environment file, issuer, key source, Compose configuration, and complete service rollout before returning success.
- `deploy/run-staging-oidc-smoke.sh` runs from the staging host and verifies Discovery, JWKS, authorization redirect, PKCE exchange, logout, and a second-app SSO path without logging secrets or tokens.

- [ ] **Step 1: Write deployment script contract tests.**

  Reject missing full SHA, generic service names, production database paths, missing issuer, missing signing-key configuration, and unbound staging host configuration.

- [ ] **Step 2: Implement staging deployment and smoke runner.**

  Use the existing SSH/Compose conventions, rebuild the complete Hearth stack, record commit-bound evidence, and fail closed on any warning or health failure.

- [ ] **Step 3: Run local script/configuration checks.**

  Run `bash scripts/test-deploy-staging.sh`, `bash scripts/check-staging-checklist.sh`, `docker compose ... config --quiet`, and the full local quality gate. Do not use local services as staging evidence.

- [ ] **Step 4: Deploy and verify on staging.**

  Deploy the named PR branch to 124, run the OIDC smoke flow on staging, verify the `issuer`/JWKS/PKCE contract and the HTTPS UI, then record integration and E2E evidence bound to the exact full SHA.

- [ ] **Step 5: Commit the staging provider handoff.**

  ```bash
  git add deploy scripts docs/releases/CHANGELOG.md
  git commit -m "feat: stage hearth self-hosted oidc provider"
  ```

## Final verification

Run `bash scripts/run-local-quality.sh`, `./mvnw verify -Dsort.skip=true`, `npm test`, `npm run lint`, `bash scripts/check-staging-checklist.sh`, and the staging OIDC smoke runner. No production release is allowed until staging evidence is complete and the PR is merged through the repository workflow.
