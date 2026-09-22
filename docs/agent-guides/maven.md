# Maven 与测试

Hearth 固定使用仓库 Maven Wrapper 3.9.11 和 Java 25。禁止裸 `mvn`、浮动 Maven 镜像或依赖人工 `MAVEN_OPTS`。

## 本机质量门禁

```bash
bash scripts/run-local-quality.sh
```

若只需要分别运行多模块 Java 测试：

```bash
./mvnw clean install -DskipTests -Dsort.skip=true
./mvnw test -Dsort.skip=true
./mvnw verify -Dsort.skip=true
```

统一入口同时执行前端安装、Vitest、ESLint、Java 测试、PMD、JaCoCo、部署配置契约和文档契约。所有输出必须没有 `WARNING` 或 `WARN`；出现告警时必须定位、修复或中止。

Java 生产代码的变更分支覆盖率要求为 100%（行、分支、方法）：

```bash
bash scripts/verify-changed-coverage.sh
```

本机只运行不依赖独立进程的单元测试。MySQL、Redis、Flyway、Docker、OIDC 和浏览器组成的集成验证必须在 staging 执行，不能用本机临时服务替代。

## 构建与运行

```bash
./mvnw clean package -DskipTests -Dsort.skip=true
java --enable-native-access=ALL-UNNAMED -jar hearth-start/target/hearth-start.jar
```

前端依赖必须在每个 worktree 内用 lockfile 安装：

```bash
npm ci --ignore-scripts --no-audit --no-fund
```

不得跨项目共享 `node_modules`。前端构建产物由 Docker 构建阶段生成，不提交到 Git。
