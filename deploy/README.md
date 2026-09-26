# Hearth 部署说明

Hearth 是统一身份服务，staging 与 production 分别运行于 129、175，并与 ByteDepth、Career、Daylilt、Toolbox 共用宿主机的 MySQL、Redis、公共 Nginx、Java 和测试运行时。Hearth 的 logical database/user、Redis DB/namespace、端口、目录、systemd unit、TLS 文件、配置和测试资源均独立。

## Native 拓扑

| 环境 | 主机 | Spring profile | app / edge | MySQL | Redis | 数据根 |
|---|---|---|---|---|---|---|
| staging | 129 | `staging-native` | 18110 / 18111 | 13306，DB `hearth`，用户 `hearth_staging_native` | 16379，DB 5，`hearth:staging:session:v1` | `/data/hearth-native-staging` |
| production | 175 | `production-native` | 18112 / 18113 | 13306，DB `hearth`，用户 `hearth_production_native` | 16379，DB 6，`hearth:production:session:v1` | `/data/hearth-native-production` |

80/443 只由各主机已有的共享公网 Nginx 监听。Hearth app 与 private edge 的专属端口都只绑定 loopback；安装/更新 Hearth route 后只对共享 Nginx 执行配置检查与 graceful reload，禁止停止或覆盖其他项目。

## 配置和文件归属

`deploy/hearth-native.conf.example` 是 native 端口、路径和 Redis DB 分配的唯一模板。部署将它安装到 `/etc/hearth/hearth-native.conf`，然后使用 Spring profile 加载环境配置。staging、production 配置和运行数据不得互相复用；私钥、数据库密码和 Remember-Me key 不得写入 Git 或日志。

线上/staging 的 Hearth 项目文件、配置、制品、TLS bundle、运行数据、日志和测试资源都必须归 `ubuntu`；服务只以 `hearth` 用户运行，并通过 `hearth` group 获得必要数据目录权限。以 sudo 创建的项目文件也必须在同一步骤中明确设为 `ubuntu` 所有。

Private edge 的 access/error log 位于各环境 edge 数据目录的 `logs/`，文件为 `ubuntu:hearth`、0660，目录为 0750。对应的 `hearth-{staging,production}-native-edge-logrotate.timer` 每 5 分钟以非特权 `ubuntu` 用户检查 10 MiB 大小阈值，保留 14 份并使用 copytruncate；因此轮转的极短复制/截断窗口可能丢少量日志。logrotate 配置不放入 root 执行的 `/etc/logrotate.d`，避免 Ubuntu 可写配置中的脚本以 root 身份执行。

## Staging 数据迁移与证书

staging 原 Hearth MySQL 数据源位于 124（`124.221.143.25`），仅迁移 `hearth` logical database。迁移脚本会在需要时短暂启动旧 MySQL 容器进行一致性 dump，然后恢复其原运行状态；不会迁移 Redis Session、停止其他项目或删除旧 Docker 数据目录。导入若出现不确定状态会 fail-closed，不能自动清库重试。

部分导入恢复保留原始 dump 和目标 schema 中的部分表；完整 dump 先导入唯一 `hearth_recovery_*` schema，只有管道状态、日志、表集、启用管理员、Flyway 及对象类型校验全部通过后才允许原子交换。旧版中断且没有 `recovery-ready` 标记时，默认拒绝续跑；仅在已独立确认某个恢复 schema 对应的完整成功导入后，才显式设置 `HEARTH_STAGING_RECOVERY_ADOPT_SCHEMA=hearth_recovery_<run-id>`。部署脚本会再次核对 schema 唯一性、数据不变量和日志后写入 ready marker，然后执行同一套续跑校验。该选项不能用于跳过校验或清理任何 schema。

staging TLS 源证书由 124 的 Let’s Encrypt 管理。部署前运行 `deploy/sync-staging-certificate-to-native.sh`；它会校验精确 SAN、有效期和证书/私钥匹配，写入 129 的版本化 `/etc/hearth/staging-tls/releases/`，再在部署/test-slot 共用锁内原子切换 ubuntu 所有的 `current` symlink，避免逐文件更新形成混合证书对。若仍发现旧式真实 current 目录且 Hearth 公网 route 已安装，脚本会 fail-closed。124 续期证书后，必须重新运行此同步脚本，再 reload 129 的共享 Nginx。证书同步不会代理或改变其他域名。

