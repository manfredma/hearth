# Changelog

Hearth 使用 Semantic Versioning。用户可见、运行时、部署或配置变化必须先记录在 `## Unreleased`，再进入 staging。

## Unreleased

### Added

- 登记 `TD-HEARTH-002`：Hearth 当前退出只清理中央 Session，不会主动失效 Career、release-platform/devops 等业务系统的本地 Session；后续评估 OIDC Back-Channel/Front-Channel Logout 或 Session introspection。

### Changed

- Hearth 构建、staging/production 发布和回滚改由 release-platform 统一编排；项目仓库不再提供发布脚本，平台构建写入标准 `/version` 元数据。
- 真实 OAuth consent 页改从已登记 Client 读取应用名称与回调来源，只列出请求的可选权限；纯 OIDC 请求明确显示无额外个人资料权限并可继续授权；移除尚未提供的授权撤销界面承诺。
- 生产发布与证书脚本改用 175 当前共享 Nginx unit/config 和 MySQL 管理配置路径；共享服务快照在任一 unit 缺失或非 active 时立即失败。
- Career E2E 从其受保护日历页发起授权，关联 Career 实际生成的 state/PKCE 与 callback，断言 Career 登录会话并执行真实退出按钮；Hearth 自测 Client 单独验证 token/userinfo 与 RP logout。候选 SHA 变化后必须重新执行 staging integration/E2E；这些用例的本地静态检查不是 staging 通过证据。
- Hearth staging TLS 改为由 129 本机 Certbot 自动续期；将现有证书纳入续期管理，不重新签发或从已退役的 124 同步；首次 dry-run 跳过随机等待，日常续期仍保留错峰，并明确区分 Hearth 自有命名与真实共享基础设施标识。
- staging 发布先以最多 5 次尝试建立短期 SSH multiplex，再复用同一连接执行上传/迁移，规避公网 SSH 未认证探测触发 sshd `MaxStartups` 后随机丢连接；不更改共享 sshd 配置。
- 修复 staging E2E 降权启动 Playwright 时管理员凭据环境变量被 `sudo` 清理的问题；仅保留变量名传递，不把凭据放入命令参数。

- `v0.1.0` staging candidate 使用资源门槛与 cgroup 限额保护的 Maven dependency bootstrap，按共享缓存的现有权限安全补齐 artifacts，并只恢复 Hearth 构建目录的 ubuntu 所有权；同时清理未使用的 ByteDepth 模板依赖并校正 Hearth 模块/数据库/路由说明；integration 继续离线只读。
- staging Docker→native 数据迁移可恢复已开始但未完成的 Hearth 导入：保留原始 dump，将数据先导入唯一临时 schema，校验后原子备份部分表并切换完整表集。
- staging 发布制品上传使用工程专属 `/var/tmp/hearth-native-staging-uploads`，避免大型 JAR 与其他服务竞争共享 tmpfs。
- staging Maven bootstrap 显式预热与 Failsafe 同版本的 JUnit Platform provider，并检查资源和共享锁。
- staging 导入成功检查点只在所有管道步骤成功后落盘；进程中断后的续跑会重新校验唯一临时 schema、管理员、Flyway 和对象类型，再交换表集。
- native private edge 的 Nginx access/error 日志写入项目 edge 数据目录，避免服务账号写共享 `/var/log/nginx` 被拒绝。
- staging/production private edge 日志由 Ubuntu 用户级 timer 每 5 分钟检查 10 MiB 阈值，保留 14 份并使用 copytruncate；新日志由 `ubuntu:hearth` 创建。
- staging integration/E2E 使用带 `--pipe` 的 transient systemd service unit，保留 stdin 凭据传递、唯一 run-id 回收与内存上限。

### Fixed

