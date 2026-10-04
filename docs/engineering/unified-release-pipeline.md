# Hearth 平台发布流程

AI Agent 负责在 Hearth 仓库内修改代码、运行本地质量门禁和提交 PR；Host Agent 负责在目标主机执行 release-platform 签名任务。项目仓库不执行发布、回滚、Tag、SSH 或远程部署脚本。

```text
独立 worktree → 本地质量检查 → PR 合并 → release-platform 按完整 SHA 构建
→ staging 发布与页面验收 → 同一不可变制品提升 production
```

staging 是跨进程验收环境。发布、日志、重试、版本校验和回滚都在 release-platform 页面完成；项目内的 `deploy/` 仅保留一次性基础设施初始化、数据迁移和测试辅助脚本。