production 首次发布在 175 使用既有 Certbot ACME account，为 `hearth.bytedepth.cn` 签发独立证书；account 副本、renewal 配置、private key 和 challenge root 全部归 `ubuntu`，存放在 `/data/hearth-native-production/letsencrypt`。签发时只临时加载 Hearth HTTP-01 challenge server，申请后删除并 reload；production Hearth route 保留专属 challenge location。`hearth-production-cert-renew.timer` 每日两次检查续期，续期 hook 先 `nginx -t` 再 graceful reload production shared Nginx，不停止其他项目。

生产空库完成 Flyway 后，部署流程只初始化一个永久 `admin` identity：从 staging 的现有管理员 credential 读取 BCrypt hash，经本机临时 `0600` 文件传输到 175 的 `/run`，导入生产 issuer 下的新 identity 后立即删除。hash 不会放入 SSH 命令参数或日志；不会复制 staging 用户、授权记录或 OAuth client，也不会创建临时用户。若 staging 管理员缺失、hash 格式不支持、或 production identity 表非空而没有同 hash 的管理员，流程 fail-closed，不重置已有账号。

## Staging 集成/E2E 资源隔离

每次 staging 部署在 `/opt/shared-maven/repository.lock` 全局排他锁下运行 `deploy/bootstrap-staging-maven-runtime.sh`。它先比较 `/var/lib/hearth-staging/maven-bootstrap/inputs.manifest` 中的 POM、Maven Wrapper 与 `.mvn` 输入指纹；输入未变且既有共享缓存由成功的离线 Failsafe 与无 WARNING 预热日志证明可用时直接复用，不受 Maven 预热内存门槛阻塞；输入变化或无可信缓存证明时，才以 Maven Wrapper 的 `-Pstaging-integration -pl hearth-start -am dependency:go-offline` 预热唯一共享仓库 `/opt/shared-maven/repository`。manifest 只绑定依赖输入，不绑定 checkout SHA；该步骤不编译、不另建 Hearth Maven cache。随后每次 integration/E2E run 生成带唯一 run-id 的 MySQL logical database/user，并从 staging Hearth DB 做一致性快照；测试写入不会落到 staging 主库。Maven Failsafe 的 `NativeInfrastructureIT` 验证快照中的 Flyway 迁移与永久管理员、MySQL 临时表读写，以及 Redis 隔离 DB/namespace 的真实 set/get/delete。集成 runner 持共享 Maven 仓库的只读锁并在 `-o` 离线模式复用该仓库。集成测试使用 Redis DB 12，E2E 使用 Redis DB 13，并分别带 `hearth:staging:test:<suite>:<run-id>:` namespace。Redis DB 14/15 保留给 ByteDepth 的集成/E2E，不能分配给 Hearth。

测试 app 使用 `staging-test` Spring profile 和独立 systemd test-slot。test-slot 与 staging app 声明冲突，测试期间 edge 和共享 Nginx 保持不变；测试结束后脚本停止 test-slot、仅清理该 run 的 Redis namespace/MySQL 库和用户、恢复 staging app，并验证服务健康。存在不确定状态时保留 manifest 与资源，不自动删除。

共享 129 主机曾发生全局 OOM：内核日志明确记录被杀进程是 `release-platform` 的 `npm ci`（RSS 约 1.07 GiB）；当时 Hearth 源 MySQL 仅约 200 MB，native logical DB 尚未导入，不能据此把 OOM 归因于 Hearth dump。为避免复发，Hearth staging npm runtime 仅在 `MemAvailable` 至少 512 MiB 时安装，并将 Node heap 限为 384 MiB、网络 socket 限为 1；Maven dependency prewarm 只运行 `dependency:go-offline`，先检查 `MemAvailable` 且置于 `MemoryMax=384M`、`MAVEN_OPTS=-Xmx192m` 的 Ubuntu transient service；测试 app 的 systemd 上限为 384 MiB。Maven integration 与 Playwright/Chromium 使用唯一 run-id 的 transient systemd service units，设置 `MemoryMax=512M`、`MemorySwapMax=0`，Node E2E heap 限为 256 MiB；启动前仍需通过 test-slot 内存门槛。检查失败时保持现有项目服务不变，不通过停止其他项目释放资源，也不盲目重跑。

在 129 上依次执行：

```bash
sudo -n /opt/hearth-native/source/current/deploy/run-staging-integration-tests.sh
sudo -n /opt/hearth-native/source/current/deploy/run-staging-e2e-tests.sh
```

