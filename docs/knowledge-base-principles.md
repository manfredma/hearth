# Hearth 知识库建设原则

`docs/README.md` 是知识库入口，架构取舍进入版本化 ADR，长期约束进入工程指南，部署细节只进入 `deploy/README.md`。

文档必须与当前 Hearth 代码一致，不复制业务系统的数据库、权限规则或私有凭据。模板继承的通用 Maven、Git、测试规则可以保留，但已经失效的博客、Obsidian、RSS 和旧域名说明必须删除或明确标为迁移背景。
