# docs/adr

可选目录，用来放架构决策记录（ADR）。

ADR 是一份短文档，写下一次取舍的背景、选了什么、代价是什么；通常一份决策一个 Markdown 文件，按序号命名（例如 `0002-compose-orchestration.md`）。

它在本仓库里的位置是「长期记录」：与 `clients/`、`services/` 这些随产品演进的代码目录分开，也不参与构建和 CI。不用这类记录时，整个目录可以删掉；想用时随手加文件即可。

## 现有记录

- [0001-infra-vs-deploy.md](0001-infra-vs-deploy.md)：按"本地每天跑"把 `infra/` 与 `deploy/` 切开
- [0002-compose-orchestration.md](0002-compose-orchestration.md)：编排下沉到 compose 与镜像，just 只保留别名（模板建议）
