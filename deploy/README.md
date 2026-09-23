# Hearth 部署说明

Hearth 是统一身份服务。staging 入口为 `https://staging-hearth.bytedepth.cn/`。生产与 staging 必须使用不同的数据目录、Redis namespace、session cookie、issuer 和签名密钥；staging 不得复用生产凭据或数据库。

## 配置

复制 `deploy/.env.example` 或 `deploy/.env.staging.example` 为宿主机私有的 `.env`，并由部署系统注入真正的数据库、Redis 和 RSA 私钥配置。`HEARTH_SIGNING_KEY` 使用 base64 编码的 PKCS#8 RSA 私钥 DER，私钥不得提交到仓库。不要把 `.env` 提交到仓库。`HEARTH_COMMIT_ID` 与 `HEARTH_BUILT_AT` 必须由发布流程显式注入，不接受隐式默认值。

生产使用 `docker-compose.single-host.yml`，staging 使用它叠加 `docker-compose.staging.yml`。服务名统一带 `hearth-` 前缀，避免与同机其他项目的 compose DNS 别名冲突；只有 `hearth-app` 接入共享 `bytedepth_default` 网络供边缘 Nginx 反向代理，MySQL/Redis 保持在 Hearth 私有网络。

## 验证边界

本机只执行静态配置检查和 `docker compose config` 语法检查；MySQL、Redis、Flyway、OIDC 的跨进程验收必须在 staging 完成。发布前先执行：

```bash
bash scripts/test-deploy-hearth-config.sh
docker compose --env-file deploy/.env -f deploy/docker-compose.single-host.yml config --quiet
```

staging 部署使用命名分支或 Tag：

```bash
bash deploy/deploy-staging.sh <candidate-branch-or-tag>
```

脚本使用显式的 SSH 私钥和 `known_hosts`，在 124 上获取候选 ref，重建完整 Compose 服务，等待 Flyway/应用健康检查，再验证 HTTPS OIDC discovery；staging 的 `.env` 由宿主机私有配置提供，脚本不会把凭据写入 Git 或命令行。

如果 staging 宿主机暂时无法访问 GitHub，可通过 `HEARTH_REPOSITORY_URL` 指向宿主机上的只读 Git mirror/bundle；默认仍使用官方 Hearth GitHub 仓库。

部署脚本会在同一把 `/opt/shared-maven/repository.lock` 全局锁内，使用固定的 Java 25 Maven 镜像预热 `/opt/shared-maven/repository`，再执行 Dockerfile 的离线构建；预热日志中的未登记 `WARN`/`WARNING` 会直接阻断发布。

staging 入口由 124 上共享的 bytedepth-nginx 承载，路由文件见 [`nginx/staging-hearth.conf`](nginx/staging-hearth.conf)。证书路径固定为 `/etc/letsencrypt/live/staging-hearth.bytedepth.cn/`，证书申请与续期必须先在 124 完成，再 reload Nginx。正式部署脚本将在 staging 部署阶段补充，必须遵守不可变版本、完整 compose 重建、集成测试和 E2E 验收顺序。
