# Hearth 工程陷阱

这里记录已经固化为 Hearth 规则的常见问题。发现新的流程、配置、测试或部署错误时，必须同时补充文档规则和可重复的自动检查。

## 构建与测试

- Maven 必须使用 Wrapper、Java 25 和提交到仓库的 `.mvn/jvm.config`；不要依赖本机默认 `mvn`。
- 新 worktree 在任何前端测试、lint 或 Playwright 前必须先执行 `npm ci --ignore-scripts --no-audit --no-fund`。
- `mvn clean install` 不代表所有质量插件都已执行；覆盖率、PMD 和完整测试必须运行 `verify` 或统一质量入口。
- 单元测试不得连接独立 MySQL、Redis、Docker、Flyway 或浏览器；这些验证属于 staging 集成验收。
- `verify` 生成报告不等于执行覆盖率门禁。必须合并 reactor 的 JaCoCo 数据，再按 `origin/main` merge-base 到候选（含未提交/新增文件）检查每个变更类；报告缺失或未覆盖都失败，抽象接口和 package-info 无可执行代码除外。聚合报告的 exec 路径相对模块目录，不能漏掉 `target/`。本地质量输出也必须通过统一诊断扫描，不能仅看退出码；负向测试把预期诊断捕获到 fixture 日志，成功消息不要含告警级别词。

## 部署与数据

- 当前 staging/production 是宿主机 native runtime，不要把历史 Compose 配置当作当前部署拓扑；确需使用的本地/迁移 Compose service 必须带 `hearth-` 前缀，避免共享 Docker 网络 DNS 别名冲突。
- staging 和生产必须使用独立数据库目录、Redis namespace、Session Cookie 和 OIDC client；前端不得用 localStorage 保存私人身份或业务数据。
- 已执行的 Flyway 迁移不可修改，schema 变化必须追加新迁移。
- native 发布必须按 `deploy/README.md` 执行不可变 JAR 校验、systemd restart、版本检查和 Nginx reload；不能只替换文件或手工启动进程。
- 生产重复部署的端口预检核对所有 listener PID 的 cgroup 与对应 active Hearth unit；只检查进程名或一律拒绝已占用端口都不正确。安装前备份 env/native/edge/systemd 文件及启用链接，恢复原内容与权限后 daemon-reload、恢复指针和服务；失败回滚不能只恢复 symlink。故障注入测试覆盖首次安装缺失文件和逐步安装失败。
- 生产续期 hook 必须检查 Certbot 的精确 RENEWED_LINEAGE/RENEWED_DOMAINS、唯一精确 DNS SAN、至少 30 天有效期及公私钥一致；Nginx 成功退出但带告警也不能 reload。签发管道必须同时检查 Certbot 与 tee 状态。
- 发布入口共享非空分类 Unreleased、候选 Changelog 差异门禁；staging 禁止 main 及其 SHA 别名。生产 Tag 必须 annotated 且精确等于已验收后合并的 main HEAD，不能仅验证属于 main 历史。候选新增提交后，旧 SHA 的两份 evidence 不能复用。

## 安全