- 生产监听端口验收统一 IPv4 loopback 与 IPv4-mapped IPv6 loopback 表示，避免 Java 双栈监听被误判为超出 Hearth 端口范围。
- 生产部署等待共享 Nginx 完成 reload 后再校验证书，并在失败回滚时先恢复 Hearth release 指针与服务，再恢复配置文件，避免留下半发布状态。
- 本地质量入口捕获每步输出并阻断 WARN/WARNING、非零退出和日志捕获失败；恢复对 PR 变更 Java 类的 100% 行、分支、方法覆盖率检查，合并各模块单元测试执行数据后逐模块检查实际报告。
- 身份目录 upsert 后的查询补齐 RowMapper 读取的 issuer/subject 列，并补充 JDBC 边界回归测试。
- 生产升级仅接受已有 active Hearth unit 的 loopback 端口监听者；部署安装前备份环境、native 配置、systemd unit/启用链接与 edge 配置，失败时恢复文件内容、权限及服务状态，回滚不完整时保留事务备份。
- 本地、CI 和部署入口要求非空分类 Unreleased；候选需有 Changelog 差异，staging 拒绝 main，生产 annotated Tag 必须与 main HEAD 和两份 staging passed evidence 的完整 SHA 一致。
- 用系统 `grep` 的共享 WARNING-log verifier 取代错误的 ripgrep 参数/远端工具依赖，并在所有 build/test pipelines 中同时检查产生命令与 `tee` 的退出状态，避免日志缺失时写 passed evidence。
- 修复 staging runtime manifest 的 awk 双引号转义，确保依赖未变化时能够复用既有 Playwright/Chromium runtime。
- 对 transient systemd service 显式关闭 ExecStart 环境变量扩展，使 runner 自己的 Bash 参数展开与 stdin 凭据解析正常工作。
- staging integration 在 512 MiB transient cgroup 中解绑已由本机/CI 完成的 PMD 生命周期执行、使用显式可解析且受限的 forked javac，并收紧 Failsafe fork heap，避免 Maven 与测试 JVM合计触发 OOM。
- 修正 staging integration 的 curl CSRF header 语法及 E2E Chromium runtime manifest 值解析，避免 smoke test 403 和误报 runtime mismatch。
- staging Maven 预热新增依赖输入指纹复用；仅在 Maven 输入变化或既有离线验证不成立时才运行受内存门槛保护的预热。
- 修复 Hearth E2E test-slot run-id 的日期格式，使浏览器测试能进入实际执行阶段。
- 移除 test-slot 无文档依据的 640 MiB 主机可用内存预检；Maven/E2E 保留 cgroup 内存上限，但不单独限制 unit swap。

### Security

- JSON 密码登录在保存认证上下文前执行 session ID 轮换；进程内 Spring Session 测试验证旧匿名 ID 无法复用新认证会话。
- OIDC 的 name/preferred_username 仅在授权 profile scope 时签发，email 仅在 email scope 时签发；没有邮箱验证状态时不签发 email_verified。
- Remember-Me 恢复使用框架支持的 RememberMeAuthenticationToken；RP `/connect/logout` 同时清除中央 session 和持久 Cookie。
- 登录回跳使用浏览器 URL 解析及 origin 比较，拒绝反斜杠 authority、控制字符及其他外部目的地。
- 生产证书签发/续期要求精确 lineage/SAN、至少 30 天有效期与匹配私钥；Nginx 告警和 Certbot 日志捕获失败均阻断流程。

## 0.1.0 - 2026-09-26

### Changed

- 将 Hearth staging/production 规划为与 ByteDepth、Career、Daylilt、Toolbox 共用宿主机基础设施的 native 部署，使用独立 MySQL logical database、Redis DB/namespace、端口、目录、systemd unit 和 Nginx route。
- 增加 `staging-native`、`production-native` 与 `staging-test` Spring profiles；integration/E2E 使用 run-scoped MySQL logical database/user、Redis DB 12/13 与专属 test-slot，测试后验证清理并恢复 staging app。
- Native app 和 private edge 端口仅绑定 loopback，避免绕过共享 Nginx 直接访问项目服务。
- 增加 124→129 的 staging TLS bundle 校验/同步流程，证书和私钥 bundle 归 `ubuntu` 持有，不修改其他项目的证书或 Nginx route。
- 增加 175 Hearth 专属 Certbot account/config、webroot HTTP-01 签发和 systemd 自动续期；证书配置与私钥由 `ubuntu` 管理，renewal hook 只验证并 graceful reload 项目共享 Nginx。
- 限制 staging Node 安装和 test-slot 的内存预算，避免与同机多项目构建争抢内存；资源不足时 fail-closed，不停止其他服务或自动重跑。
- staging 集成 runner 执行真实 Maven Failsafe 测试，验证 run-scoped MySQL 快照迁移与 Redis 隔离读写；没有 completed Failsafe 测试时拒绝生成 evidence。
- 首次 production 初始化只创建永久的共享管理员 identity：复用 staging 中现有管理员的 BCrypt password hash，不复制其他身份或 OAuth client，不创建临时账号。

### Added

- 初始化 Hearth 统一身份中心：OIDC 登录边界、服务端 Redis Session、MySQL 身份目录和应用访问数据模型。
- 增加 Hearth 统一的 30 天免登录：复用 bytedepth 已验证的 Spring Security 无状态签名 Remember-Me Cookie。
- 确定 Hearth 自建 OIDC Provider 方向，接入 Spring Security 7 Authorization Server 边界配置与标准 Provider 路由。
- 新增本地密码凭据、服务端登录 Session，以及 OAuth Client、授权码、Consent 的 MySQL 持久化表。
- 接入 Spring Security 7 的 Authorization Server filter chain、RSA JWK、OIDC claims 和 OAuth Client 管理 API。
- 新增 React/Vite 管理端原型，包含身份总览、应用接入、移动端抽屉导航和登录入口。
- 新增 Hearth 品牌化 OAuth 授权确认视觉原型，展示来源应用、来源域名、当前账号和可审阅的权限项，并适配移动端。
- 优化 OAuth 授权确认视觉稿：强化来源应用与 Hearth 的连接关系，收紧版式层级并细化权限清单与操作区。
- 修复授权确认页手机端操作区的按钮宽度冲突，避免主按钮文字在窄屏下竖排。
- 新增生产/staging 隔离的 Docker Compose 配置与静态环境检查。
- 修复 MySQL utf8mb4 身份联合索引超长问题，并移除未使用的 MyBatis 启动依赖。

