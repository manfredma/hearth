# ADR-0014: Hearth 复用共享宿主机 native 基础设施

- **状态**: Proposed
- **日期**: 2026-09-26
- **决策者**: Hearth 项目所有者与维护团队

## 背景

Hearth 当前使用 Docker Compose，staging 运行在 124；生产尚未发布。ByteDepth、Career、Daylilt 和 Toolbox 已在 129/175 使用共享宿主机 native 基础设施。继续为 Hearth 启动独立 MySQL、Redis、应用边缘和公网 Nginx 会重复占用资源，并增加同机端口、路由和重启风险。

## 决策

1. Hearth staging 部署到 129，production 部署到 175；两个环境均由宿主机 systemd 管理 Java 25 应用和项目专属内部 edge，公网 80/443 只由共享 Nginx 持有。
2. Hearth 复用共享 MySQL 127.0.0.1:13306，但只使用 hearth logical database、环境专属数据库用户和凭据。
3. Hearth 复用共享 Redis 127.0.0.1:16379，staging 使用 logical DB 5、production 使用 logical DB 6，并同时使用 hearth:staging: / hearth:production: namespace。
4. 端口固定为 staging app/edge 18110/18111，production app/edge 18112/18113；不得绑定 80/443 或占用现有项目端口。
5. 项目目录、配置、发布制品、日志、测试资源和运行数据由 ubuntu 持有；服务用户 hearth 只通过专属服务组获得必要写权限。
6. staging 从 124 旧 Docker MySQL 只迁移 hearth logical database；Redis Session 不迁移。production 没有既有 Hearth 线上数据，首次部署只初始化空 logical database。
7. 任一 native 前置检查、数据迁移、健康检查、TLS/SNI 或只读验收失败，都不得影响其他项目。

## 资源映射

| 资源 | Hearth staging | Hearth production | 隔离方式 |
|---|---:|---:|---|
| MySQL | 13306 / hearth / hearth_staging_native | 13306 / hearth / hearth_production_native | logical database + user |
| Redis | 16379 / DB 5 / hearth:staging: | 16379 / DB 6 / hearth:production: | logical DB + key namespace |
| app | 18110 | 18112 | 独立 systemd unit |
| edge | 18111 | 18113 | 独立 systemd unit |
| 数据根 | /data/hearth-native-staging | /data/hearth-native-production | 独立目录 |

## 后果

- Hearth 不再重复运行 MySQL、Redis 或公网 Nginx，内存和端口预算纳入现有多服务宿主机。
- staging/production 的身份数据、Session、OIDC 配置和密钥仍然完全隔离。
- 需要维护 native systemd、迁移、Nginx、Redis logical DB/namespace 和 commit-bound staging evidence 契约。
