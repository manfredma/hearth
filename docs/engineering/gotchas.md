# Hearth 工程陷阱

这里记录已经固化为 Hearth 规则的常见问题。发现新的流程、配置、测试或部署错误时，必须同时补充文档规则和可重复的自动检查。

## 构建与测试

- Maven 必须使用 Wrapper、Java 25 和提交到仓库的 `.mvn/jvm.config`；不要依赖本机默认 `mvn`。
- 新 worktree 在任何前端测试、lint 或 Playwright 前必须先执行 `npm ci --ignore-scripts --no-audit --no-fund`。
- `mvn clean install` 不代表所有质量插件都已执行；覆盖率、PMD 和完整测试必须运行 `verify` 或统一质量入口。
- 单元测试不得连接独立 MySQL、Redis、Docker、Flyway 或浏览器；这些验证属于 staging 集成验收。

## 部署与数据

- 当前 staging/production 是宿主机 native runtime，不要把历史 Compose 配置当作当前部署拓扑；确需使用的本地/迁移 Compose service 必须带 `hearth-` 前缀，避免共享 Docker 网络 DNS 别名冲突。
- staging 和生产必须使用独立数据库目录、Redis namespace、Session Cookie 和 OIDC client；前端不得用 localStorage 保存私人身份或业务数据。
- 已执行的 Flyway 迁移不可修改，schema 变化必须追加新迁移。
- native 发布必须按 `deploy/README.md` 执行不可变 JAR 校验、systemd restart、版本检查和 Nginx reload；不能只替换文件或手工启动进程。

## 安全

- OIDC `issuer + sub` 是跨应用身份稳定键；不能用 email 代替 subject。
- Hearth 管理认证、身份目录和应用访问；业务系统管理功能权限、资源权限和数据权限。
- session 只保存服务端身份引用，浏览器通过 HttpOnly、Secure、SameSite Cookie 持有 session 标识。
- 放入 Redis HTTP Session 的 Spring Security principal 必须实现稳定的 `Serializable` 合约，并用 Java 序列化往返测试覆盖；否则登录请求虽然认证成功，提交 session 时仍会失败。
- 跨站点 OIDC 回跳后的 SPA 登录不能只依赖 session 中的 CSRF token；统一使用非 HttpOnly 的 `XSRF-TOKEN` cookie，并让 `X-CSRF-TOKEN` 请求头与之匹配。
- OIDC 登录入口必须显式保留原始相对授权 URL；不能只依赖 session saved request，否则 session fixation/回跳过程可能让登录后落到 Hearth 首页。
- 未登录可访问的 SPA 原型入口必须同时加入前端路由和 `SecurityConfig.publicRequestMatchers()`，并用安全路由单元测试锁定白名单；否则页面会被统一认证规则返回 403。
- Hearth 命名门禁禁止复制 bytedepth 的运行时标识，但允许明确登记的业务应用 staging 域名作为 OAuth 来源应用展示数据；新增来源域名时必须同步更新门禁测试，不能放宽为任意 bytedepth 字符串。
- Native 多服务主机的生产安全检查需要引用真实的共享 systemd unit 与公开域名；命名门禁只允许这些完整标识作为独立行，并有混入 `bytedepth-app` 的负向测试，不能因同一行出现合法域名就忽略整行。
- 更新运行服务使用的 current symlink 时，不能用 `ln -sfn` 直接覆盖；先在同一目录以服务拥有者创建临时 symlink，再通过同文件系统原子 rename 替换，并在失败时恢复旧指针。
- staging 宿主机不保证安装 ripgrep；部署/测试运行脚本必须用系统 `grep` 或共享 warning-log helper，不能依赖本机工具。另，ripgrep 的 `-E` 是字符编码选项，不是 grep 的扩展正则开关，`rg -Eqi` 会因 `unknown encoding: qi` 报错。日志缺失、不可读、`tee` 失败或测试进程失败都必须阻止 passed evidence。
- 恢复 MySQL 部分导入时，必须先把 mysqldump 中的 `CREATE DATABASE` 与 `USE` 明确重写到唯一临时 schema，并用测试断言重写后的 SQL；动态 schema 标识符统一经安全引用函数生成，避免 Shell 双引号中的反引号触发命令替换。只有导入管道所有步骤成功后才能写 `recovery-ready` 检查点；从旧版中断状态 adoption 时，必须显式指定唯一临时 schema，并在落盘检查点前重新验证表集、管理员、Flyway、日志和对象类型。
- 多服务主机的 `/tmp` 可能是接近满载的 tmpfs；大型部署上传应放入工程专属、由 `ubuntu` 持有的 `/var/tmp` 目录，避免与其他服务竞争共享 tmpfs。
- 被部署脚本直接执行的 Shell 文件必须在 Git 中保留可执行位；迁移门禁要对每个直接调用的入口使用 `test -x`，避免部署到远端后才因 `Permission denied` 中断。
- Shell 中已经单引号包围的 `awk` 程序不要再把双引号写成 `\"`；反斜杠会被传入 awk 并造成语法错误。manifest 解析应有契约测试，避免静默退化成每次重装依赖。
- 目标机 systemd 的 `systemd-run --pipe` 与 `--scope` 不兼容；需要接 stdin/stdout 时改用唯一名称的 transient service unit（`--unit --collect --wait --pipe`），并保留其 cgroup 内存限制。systemd-run 默认还会扩展 transient service ExecStart 中的 `$`/`%` 表达式；执行 Bash 脚本字符串时必须加 `--expand-environment=no`，否则脚本内参数展开可能被清空。
- staging integration 使用离线、只读的唯一共享 Maven 仓库；新增 profile/test 插件依赖必须在部署阶段先通过 Wrapper 的 `dependency:go-offline`（启用 staging-integration profile）预热，并持全局排他锁，不能给项目新建第二份缓存或让集成 runner 在线下载。
- 共享 Maven 仓库可能含有其他 bootstrap 遗留的 `root:root` 子目录；不能假设 `ubuntu` 对整个缓存可写，也不能递归 chown 多项目共用的仓库。预热必须持全局排他锁，由 root 在 `umask 022` 下补齐共享 artifacts，`HOME`/Maven Wrapper 用户缓存仍指向 ubuntu；退出时只把当前 Hearth checkout 下的 `target` 目录恢复为 `ubuntu:ubuntu`。
- Failsafe 会动态选择 JUnit Platform provider，Maven dependency `go-offline` 不保证发现它；staging profile 应在 Failsafe plugin dependencies 中显式声明与插件同版本的 `surefire-junit-platform`，才能可靠预热给离线集成运行。
- 多服务 staging 机的 Maven 依赖预热不得先做完整编译/PMD；用 `dependency:go-offline`、MemAvailable 门槛和受限 transient service，避免预热任务挤压同机服务。
- Linux 的 `flock -x` 排他锁必须使用可写文件描述符；全局锁文件由 root 管理时，用 append-only 打开（`>>`）即可取得排他锁且不会截断锁文件，`<` 只读句柄只用于共享锁。
- 以项目服务账号运行的私有 Nginx edge 不能写共享 `/var/log/nginx/*.log`；access/error log 必须落到项目专属日志目录，文件由 `ubuntu:hearth` 预创建/持有、服务组只追加写入。轮转使用 Ubuntu 用户级 timer，禁止让 Ubuntu 可写的 logrotate 配置被 root 执行；copytruncate 可能在复制/截断窗口丢少量日志。运行时契约测试保护该约束；已有日志文件不能通过安装 `/dev/null` 截断重建。
