# Hearth 部署说明

Hearth 是统一身份服务。staging 入口为 `https://staging-hearth.bytedepth.cn/`，production 入口为 `https://hearth.bytedepth.cn/`。Hearth 与 ByteDepth、Career、Daylilt、Toolbox 共享宿主机基础设施，但使用独立 logical database/user、Redis DB/namespace、端口、目录、systemd unit、route、凭据和 evidence。

## 当前 native 拓扑

| 环境 | 主机 | app | edge | MySQL | Redis | 数据根 |
|---|---|---:|---:|---|---|---|
| staging | 129 | 18110 | 18111 | 13306 / hearth / hearth_staging_native | 16379 / DB 5 / hearth:staging: | /data/hearth-native-staging |
| production | 175 | 18112 | 18113 | 13306 / hearth / hearth_production_native | 16379 / DB 6 / hearth:production: | /data/hearth-native-production |

Hearth 不绑定 80/443；共享公网 Nginx 只加载项目专属 server 配置并 reload。旧 124 Docker Compose 仅作为 staging 迁移输入，不能继续作为验收入口。

## 配置

复制 `deploy/.env.example` 或 `deploy/.env.staging.example` 为宿主机私有的 `.env`，并由部署系统注入真正的数据库、Redis、RSA 私钥和 Remember-Me 签名密钥配置。`HEARTH_SIGNING_KEY` 使用 base64 编码的 PKCS#8 RSA 私钥 DER；`HEARTH_REMEMBER_ME_KEY` 必须是独立的高熵随机值，staging/production 不得共用。密钥不得提交到仓库。不要把 `.env` 提交到仓库。`HEARTH_COMMIT_ID` 与 `HEARTH_BUILT_AT` 必须由发布流程显式注入，不接受隐式默认值。

旧 Compose 文件和 hearth-* 服务只用于理解迁移输入与回退边界；当前 staging/production 正常运行必须使用 native systemd app/edge、共享 MySQL/Redis 和宿主机公共 Nginx。

## 验证边界

本机只执行静态配置检查和 `docker compose config` 语法检查；MySQL、Redis、Flyway、OIDC 的跨进程验收必须在 staging 完成。发布前先执行：

```bash
bash scripts/test-deploy-hearth-config.sh
docker compose --env-file deploy/.env -f deploy/docker-compose.single-host.yml config --quiet
```

native staging 部署使用命名候选分支或 Tag：

```bash
bash deploy/deploy-staging.sh <candidate-branch-or-tag>
```

脚本使用显式的 SSH 私钥和 `known_hosts`，在 129 上传输外部构建 JAR、初始化共享 logical database/Redis namespace、重启 native app/edge，等待 Flyway/应用健康检查，再验证 HTTPS OIDC discovery；环境文件由宿主机私有配置提供，脚本不会把凭据写入 Git 或命令行。

部署脚本默认通过宿主机 root 的 GitHub SSH 凭据获取官方 Hearth 仓库：`git@github.com:manfredma/hearth.git`。如果 staging 宿主机暂时无法通过 SSH 访问 GitHub，可显式设置 `HEARTH_REPOSITORY_URL`，指向宿主机上的只读 Git mirror/bundle；该覆盖不会改变默认源仓库。

部署脚本会在同一把 `/opt/shared-maven/repository.lock` 全局锁内，使用固定的 Java 25 Maven 镜像预热 `/opt/shared-maven/repository`，再执行 Dockerfile 的离线构建；预热日志中的未登记 `WARN`/`WARNING` 会直接阻断发布。

staging 入口由 124 上共享的 bytedepth-nginx 承载，路由文件见 [`nginx/staging-hearth.conf`](nginx/staging-hearth.conf)。证书路径固定为 `/etc/letsencrypt/live/staging-hearth.bytedepth.cn/`，证书申请与续期必须先在 124 完成，再 reload Nginx。正式部署脚本将在 staging 部署阶段补充，必须遵守不可变版本、完整 compose 重建、集成测试和 E2E 验收顺序。
