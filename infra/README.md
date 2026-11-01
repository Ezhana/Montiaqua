# infra/

本机开发环境层：本地开发者每天跑的那部分基础设施。用 `docker compose` 把依赖和服务拉起来，端口直通到宿主机，库从种子数据起，密钥是只在本机有效的弱口令。仓库当前只有这份说明，还没有子目录。

## 判断标准

一份文件要不要放进 `infra/`，只问一个问题：**这份文件会不会被本地开发者每天跑？**

- 会——本地拉起依赖、直连端口、灌种子数据，放 `infra/`。
- 不会——只被平台、CI 或发布流程在非本地环境消费，放 `deploy/`（见 [deploy/README.md](../deploy/README.md)）。

这条标准比"文件名里带没带 dev"更可靠：同样是 compose 语法，能 `build:` 当前代码的属于本地，只能引用 `image:` 的属于部署；两者不共用同一份文件。

## 放什么

- 本地编排：`docker-compose` 文件（`infra/compose/`），允许 `build:`
- 本地配置与弱密钥模板：`infra/env/*.example`，值只对 localhost 有意义
- 端口直通：宿主机端口映射，方便 curl、浏览器和调试器直接连
- 种子数据与初始化：数据库 seed、fixture、首次启动的 bootstrap
- 本地依赖的编排：数据库、消息队列、对象存储等在本机的替身

## 硬规则

1. **只服务本机。** 目标是 localhost；不写真实域名、云上端点、生产或预发地址。
2. **允许 `build:`。** 本地要跑的是工作区当前的代码，构建是正常路径，也是 `infra/` 与 `deploy/` 最明确的区别。
3. **弱密钥只在本机有效。** 可以用固定口令、默认账号、关闭鉴权，但要在文件里显式注明"仅本地"；`deploy/` 不得引用这些值。
4. **端口直通是允许的，甚至是期望的。** 每个服务把端口映射到宿主机，便于直接用浏览器、curl 和调试器访问。
5. **允许 seed 数据。** 本地库从种子数据起，或用内存 / 临时卷都行，不用模拟生产的持久化规格。
6. **不承担发布。** `infra/` 不产出发布镜像、不写发布脚本、不被 `deploy/` 复用；真实密钥和生产账号只在 CI secret 与外部密钥管理里。

`.env` 已被 `.gitignore` 忽略；本地模板用 `*.example` 提交，真实值留空或写占位符。

## 结构

```text
infra/
├── compose/
│   ├── compose.yaml            # 本地主编排，允许 build:
│   └── compose.override.yaml   # 本地覆盖：端口直通、调试、挂载
├── env/
│   └── local.env.example       # 本地弱密钥模板，仅 localhost 有效
├── seed/                       # 本地种子数据与初始化脚本
└── terraform/                  # 预留：云资源定义（见下节），不与 compose 混放
```

按需创建，不必一次齐全。

## Terraform / 云资源

将来引入 Terraform 或其他云资源定义时，放 `infra/terraform/`（或独立成 `platform/`），不要把它和应用清单混进同一层：

- `infra/compose/` 是"每天跑的本地环境"，生命周期以小时计；
- `infra/terraform/` 是"低频变更的云资源"，生命周期以月计，权限与审批边界也不同。

两者即使都在 `infra/` 下也仍然分层：根层只放本地开发编排，terraform 作为独立子目录；如果云资源变多，整体迁到独立 `platform/`，`infra/` 保持纯本地。无论如何，不要把 terraform 放进 `deploy/` 跟 k8s / helm 清单混排——一个管"环境怎么搭"，一个管"应用怎么跑"。

完整决策与代价见 [docs/adr/0001-infra-vs-deploy.md](../docs/adr/0001-infra-vs-deploy.md)。

## 与相邻目录的关系

- `deploy/` 是非本地环境的镜像化清单，与 `infra/` 互不复用文件、互不引用变量。
- `clients/` 与 `services/` 的代码由本地 compose 直接 build 进容器，不需要先发镜像。
- `seed/` 需要生成数据时，可以调用 `tools/` 里的脚本，但数据本身仍放在 `infra/seed/`。
- 根 `justfile` 可以把 `up` 这类命令包成短别名，但逻辑仍在 compose 与项目 target 里。