### Changed

- 修复 OAuth 授权确认页提交返回 403 的问题：按 Spring Authorization Server 的端点边界使用一次性 OAuth `state` 防护 Consent 提交，避免与通用 Web CSRF 过滤链重复校验。
- 修复 OAuth 授权码换 Token 时缺少 `auth_time` 导致 Career 回调失败并重复发起登录的问题：本地密码登录、Remember-Me 和旧会话迁移均携带带时间戳的 Spring Security 认证因子。
- 修复 OAuth 授权确认在登录后返回 403 的问题：认证会话改用 Spring Security 可持久化的标准用户主体，兼容旧 HearthPrincipal 会话，并清理已写入旧主体的失效授权记录。
- 收敛 OAuth 授权确认页的身份上下文展示：合并 Career 来源与当前账号信息，移除重复的 Hearth 身份块，并优化域名、权限说明和移动端布局。
- 将授权确认原型接入真实 OAuth 流程：Career 授权请求使用 Hearth 中文 consent 页面，支持动态应用/账号信息、权限选择、同意与取消提交。
- 修复授权确认页原生表单提交时 `client_id`、`state`、`user_code` 和 `scope` 参数丢失，确保同意与取消都能正确回到 OAuth 授权端点。
- 修复旧 Hearth 会话缺少 OIDC `auth_time` 时 Career 登录循环、RP-Initiated Logout 被通用 CSRF 错误拦截的问题，并在 Hearth 首页账号菜单提供服务端退出入口。
- 放行 OIDC RP-Initiated Logout 协议入口到端点自身校验，避免业务系统没有 Hearth Session 时被外层认证规则返回 403。
- 修复 OAuth Client 将登录回调地址误用为退出回跳地址导致 Career RP-Initiated Logout 返回 403 的问题，分别保存并校验两类 URI。
- 由 bytedepth 模板转换为独立的 Hearth 身份服务工程，模块、包名、运行时变量和服务名统一使用 Hearth 命名。
- 生产发布强制校验 integration/E2E 两份 passed evidence 与 Tag 完整 SHA 一致，并校验 Tag 与 POM 版本一致且未曾发布；版本切换使用独占锁、原子 symlink、systemd 完整重启和失败回滚。
- staging TLS 证书按完整版本目录校验后原子切换 current 指针；同步、部署和 test-slot 共用锁，避免证书/私钥混合及并发覆盖。
- staging dump 使用唯一临时文件，并在共享锁内重新核对状态后原子落盘；不再覆盖缺少完成标记的 dump。
- E2E 在凭据检查前先作废旧 evidence；E2E/Maven 进程树使用内存与 swap 上限；集成 Maven 离线只读复用共享 Maven 仓库；edge 运行目录归 `ubuntu:hearth`。
- integration/E2E 校验测试进程和日志 `tee` 的全部退出状态，并用完整 WARNING 单词边界 fail-closed；生产部署后核对其他项目服务、公开路由与监听端口。
- 修复 staging/production 构建脚本对远端 ripgrep 的隐式依赖及将 ripgrep `-E` 误当 grep 扩展正则选项的问题；warning log 缺失或不可读时也 fail-closed。
- Hearth 命名门禁精确登记生产共享服务名与公开 host，并回归验证合法共享主机标识不会放行夹带的非法项目名。
- 基础设施 JDBC 仓储保持可代理，避免 Spring Repository 异常转换在启动阶段失败。
- 修正 Spring Security 7 Authorization Server endpoint matcher 绑定，并移除未使用的 Thymeleaf 模板依赖。
- 修正登录页 CSRF 请求头名称，使服务端会话登录请求能够通过 Spring Security 校验。
- 登录页在 CSRF token 准备完成前禁用提交，避免快速操作触发 403。
- 显式启用 Redis-backed HTTP Session，并按环境使用隔离的 Redis namespace。
- JSON 登录 API 使用跨请求稳定的非掩码 CSRF token handler，继续保留服务端 CSRF 校验。
- SPA 登录使用非 HttpOnly 的 `XSRF-TOKEN` CSRF cookie，并继续通过 `X-CSRF-TOKEN` 请求头校验。
- OIDC 未登录请求显式携带 `/login?continue=...`，登录后可稳定回到原始授权请求。
- Redis HTTP Session 中的 HearthPrincipal 支持 Java 序列化，修复登录成功后无法持久化会话的问题。

### Security

- Hearth 不保存业务密码；生产与 staging 必须使用不同 OIDC client、MySQL 数据目录、Redis namespace 和 Session Cookie。
- Remember-Me 签名密钥由 `HEARTH_REMEMBER_ME_KEY` 注入，HTTPS 环境使用 HttpOnly、Secure、SameSite=Lax Cookie；业务应用不共享该 Cookie。
