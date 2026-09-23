# ADR-0007: MySQL 身份键保留原文并使用哈希联合唯一索引

- **状态**: Accepted
- **日期**: 2026-09-23
- **决策者**: 项目所有者

## 上下文

`issuer + subject` 是 Hearth 的稳定身份键。MySQL 8 的 utf8mb4 InnoDB 联合索引上限为 3072 字节；如果直接对两个 512 字符字段建立唯一索引，首次 staging 迁移会失败。

## 决策

`user_identity` 保留完整的 `issuer` 与 `subject` 原文，分别通过 MySQL 生成列计算 SHA-256 二进制值，并对两个 32 字节哈希建立联合唯一索引。`application_redirect_uri` 同样保留完整的 Redirect URI 原文，以生成的 SHA-256 二进制值和 application id 建立主键。应用查询仍使用原文，哈希列只承担索引约束，不写入或暴露给业务层。

## 后果

- 支持较长的标准 issuer、subject 和 Redirect URI，同时遵守 InnoDB 索引长度限制。
- 原始身份键仍可审计和回读；查询路径无需感知存储优化。
- 哈希碰撞属于极低概率风险；如果未来安全审计要求消除该风险，应迁移到专用二进制身份键或经过验证的规范化键，而不是静默放宽索引。

## 验证

- `MigrationScriptsTest` 固化生成列和索引约束。
- staging 必须实际执行 Flyway V1，并检查应用健康检查与 OIDC Discovery。
