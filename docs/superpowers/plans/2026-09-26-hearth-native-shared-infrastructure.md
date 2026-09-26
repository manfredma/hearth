# Hearth native 共享基础设施实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Hearth staging 从 124 Docker 迁移到 129 native，并在 175 初始化 production native，完成 commit-bound staging integration/E2E 和生产只读验收。

**Architecture:** 复用共享 MySQL 13306、Redis 16379、公共 Nginx、Java/Maven/Chromium；Hearth 使用独立 logical database、Redis DB/namespace、端口、systemd unit、目录、配置和路由。staging 迁移旧 Hearth MySQL 数据，production 从空 logical database 初始化。

**Tech Stack:** Spring Boot、Java 25、Maven Wrapper、systemd、Nginx、MySQL 8、Redis 7、Docker 迁移源、Playwright。

**Spec:** docs/superpowers/specs/2026-09-26-hearth-native-shared-infrastructure-design.md

## Global Constraints

- 不在 main 开发；本计划在现有 fix/hearth-login-csrf-race worktree 执行。
- staging 使用 129，production 使用 175；app/edge 只绑定 loopback，80/443 只由共享 Nginx 监听。
- MySQL 只使用 hearth logical database 和 Hearth 专属用户；Redis 使用 DB 5/6 与环境 namespace。
- 所有 WARNING、SHA 不一致、TLS/SNI 错误、数据迁移不确定状态和 owner prerequisite 缺失均 fail-closed。
- 所有项目文件、配置、日志、制品和运行数据归 ubuntu；服务用户只通过项目组写入数据目录。

### Task 1: ADR/spec/知识库与静态资源契约

- [x] 写入 ADR、spec、plan，更新 ADR index、AGENTS、deploy README 和 CHANGELOG。
- [x] 新增 scripts/test-hearth-native-runtime.sh、scripts/test-hearth-native-migration.sh、scripts/test-hearth-native-nginx.sh。
- [x] 先运行静态契约并确认缺失契约以失败结束，再完成最小实现并运行通过。

### Task 2: Native runtime/systemd/Nginx

- [x] 新增 Hearth native config、app/edge/test-slot systemd 模板和 staging/production Nginx 模板。
- [x] 新增 deploy/install-native-runtime.sh，验证 Java 25、资源限制、ubuntu ownership 和无公网端口冲突。
- [x] 为 staging/production 部署脚本实现外部 JAR、SHA、/version、Nginx route 和 systemd 完整重启。

### Task 3: MySQL/Redis 隔离与 staging 数据迁移

- [x] 新增 bootstrap-native-mysql.sh，创建 logical database/user 和 native env。
- [ ] 新增 124→129 的 Hearth 限定 database dump/import；dump 已校验并在 129 待导入，native DB 导入尚未执行。
- [x] 遇到缺少 dump-complete marker 的已有 dump 时分类为 uncertain 并保留，不自动删除或重做。
- [x] staging dump 与 TLS current 更新使用唯一临时输入并在 deployment-test lock 内提交，不能并发覆盖或观察半成品。
- [x] 新增 run-scoped integration/E2E MySQL database/user、Redis DB/namespace 和 test root。

### Task 4: Staging integration/E2E

- [x] 将现有跨进程测试接入 `staging-test` profile 和 129 native Hearth test-slot。
- [x] 增加真实 Maven Failsafe `NativeInfrastructureIT`，验证 MySQL 快照/Flyway/管理员和隔离 Redis 读写；runner 必须核对本轮非零 Failsafe summary 才允许写 evidence。
- [x] 新增管理员登录、CSRF、OAuth consent、OIDC token/userinfo、RP logout 和 Career callback redirect E2E。
- [x] 为 Maven integration 与 Playwright/Chromium 子进程设置 512 MiB `MemoryMax`、零 swap cgroup 限制，E2E Node heap 限为 256 MiB。
- [x] Maven Failsafe 离线只读使用 `/opt/shared-maven/repository`，并持有全局共享仓库读锁。
- [x] 测试 runner 在结束时清理 run-scoped 资源、恢复 staging app 并校验服务日志；实机 evidence 尚未生成。
- [ ] 在 129 执行 integration 与 E2E 并检查两份 SHA-bound `result=passed` evidence。

### Task 5: Staging deployment and acceptance

- [x] 完成本机质量、静态契约和脚本检查；129 native 部署、integration/E2E 与日志 WARNING 实机检查待执行。
- [ ] 验证 staging-hearth.bytedepth.cn TLS/OIDC discovery/health 与其他项目无影响。
- [ ] 项目所有者 staging 验收后 fast-forward 合并 main。

### Task 6: Production bootstrap and release

- [ ] 创建新的 annotated SemVer Tag；Tag 必须与 staging 验收候选 SHA 一致。
- [x] 生产入口校验 annotated Tag SHA 对应 staging integration/E2E 两份 passed evidence、Tag/POM 版本一致，并拒绝 production history 中已部署版本。
- [x] 生产切换使用独占部署锁、systemd restart 与失败恢复；检查其他项目 units/routes/listeners 和 Hearth WARNING。
- [x] 实现 175 production env、MySQL logical database/user、Redis DB 6/namespace、systemd、ACME TLS 自动续期和永久管理员 bootstrap。
- [ ] 部署 native JAR，验证 public `/version`、OIDC discovery、登录、TLS、ownership 和其他项目服务。
- [ ] 生产失败时保持 Hearth 无流量，不停止或修改 ByteDepth、Career、Daylilt、Toolbox。
