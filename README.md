# Montiaqua

[English](README.en.md) | 简体中文

## 名字

**Montiaqua** /mɒnˈtiːəkwə/，mont（山）+ aqua（水）：从高山发源、广布的水源——山原巨水。模板沿用了这个意象：从一个源头出发，铺开成一张多语言的水系。

Montiaqua 是一个多语言 monorepo 的 GitHub Template Repository，用来承载 clients 与 services。它只提供骨架：根目录放别名和说明，项目在需要时加入，由 Docker Compose 统一编排。

## 设计

- **根目录不承载编排逻辑。** `justfile` 只把 `docker compose` 与 registry 命令包成短别名（`just up`、`just logs`、`just push` …），删掉它不丢任何能力。编排的"脑子"只有两处：
  - `infra/compose/compose.yaml`：声明式——服务、依赖顺序、端口、环境变量、一次性任务；
  - 各项目的 `Dockerfile`：命令式——镜像怎么构建、lint / test 在哪个构建阶段跑。
- **这是模板建议。** 想加一条编排能力，先看能不能放进 compose 或 Dockerfile；能放就不进别名，放不进去才加别名，而别名只做一层转发。取舍见 [ADR 0002](docs/adr/0002-compose-orchestration.md)。
- **项目 = Dockerfile + 自带工具链。** 加一个项目 = 建目录、放 `Dockerfile` 和它自己的构建文件、在 compose 里加一个 service；根目录没有项目清单，也不用改 `justfile`。语言、构建工具和版本随项目自己的构建文件走。
- **跨语言靠契约与镜像。** 接口放在 `services/contracts`（OpenAPI / proto / JSON Schema），客户端与服务端消费同一份契约，生成代码由 `tools/gen-api` 产出；运行单元是镜像，服务之间用 compose network 通信。
- **环境按"本地每天跑"分层。** `infra/` 只服务本机开发，`deploy/` 只服务非本地环境；判断标准是"这份文件会不会被本地开发者每天跑"。
- **CI 全量构建镜像。** 没有 affected：CI 直接 `docker compose build` / `push`，增量靠镜像层缓存；仓库还没有服务时只校验 compose 文件，空跑绿灯。

## 目录

```text
/
├── README.md                     # 本文件（中文）
├── README.en.md                  # 英文版
├── LICENSE
├── .gitignore                    # 多语言通用忽略
├── .editorconfig                 # 跨语言缩进 / 换行
├── justfile                      # 只把 docker compose / registry 命令包成短别名
│
├── clients/README.md             # web / desktop / mobile / bff 的位置
├── services/README.md            # java-api / python-api / contracts 的位置
├── infra/
│   ├── README.md                 # 本机开发：compose / 弱密钥 / 端口直通 / seed
│   ├── compose/compose.yaml      # 本地编排声明处：服务 / 依赖 / 端口 / 环境
│   └── env/.env.example          # 本地变量模板，复制成 .env 使用
├── deploy/README.md              # 非本地环境：image: 清单 / 外部注入密钥
├── tools/README.md               # gen-api、边界校验等一次性任务的位置
│
├── docs/
│   └── adr/
│       ├── README.md             # 可选：架构决策记录
│       ├── 0001-infra-vs-deploy.md        # 分层规则：本地开发 vs 非本地部署
│       └── 0002-compose-orchestration.md  # 编排选型：compose + 镜像，just 只做别名
│
└── .github/workflows/ci.yml      # 校验 compose，并检查层规则
```

`clients/`、`services/`、`deploy/`、`tools/` 下目前只有各自的 README；`infra/` 已有 compose 与 env 骨架（`services` 为空）。`docs/adr/` 除说明外有两条记录：`0001` 分层规则与 `0002` 编排选型；`docs/adr` 仍是可选目录，不用可以连同记录一起删掉。

## 用法

前置只有 Docker（compose v2）与 `just`。`just` 是纯别名层，不装也能直接用 `docker compose` 完成同样的事。

```bash
just --list      # 列出全部别名
just up          # docker compose up -d
just ps          # 查看容器状态
just logs java-api
just down        # 停止并移除容器、网络
```

本地环境：把 `infra/env/.env.example` 复制成 `infra/env/.env`（只需一次）。服务、依赖顺序、端口和环境变量都写在 `infra/compose/compose.yaml`。

加一个服务，三步：

1. 在项目目录写 `Dockerfile`：多阶段构建，构建阶段跑 lint / test，运行时阶段只带产物。
2. 在 `infra/compose/compose.yaml` 的 `services:` 下加一条：`build.context` 指向项目目录，端口直通到宿主机。
3. `just up <服务名>`。

镜像与 registry：

```bash
just build       # docker compose build
just push        # docker compose push，镜像名来自 compose 里的 image:
just pull        # docker compose pull
```

别名表——每个别名都只是一层转发：

| 别名 | 等价命令 |
| --- | --- |
| `just up [服务…]` | `docker compose up -d` |
| `just rebuild [服务…]` | `docker compose up -d --build` |
| `just down` | `docker compose down --remove-orphans` |
| `just restart [服务…]` | `docker compose restart` |
| `just ps` / `just logs [服务…]` | `docker compose ps` / `docker compose logs -f` |
| `just build [服务…]` / `just run …` / `just sh <服务>` | `docker compose build` / `run --rm` / `exec … sh` |
| `just config` | `docker compose config -q` |
| `just push [服务…]` / `just pull [服务…]` / `just login [registry]` | `docker compose push` / `pull`、`docker login` |

编排分工的建议：

- 依赖顺序写 compose 的 `depends_on` + healthcheck，不写脚本 sleep 等待。
- lint / test 放进 `Dockerfile` 的构建阶段，CI 构建镜像时顺带执行。
- 代码生成、边界检查这类一次性任务，用 compose `profiles` 声明成服务，`just run gen-api` 执行。
- 不要在 `justfile` 里加项目发现、循环、批量、变更筛选——那是编排逻辑，属于 compose 与 Dockerfile。

## 环境分层：infra/ 与 deploy/

仓库按环境切成两层，判断标准只有一句话：**这份文件会不会被本地开发者每天跑？**

| 目录 | 服务谁 | 允许 | 禁止 |
| --- | --- | --- | --- |
| `infra/` | 本机开发（localhost） | `build:`、弱密钥、端口直通、seed 数据 | 真实密钥、云上地址、发布逻辑 |
| `deploy/` | 非本地环境（staging / prod 等） | `image:`、外部注入的密钥键名 | `build:`、装依赖、提交真实密钥 |

- 本地编排、弱口令和种子数据放 `infra/`，见 [infra/README.md](infra/README.md)；`deploy/` 只放 Kubernetes / Helm 等镜像化清单，见 [deploy/README.md](deploy/README.md)。
- 两层不共享文件、不共享变量；`deploy/` 的 YAML 里出现 `build:` 会被 CI 的层规则检查拦下。
- 镜像由 CI 按 compose 声明构建并推 registry，`deploy/` 只消费 `image:`，不重复构建。
- 将来引入 Terraform / 云资源定义，放 `infra/terraform/`（或独立 `platform/`），不要和应用清单混进同一层：本地环境以小时计、云资源以月计，生命周期与权限边界不同。理由与代价见 [docs/adr/0001-infra-vs-deploy.md](docs/adr/0001-infra-vs-deploy.md)。

## 许可证

[MIT](LICENSE)
