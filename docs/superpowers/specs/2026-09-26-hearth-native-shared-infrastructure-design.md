# Hearth native 共享基础设施改造设计

## 目标

将 Hearth 从 Docker-only 运行时迁移到与 ByteDepth、Career、Daylilt、Toolbox 一致的共享宿主机 native 运行方式，并同时完成 staging/production 部署。

## 环境拓扑

| 环境 | 主机 | 域名 | app | edge | MySQL | Redis | 数据根 |
|---|---|---|---:|---:|---|---|---|
| staging | 129 | staging-hearth.bytedepth.cn | 18110 | 18111 | 13306 / hearth | 16379 / DB 5 | /data/hearth-native-staging |
| production | 175 | hearth.bytedepth.cn | 18112 | 18113 | 13306 / hearth | 16379 / DB 6 | /data/hearth-native-production |

共享公网 Nginx 精确按 Host/SNI 路由到 Hearth edge；Hearth 不监听 80/443，也不重启共享 Nginx，只执行 nginx -t 和 reload。

## 配置与隔离

- /etc/hearth/staging-native.env 与 /etc/hearth/production-native.env 由 ubuntu 持有、服务组可读，禁止提交或输出密钥。
- native app 使用外部构建不可变 JAR；/version 必须返回完整构建 SHA、版本和构建时间。
- MySQL 用户分别为 hearth_staging_native、hearth_production_native；Redis logical DB 和 namespace 必须显式注入，不使用默认值。
- staging/production 分别使用 HEARTH_SESSION_COOKIE_NAME、HEARTH_OIDC_ISSUER、HEARTH_SIGNING_KEY、HEARTH_REMEMBER_ME_KEY，禁止跨环境复用。

## 迁移与发布

1. staging 部署前从 124 旧 Hearth MySQL 容器导出限定 hearth database，传输到 129，导入共享 MySQL；Redis Session 不迁移。
2. 129 部署 native app/edge、共享 Nginx route，并验证 HTTPS OIDC discovery、health、登录、OAuth consent、callback、token exchange、logout 和 Career 端到端回调。
3. staging integration/E2E evidence 绑定完整候选 SHA；只有两份 evidence、所有 WARNING 检查和项目所有者验收通过后才合并 main。
4. production 175 首次创建 Hearth logical database/user、Redis DB 6、环境文件、native systemd unit 和 Nginx route；不存在旧 Hearth 流量时不执行 Docker blue 切流。
5. 生产只接受新的 annotated SemVer Tag；发布后验证 public /version、OIDC discovery、TLS SAN、app/edge、MySQL/Redis 隔离和其他项目服务。

## 失败与回退

- staging native 准备失败时保持 124 旧 Docker 资源不变，不能伪造迁移成功。
- production 首次初始化失败时停止 Hearth native unit，保留其他项目和共享中间件；不得 stop/down 其他项目。
- 任意 Redis/MySQL 导入不确定状态都保留状态目录，禁止自动清库重试。
