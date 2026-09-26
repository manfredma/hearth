# Changelog

Hearth 使用 Semantic Versioning。用户可见、运行时、部署或配置变化必须先记录在 `## Unreleased`，再进入 staging。

## Unreleased

### Changed

- `v0.1.0` staging candidate 已重新冻结；integration/E2E runner 使用目标 systemd 支持的 transient service unit，部署使用此提交完整 SHA。
- staging Docker→native 数据迁移可恢复已开始但未完成的 Hearth 导入：保留原始 dump，将数据先导入唯一临时 schema，校验后原子备份部分表并切换完整表集。
- staging 发布制品上传使用工程专属 `/var/tmp/hearth-native-staging-uploads`，避免大型 JAR 与其他服务竞争共享 tmpfs。
- staging 导入成功检查点只在所有管道步骤成功后落盘；进程中断后的续跑会重新校验唯一临时 schema、管理员、Flyway 和对象类型，再交换表集。
- native private edge 的 Nginx access/error 日志写入项目 edge 数据目录，避免服务账号写共享 `/var/log/nginx` 被拒绝。
- staging/production private edge 日志由 Ubuntu 用户级 timer 每 5 分钟检查 10 MiB 阈值，保留 14 份并使用 copytruncate；新日志由 `ubuntu:hearth` 创建。
- staging integration/E2E 使用带 `--pipe` 的 transient systemd service unit，保留 stdin 凭据传递、唯一 run-id 回收与内存上限。
- integration/E2E transient runners 改用带 `--pipe` 的 systemd service units，同时保留每进程内存上限和唯一 run-id 回收。

### Fixed

- 用系统 `grep` 的共享 WARNING-log verifier 取代错误的 ripgrep 参数/远端工具依赖，并在所有 build/test pipelines 中同时检查产生命令与 `tee` 的退出状态，避免日志缺失时写 passed evidence。
- 修复 staging runtime manifest 的 awk 双引号转义，确保依赖未变化时能够复用既有 Playwright/Chromium runtime。

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
