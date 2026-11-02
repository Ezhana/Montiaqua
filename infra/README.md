# infra/

本机开发环境层：本地开发者每天跑的那部分基础设施。`infra/compose/` 是本地编排的唯一声明处——服务、依赖顺序、端口、环境变量都写在 compose 里；根 `justfile` 只是把 `docker compose` 命令包成短别名（`just up`、`just logs`），删掉它不丢任何能力。编排选型见 [docs/adr/0002-compose-orchestration.md](../docs/adr/0002-compose-orchestration.md)。

## 判断标准

一份文件要不要放进 `infra/`，只问一个问题：**这份文件会不会被本地开发者每天跑？**

- 会——本地拉起依赖、直连端口、灌种子数据，放 `infra/`。
- 不会——只被平台、CI 或发布流程在非本地环境消费，放 `deploy/`（见 [deploy/README.md](../deploy/README.md)）。

这条标准比"文件名里带没带 dev"更可靠：同样是 compose 语法，能 `build:` 当前代码的属于本地，只能引用 `image:` 的属于部署；两者不共用同一份文件。

## 放什么

- 本地编排：`infra/compose/compose.yaml`，允许 `build:`
- 本地配置与弱密钥模板：`infra/env/.env.example`，复制成 `infra/env/.env` 使用（`.env` 已被 `.gitignore` 忽略）
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
7. **别名可选。** `justfile` 只做一层转发，删掉它直接敲 `docker compose` 完全等价；别名里不放编排逻辑。

## 结构

```text
infra/
├── compose/
│   ├── compose.yaml            # 本地主编排：services / depends_on / ports / env，允许 build:
│   └── compose.override.yaml   # 可选覆盖：端口直通、调试、挂载
├── env/
│   └── .env.example            # 本地弱密钥模板，复制成 env/.env 使用（.env 已忽略）
├── seed/                       # 本地种子数据与初始化脚本
└── terraform/                  # 预留：云资源定义（见下节），不与 compose 混放
```

`compose.yaml` 当前是骨架：`name: montiaqua` 加一个空的 `services: {}`，文件里留了加服务时的示例注释。第一个服务落地时把注释改成真实条目即可，`justfile` 不需要改。

本地变量只需准备一次：

```bash
cp infra/env/.env.example infra/env/.env
```

## 编排分工

编排能力只往两处放：compose（声明式）与项目 `Dockerfile`（命令式）。根 `justfile` 是别名层，不是调度器；以下每条都是这条分工的推论，理由与代价见 [ADR 0002](../docs/adr/0002-compose-orchestration.md)。

- **依赖顺序** 用 `depends_on` + healthcheck 表达，不写脚本 sleep 等待、不用外部调度器。
- **lint / test** 放进 `Dockerfile` 的构建阶段，CI 构建镜像时顺带执行；不另设"跑测试"的编排入口。
- **一次性任务**（代码生成、边界检查）用 `profiles: ["tools"]` 声明成服务，`just run gen-api` 执行，不进入 `just up` 的常驻集合。
- **不在 `justfile` 里加**项目发现、循环、批量执行、`git diff` 变更筛选——这些是编排逻辑，属于 compose 与 Dockerfile。

compose 里各字段的写法（`build.context`、`image`、`env_file`、`depends_on`）见 [clients/README.md](../clients/README.md)、[services/README.md](../services/README.md) 与 [tools/README.md](../tools/README.md)。

## Terraform / 云资源

将来引入 Terraform 或其他云资源定义时，放 `infra/terraform/`（或独立成 `platform/`），不要把它和应用清单混进同一层：

- `infra/compose/` 是"每天跑的本地环境"，生命周期以小时计；
- `infra/terraform/` 是"低频变更的云资源"，生命周期以月计，权限与审批边界也不同。

两者即使都在 `infra/` 下也仍然分层：根层只放本地开发编排，terraform 作为独立子目录；如果云资源变多，整体迁到独立 `platform/`，`infra/` 保持纯本地。无论如何，不要把 terraform 放进 `deploy/` 跟 k8s / helm 清单混排——一个管"环境怎么搭"，一个管"应用怎么跑"。

完整决策与代价见 [docs/adr/0001-infra-vs-deploy.md](../docs/adr/0001-infra-vs-deploy.md)。

## 与相邻目录的关系

- `deploy/` 是非本地环境的镜像化清单，与 `infra/` 互不复用文件、互不引用变量。
- `clients/` 与 `services/` 的代码由本地 compose 直接 build 进容器，不需要先发镜像。
- `seed/` 需要生成数据时，可以调用 `tools/` 里的工具镜像（compose `profiles` 一次性任务），但数据本身仍放在 `infra/seed/`。
- 根 `justfile` 只把 `docker compose` 包成短别名；逻辑在 compose 与 Dockerfile 里，别名可以删。
