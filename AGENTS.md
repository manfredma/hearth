# Hearth

Spring Boot 多模块统一身份服务（DDD 分层）+ React/Vite 管理端。Hearth 负责统一认证、身份目录和应用级访问；业务系统负责自己的功能、资源和数据权限。项目知识库入口见 `docs/README.md`，唯一部署说明见 `deploy/README.md`。

## 必须遵守

- 不允许在 `main` 直接开发。功能、修复和文档改动必须在独立 `feat/*`、`fix/*` 或 `docs/*` 分支的 Git worktree 中完成；合并后立即删除 worktree。
- Maven 固定使用仓库 Wrapper 3.9.11，Java 固定 25；本机、CI、Docker 都不得使用裸 `mvn` 或浮动 Maven 镜像。运行 `bash scripts/test-maven-runtime.sh` 验证。
- 新建或切换 worktree 后，运行前端测试、lint 或 Playwright 前必须先执行 `npm ci --ignore-scripts --no-audit --no-fund`。
- 不得忽略构建、测试、静态分析或部署输出中的 `WARNING`/`WARN`。发现后必须定位并修复，不能把带告警的结果称为成功。
- 改完代码必须跑测试；新增业务逻辑分支需要单元测试，模块覆盖率门禁必须通过。
- 不新增 Maven 模块；只能在现有 `hearth-domain`、`hearth-app`、`hearth-infrastructure`、`hearth-adapter`、`hearth-start` 五个模块内实现。
- 跨进程的 MySQL、Redis、Flyway、Docker、OIDC、Nginx 集成测试只能在 staging 执行；本机只执行断网单元测试、mock/fake、静态检查和配置语法检查。
- 私人身份和业务数据不得写入 `localStorage`、IndexedDB 或其他浏览器持久化存储；浏览器只保留 HttpOnly Session Cookie。
- Hearth 不保存业务系统密码。身份主键必须是经过验证的 `issuer + subject`，不能用用户名或邮箱自动合并身份。
- 生产与 staging 必须隔离 MySQL 数据目录、Redis namespace、Session Cookie、OIDC client、OIDC secret 和回调地址。
- Compose 服务名必须带 `hearth-` 前缀，禁止使用通用 `app`、`web` 等别名；完整 Compose 服务必须重建启动，不能只启动单个容器。
- 任何用户可见、运行时、配置或部署变更，首次 staging 前必须先写入 `docs/releases/CHANGELOG.md` 的非空分类 `## Unreleased`。
- 涉及模块边界、外部接口、OIDC、身份主键或长期约束的设计，必须先写 ADR（`docs/architecture/decisions/`），再写 spec 和代码。

## 质量入口

```bash
bash scripts/run-local-quality.sh
```

它会执行变更记录、命名、Maven、前端测试/lint、覆盖率、部署配置和 `git diff --check` 门禁。真实 staging 验收须使用部署手册中的 staging 流程，不能以本机页面作为最终验收依据。

## 命名与架构

- 运行时变量统一使用 `HEARTH_`；包名与 Maven 坐标统一使用 `manfred.hearth`。
- `domain` 不依赖框架、Web 或基础设施；`app` 定义端口和用例；`infrastructure` 实现 MySQL/Redis 端口；`adapter` 处理 OIDC、Session API 和 Web；`start` 负责启动、迁移和打包。
- React 组件与样式必须自隔离；环境样式放在实际承载组件且所有使用页面都会加载的样式文件中。
- 变更发现的新流程错误必须沉淀到项目文档并补充可重复自动检查，不能依赖会话记忆。