- OIDC `issuer + sub` 是跨应用身份稳定键；不能用 email 代替 subject。
- Hearth 管理认证、身份目录和应用访问；业务系统管理功能权限、资源权限和数据权限。
- session 只保存服务端身份引用，浏览器通过 HttpOnly、Secure、SameSite Cookie 持有 session 标识。
- 自定义 `/api/login` 不经过框架认证 filter，显式 saveContext 之前必须调用 SessionAuthenticationStrategy；用进程内 SessionRepository 验证旧 ID 查不到新认证，不能只断言登录返回 200。
- Remember-Me 服务必须返回匹配 RememberMeAuthenticationProvider 的 token；测试经过真实 filter/provider。OIDC logout 使用独立 success handler，普通 LogoutConfigurer 的 Cookie 清理不会自动生效，须显式委托 Remember-Me 清理并保留协议验证。
- Claims 必须依据实际 authorized scopes；profile 控制 name/preferred_username，email 控制 email。目录没有邮箱验证状态时禁止推断 email_verified。授权页不得承诺尚未存在的撤销 UI。
- SPA 回跳必须用浏览器 URL 解析并比较 origin；字符串以单个 `/` 开头不能排除反斜杠 authority 或控制字符。数据库查询的投影必须包含 RowMapper 读取的所有列，测试 fixture 不得提供 SELECT 中没有的列掩盖问题。
- 放入 Redis HTTP Session 的 Spring Security principal 必须实现稳定的 `Serializable` 合约，并用 Java 序列化往返测试覆盖；否则登录请求虽然认证成功，提交 session 时仍会失败。
- 跨站点 OIDC 回跳后的 SPA 登录不能只依赖 session 中的 CSRF token；统一使用非 HttpOnly 的 `XSRF-TOKEN` cookie，并让 `X-CSRF-TOKEN` 请求头与之匹配。
- OIDC 登录入口必须显式保留原始相对授权 URL；不能只依赖 session saved request，否则 session fixation/回跳过程可能让登录后落到 Hearth 首页。
- 未登录可访问的 SPA 原型入口必须同时加入前端路由和 `SecurityConfig.publicRequestMatchers()`，并用安全路由单元测试锁定白名单；否则页面会被统一认证规则返回 403。
- Hearth 命名门禁禁止复制 bytedepth 的运行时标识，但允许明确登记的业务应用 staging 域名作为 OAuth 来源应用展示数据；新增来源域名时必须同步更新门禁测试，不能放宽为任意 bytedepth 字符串。
- Native 多服务主机的生产安全检查需要引用真实的共享 systemd unit 与公开域名；命名门禁只允许这些完整标识作为独立行，并有混入 `bytedepth-app` 的负向测试，不能因同一行出现合法域名就忽略整行。
- 175 的共享 Nginx unit 为 `bytedepth-production-public-nginx.service`，主配置为 `/etc/bytedepth/production-public-nginx.conf`，MySQL 管理配置为 `/etc/bytedepth/production-mysql.cnf`。共享 ByteDepth unit 使用 `bytedepth-production-{app,edge,meilisearch,mysql,public-nginx,redis}.service`；发布快照必须要求每个目标 active，缺失 unit 不能被当作前后状态未变化。
- OAuth consent 的真实页面只能展示从 RegisteredClientRepository 读取的客户端名称和已登记回调来源；`client_id` 只用来查找，不可直接作为可信来源名称。没有已登记元数据时禁用授权提交；无可选 profile/email scope 的 OIDC 请求只提交原请求中的 `openid`，取消时不能提交它。
- 更新运行服务使用的 current symlink 时，不能用 `ln -sfn` 直接覆盖；先在同一目录以服务拥有者创建临时 symlink，再通过同文件系统原子 rename 替换，并在失败时恢复旧指针。
- staging 宿主机不保证安装 ripgrep；部署/测试运行脚本必须用系统 `grep` 或共享 warning-log helper，不能依赖本机工具。另，ripgrep 的 `-E` 是字符编码选项，不是 grep 的扩展正则开关，`rg -Eqi` 会因 `unknown encoding: qi` 报错。日志缺失、不可读、`tee` 失败或测试进程失败都必须阻止 passed evidence。
- 恢复 MySQL 部分导入时，必须先把 mysqldump 中的 `CREATE DATABASE` 与 `USE` 明确重写到唯一临时 schema，并用测试断言重写后的 SQL；动态 schema 标识符统一经安全引用函数生成，避免 Shell 双引号中的反引号触发命令替换。只有导入管道所有步骤成功后才能写 `recovery-ready` 检查点；从旧版中断状态 adoption 时，必须显式指定唯一临时 schema，并在落盘检查点前重新验证表集、管理员、Flyway、日志和对象类型。
- 多服务主机的 `/tmp` 可能是接近满载的 tmpfs；大型部署上传应放入工程专属、由 `ubuntu` 持有的 `/var/tmp` 目录，避免与其他服务竞争共享 tmpfs。
- staging 主机对公网暴露 SSH 且持续有未认证探测；Hearth native 发布和 Docker→native 状态检查若为每条 SSH/SCP 命令分别建立连接，可能触发 sshd `MaxStartups` 并被远端无提示丢弃。两个脚本必须在上传/迁移前用同一 `ControlPath` 建立 SSH multiplex（`ControlMaster=auto`、短期 `ControlPersist`），并对 master 建立使用有限 5 次重试；不得通过调高/修改多项目主机的全局 sshd 参数规避。
- staging E2E 的管理员凭据先经 stdin 传入 root runner，再由 `sudo` 降权给 ubuntu 启动 Playwright；`sudo` 默认清理环境变量，必须显式 `--preserve-env=HEARTH_E2E_ADMIN_USERNAME,HEARTH_E2E_ADMIN_PASSWORD`。只能保留变量名，禁止把密码放进命令参数；契约测试必须覆盖该降权边界，避免只有公开匿名用例通过而管理员 E2E 在登录前失败。
- 登录 E2E 中，前端会消费 `/api/login` 响应 JSON 后立即导航；Playwright 若在导航后再读取同一 `Response` body，Chromium 会返回 `No resource with given identifier found`。应断言登录响应状态，再通过共享 Session Cookie 的 `/api/session` 验证登录态，不要将浏览器响应体重复读取当作认证结果。
- Playwright OAuth callback 必须观察真实请求。Hearth 自测 Client 可使用同源 `/consent-preview` 并手动换 token；Career 必须从受保护页面/授权发起端进入，捕获 Career 生成的 state、S256 challenge 和实际回调，再验证受保护页面身份及 Career 的退出按钮。测试自己生成 state/verifier 并直接请求 Career callback 会绕过 RP 会话关联，不能作为登录成功证据。
- E2E runner 获得部署锁后立即作废旧 evidence，然后才检查缺失或非法凭据；执行级回归覆盖两种凭据失败，不能只单测删除文件 helper。
- 被部署脚本直接执行的 Shell 文件必须在 Git 中保留可执行位；迁移门禁要对每个直接调用的入口使用 `test -x`，避免部署到远端后才因 `Permission denied` 中断。
- Shell 中已经单引号包围的 `awk` 程序不要再把双引号写成 `\"`；反斜杠会被传入 awk 并造成语法错误。manifest 解析应有契约测试，避免静默退化成每次重装依赖。
- 目标机 systemd 的 `systemd-run --pipe` 与 `--scope` 不兼容；需要接 stdin/stdout 时改用唯一名称的 transient service unit（`--unit --collect --wait --pipe`），并保留其 cgroup 内存限制。systemd-run 默认还会扩展 transient service ExecStart 中的 `$`/`%` 表达式；执行 Bash 脚本字符串时必须加 `--expand-environment=no`，否则脚本内参数展开可能被清空。
- staging integration 使用离线、只读的唯一共享 Maven 仓库；新增 profile/test 插件依赖必须在部署阶段先通过 Wrapper 的 `dependency:go-offline`（启用 staging-integration profile）预热，并持全局排他锁，不能给项目新建第二份缓存或让集成 runner 在线下载。
- 共享 Maven 仓库可能含有其他 bootstrap 遗留的 `root:root` 子目录；不能假设 `ubuntu` 对整个缓存可写，也不能递归 chown 多项目共用的仓库。预热必须持全局排他锁，由 root 在 `umask 022` 下补齐共享 artifacts，`HOME`/Maven Wrapper 用户缓存仍指向 ubuntu；退出时只把当前 Hearth checkout 下的 `target` 目录恢复为 `ubuntu:ubuntu`。
- Failsafe 会动态选择 JUnit Platform provider，Maven dependency `go-offline` 不保证发现它；staging profile 应在 Failsafe plugin dependencies 中显式声明与插件同版本的 `surefire-junit-platform`，才能可靠预热给离线集成运行。
- 远端 curl 自定义 header 必须使用 `-H "Name: value"` 的冒号语法；用等号拼接 CSRF header 会使请求未携带预期 header，导致 403 并阻止 integration evidence 写入。
- E2E runtime manifest 的值允许包含空格；解析 `key=value` 时用 `substr($0, index($0, "=")+1)` 保留原始值，不要清空 `$1` 后重建 `$0`，否则会引入前导空格并误判 runtime 不匹配。
- Integration 与 E2E 必须共用 `hearth_test_slot_new_run_id` 生成器，保证 run-id 符合 test-slot 的 UTC 时间格式；不要手工拆分 `date` 格式参数，空格会被解释成额外操作数。
- 多服务 staging 机的 Maven 依赖预热不得先做完整编译/PMD；用 `dependency:go-offline`、MemAvailable 门槛和受限 transient service，避免预热任务挤压同机服务。
- staging 的宿主机 Maven 仓库是多项目共享且锁保护的。若 Maven 输入指纹（全部模块 POM 与 `.mvn` 配置）未变，且最近成功部署的离线 Failsafe 与无 WARNING 预热日志证明依赖闭包可用，应复用该缓存；不得将 manifest 绑定 checkout SHA，也不能因低内存重复预热相同依赖。
- staging integration 的 512 MiB transient cgroup 同时容纳 Maven 主 JVM 与 Failsafe fork；仅配置 PMD `skip` 仍会加载插件，进程内 javac 的内存也会留在 Maven JVM。因本地/CI 门禁已运行 PMD，`staging-integration` profile 必须解绑 `pmd-check`（phase `none`），并使用显式 `executable=javac`、maxmem 128 MiB 的 forked javac；Failsafe fork heap 限在 128 MiB。显式 javac 可避免远端 Maven compiler autodetection 的 WARNING。
- Hearth test-slot 不再使用 640 MiB 主机 `MemAvailable` 预检；Maven/Playwright 及 test-slot app 各自保留 `MemoryMax` cgroup 上限，但不对 unit 单独设置 swap 限额，swap 由宿主机统一管理；不通过停止其他项目释放内存。
- Linux 的 `flock -x` 排他锁必须使用可写文件描述符；全局锁文件由 root 管理时，用 append-only 打开（`>>`）即可取得排他锁且不会截断锁文件，`<` 只读句柄只用于共享锁。
- 以项目服务账号运行的私有 Nginx edge 不能写共享 `/var/log/nginx/*.log`；access/error log 必须落到项目专属日志目录，文件由 `ubuntu:hearth` 预创建/持有、服务组只追加写入。轮转使用 Ubuntu 用户级 timer，禁止让 Ubuntu 可写的 logrotate 配置被 root 执行；copytruncate 可能在复制/截断窗口丢少量日志。运行时契约测试保护该约束；已有日志文件不能通过安装 `/dev/null` 截断重建。