两个 runner、staging 部署、MySQL source dump finalization 和 TLS current 更新共用 `/var/lib/hearth-staging/deployment-test.lock`，开始测试时先作废旧 evidence（E2E 即使缺少凭据也不能留下旧 passed 记录）。Integration runner 必须看到本轮 Failsafe summary 至少一个 completed test 且 errors/failures 为零，再运行 HTTPS/OIDC smoke；E2E runner 执行浏览器登录、CSRF、consent、token/userinfo、logout 与 Career callback 用例。两者会检查 test-slot 和恢复后 staging app 的本轮 systemd journal，只有部署 SHA 稳定、测试全绿、无 WARNING 且清理/恢复成功才写入 commit-bound `result=passed` evidence。集成/E2E 必须在 staging 执行，本机结果不是验收证据。

### E2E 管理员凭据

完整 OIDC E2E 使用既有 staging 管理员，不创建临时用户。ByteDepth 系列共享的 Keychain item 为 account `admin`、service `bytedepth-staging-e2e`。密码只在本机 Keychain 读取，通过 SSH 标准输入传到远端 shell；SSH 命令参数、远端历史、部署日志和测试报告中都不得出现明文：

```bash
staging_e2e_username=admin
staging_e2e_password="$(security find-generic-password -a admin -s bytedepth-staging-e2e -w)"
test -n "$staging_e2e_password"
{
  printf '%s\n' "$staging_e2e_username"
  printf '%s\n' "$staging_e2e_password"
} | ssh -i "$HOME/.ssh/ubuntu_2.pem" \
  -o IdentitiesOnly=yes -o BatchMode=yes \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts" \
  ubuntu@129.211.6.82 \
  "sudo -n bash -c 'IFS= read -r HEARTH_STAGING_E2E_USERNAME; IFS= read -r HEARTH_STAGING_E2E_PASSWORD; export HEARTH_STAGING_E2E_USERNAME HEARTH_STAGING_E2E_PASSWORD; cd /opt/hearth-native/source/current; sudo -n --preserve-env=HEARTH_STAGING_E2E_USERNAME,HEARTH_STAGING_E2E_PASSWORD ./deploy/run-staging-e2e-tests.sh; status=\$?; unset HEARTH_STAGING_E2E_USERNAME HEARTH_STAGING_E2E_PASSWORD; exit \$status'"
unset staging_e2e_username staging_e2e_password
```

Runner 将凭据通过管道交给以 `ubuntu` 身份运行的 Playwright 进程，不放入进程参数；含真实凭据的浏览器 trace、截图和视频关闭。E2E 使用测试槽位中的 staging 数据库副本，密码错误或账号缺失时失败，不创建或重置管理员。

## 发布顺序

1. 在指定 Hearth feature worktree 实现、测试并更新 `docs/releases/CHANGELOG.md`。
2. 候选 SHA 冻结后运行本机质量门禁：

   ```bash
   bash scripts/run-local-quality.sh
   ```

3. 从本机部署该候选 ref 到 staging（外部构建固定 SHA 的 JAR，不在目标主机编译）：

   ```bash
   HEARTH_STAGING_HOST=129.211.6.82 \
   HEARTH_SSH_KEY="$HOME/.ssh/ubuntu_2.pem" \
   HEARTH_SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts" \
   bash deploy/deploy-native-staging.sh <candidate-ref>
   ```

4. 在 129 运行全部 integration/E2E runner；检查两个 evidence 的完整 SHA 与 staging `/version` 一致，并检查服务日志无 WARNING。随后由项目所有者在 staging 验收。
5. 验收通过后 fast-forward 合并同一候选 SHA 到 `main`；不得在验收与合并之间追加提交。
6. 生产只接收已合并 `main` 历史上的新 annotated SemVer tag。执行 `deploy/deploy-native-production-remote.sh vX.Y.Z`；脚本校验 Tag 与 POM 版本相同、未出现在生产 release history、两份 staging passed evidence 绑定 Tag 完整 SHA，并在 175 的独占部署锁内完成部署。切换后必须做 systemd restart、`/version`、health、OIDC discovery、TLS/Nginx 检查，以及其他项目服务状态、HTTPS 路由、监听端口和 Hearth journal WARNING 核对。失败时恢复旧 route/current symlink 与服务状态；初次部署失败则停止 Hearth units 并移除 Hearth route，不影响其他项目。

生产没有旧 Hearth Docker 流量需要切换。生产初始化失败时保持 Hearth route 无流量，不停止、覆盖或迁移其他项目服务。
