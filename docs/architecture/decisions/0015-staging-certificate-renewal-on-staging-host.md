# ADR-0015: Staging TLS 证书由 staging 宿主机本地续期

- 状态：Accepted
- 日期：2026-09-27

## 背景

Hearth staging 已迁移到 129，`staging-hearth.bytedepth.cn` 的有效证书和 active TLS bundle 也位于 129。124 不再是 Hearth staging 主机。原发布脚本仍从 124 复制证书，导致 staging 发布依赖已退役主机的 SSH 可用性和证书目录；而 129 上已有 Certbot、ACME account 和自动续期 timer，但未纳管 Hearth staging lineage。

## 决策

- 129 是 Hearth staging TLS 证书的唯一签发与续期主机。
- Hearth 使用自己的 Certbot config/work/log/webroot 和 systemd timer，文件归 `ubuntu`；ACME HTTP-01 challenge 由 Hearth staging 的 Nginx route 提供。把 129 已有证书登记为 Certbot lineage，并通过 ACME staging endpoint dry-run 验证，不重新申请生产证书。
- 续期 hook 校验证书 SAN、有效期和私钥匹配后，写入 Hearth 版本化 TLS release，原子更新 `current`，再检查并 graceful reload 共享 `nginx.service`。
- 常规 staging 部署只确认 Hearth 证书有效且 renewal timer 已启用，不连接 124，也不复制证书。
- 124 只作为旧数据迁移来源，不再被视为 staging、证书源或部署前置条件。
- ByteDepth 的真实域名、共享 Redis/MySQL/Nginx 资源标识以及其他业务应用标识保持原名；只将 Hearth 自有包、路径、服务、配置和发布资源命名为 Hearth。

## 后果

- 129 的 staging 证书续期不依赖 124；首次建立 Certbot lineage 仅登记现有证书，并以 ACME staging dry-run 验证 webroot 配置，不触发新的生产证书签发。
- 续期 hook 只 reload 公共 Nginx，不停止或更改其他项目。
- 证书问题会在部署前 fail-closed，不以跨主机临时拷贝作为恢复路径。
