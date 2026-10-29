# Hearth 平台发布流程

AI Agent 负责在独立 worktree 内修改、测试并提交 PR；Host Agent 只执行 release-platform 签名任务。项目仓库不执行发布、回滚、Tag、SSH 或远程部署脚本。

`PR head 完整 SHA → canonical QUALITY/BUILD → staging → integration/E2E → 项目所有者验收 → 平台 fast-forward 同一 SHA → 同一制品 production`

项目为 `manfredma/hearth`，平台 slug 为 `hearth`，适配器为已登记的 `hearth-v1`。控制面只使用 [devops.bytedepth.cn](https://devops.bytedepth.cn)，不向 staging-devops 发送发布写请求。首次 PR 保留非空分类 Unreleased；创建正式候选前按 [版本准备](../releases/README.md)冻结 Changelog，并把该变更提交到同一 PR。候选 sourceRef 使用 `refs/pull/<编号>/head`；创建前核对 worktree HEAD、GitHub PR head 与完整 SHA 一致。

登录、Token、API、幂等键、轮询、重试、验收与 production 操作，以 canonical [Agent 手册](https://devops.bytedepth.cn/manual/agent)为唯一事实来源。复用 PATH 中的 `release-platform-agent-auth` 验证管理员 Agent Token，禁止输出 Token 或使用 Host Agent Token 代替。每次 mutation 保留 request ID 与稳定幂等键。

发布依据是 candidate、完整 SHA、artifact digest、各 task/attempt、日志与 evidence；本地测试不能替代 staging。按服务端 Retry-After/nextPollAfterMs 轮询，失败先定位结构化原因，不重复构建或手改状态。staging 技术验证通过后，按 [ADR-0013](../architecture/decisions/0013-agent-validation-and-owner-acceptance-boundary.md)等待业务放行，再提交 acceptance；平台自动合并、打 Tag 并晋级同一制品。
