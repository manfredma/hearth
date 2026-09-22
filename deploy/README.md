# Hearth 部署说明

Hearth 是统一身份服务。生产与 staging 必须使用不同的数据目录、Redis namespace、session cookie 和 OIDC client；staging 不得复用生产凭据或数据库。

## 配置

复制 `deploy/.env.example` 或 `deploy/.env.staging.example` 为宿主机私有的 `.env`，并由部署系统注入真正的密码和 OIDC secret。不要把 `.env` 提交到仓库。`HEARTH_COMMIT_ID` 与 `HEARTH_BUILT_AT` 必须由发布流程显式注入，不接受隐式默认值。

生产使用 `docker-compose.single-host.yml`，staging 使用它叠加 `docker-compose.staging.yml`。服务名统一带 `hearth-` 前缀，避免与同机其他项目的 compose DNS 别名冲突。

## 验证边界

本机只执行静态配置检查和 `docker compose config` 语法检查；MySQL、Redis、Flyway、OIDC 的跨进程验收必须在 staging 完成。发布前先执行：

```bash
bash scripts/test-deploy-hearth-config.sh
docker compose --env-file deploy/.env -f deploy/docker-compose.single-host.yml config --quiet
```

正式部署脚本将在 staging 部署阶段补充，必须遵守不可变版本、完整 compose 重建、集成测试和 E2E 验收顺序。
