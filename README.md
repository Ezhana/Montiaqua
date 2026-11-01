# Montiaqua

[English](README.en.md) | 简体中文

## 名字

**Montiaqua** /mɒnˈtiːəkwə/，mont（山）+ aqua（水）：从高山发源、广布的水源——山原巨水。模板沿用了这个意象：从一个源头出发，铺开成一张多语言的水系。

Montiaqua 是一个多语言 monorepo 的 GitHub Template Repository，用来承载 clients 与 services。它只提供骨架：根目录放编排配置和说明，项目在需要时加入，由 Nx 统一调度。

## 设计

- **根目录只做编排。** `nx.json` 描述 target 的缓存与顺序（`namedInputs` / `targetDefaults`），`justfile` 是一层可选的命令别名，`.github/workflows/ci.yml` 是 CI 占位。
- **项目由 `project.json` 定义。** 每个 client、service、contracts 项目在自己的目录里放一个 `project.json`，Nx 自动发现；根目录没有项目清单。
- **项目自带工具链。** 根目录没有 `package.json`、lockfile 或版本文件，语言、构建工具和版本随各个项目自己的构建文件走。
- **跨语言靠契约。** 接口放在 `services/contracts`（OpenAPI / proto / JSON Schema），客户端与服务端消费同一份契约，生成代码由 `tools/gen-api` 产出。
- **环境按"本地每天跑"分层。** `infra/` 只服务本机开发，`deploy/` 只服务非本地环境；判断标准是"这份文件会不会被本地开发者每天跑"。
- **CI 只看变更。** `nx affected` 让 CI 只跑受影响的项目；仓库还没有项目时，这条流水线空跑通过。

## 目录

```text
/
├── README.md                     # 本文件（中文）
├── README.en.md                  # 英文版
├── LICENSE
├── .gitignore                    # 多语言通用忽略
├── .editorconfig                 # 跨语言缩进 / 换行
├── nx.json                       # Nx：namedInputs / targetDefaults
├── justfile                      # 可选的命令别名
│
├── clients/README.md             # web / desktop / mobile / bff 的位置
├── services/README.md            # java-api / python-api / contracts 的位置
├── infra/README.md               # 本机开发环境：compose / 弱密钥 / 端口直通 / seed
├── deploy/README.md              # 非本地环境：image: 清单 / 外部注入密钥
├── tools/README.md               # gen-api、边界校验等脚本的位置
│
├── docs/
│   └── adr/
│       ├── README.md             # 可选：架构决策记录
│       └── 0001-infra-vs-deploy.md  # 分层规则：本地开发 vs 非本地部署
│
└── .github/workflows/ci.yml      # 占位：安装 Nx 后跑 affected，并检查层规则
```

`clients/`、`services/`、`infra/`、`deploy/`、`tools/` 下目前只有各自的 README，没有子目录；`docs/adr/` 除说明外只有一条分层决策。`docs/adr` 仍是可选目录，不用可以连同记录一起删掉。

## 用法

```bash
npm install --global nx     # 从模板创建仓库后；也可以直接用 npx nx
nx graph                    # 此时是一张空图
```

加一个项目，是建一个目录、在其中放一个 `project.json`（以 web 客户端为例）：

```json
{
  "name": "web-portal",
  "projectType": "application",
  "sourceRoot": "clients/web-portal/src",
  "targets": {
    "serve": { "executor": "nx:run-commands", "options": { "command": "npm run dev", "cwd": "clients/web-portal" } },
    "build": { "executor": "nx:run-commands", "options": { "command": "npm run build", "cwd": "clients/web-portal" } },
    "lint": { "executor": "nx:run-commands", "options": { "command": "npm run lint", "cwd": "clients/web-portal" } },
    "test": { "executor": "nx:run-commands", "options": { "command": "npm run test", "cwd": "clients/web-portal" } }
  }
}
```

```bash
nx show projects            # 列出 Nx 发现的项目
nx run web-portal:build
```

目录名的惯例是 `clients/<platform>-<name>`（web / desktop / mobile / bff）和 `services/<language>-<name>`（java / python / go / node …），契约固定在 `services/contracts`。target 名沿用 `lint`、`test`、`build`、`e2e`、`typecheck`、`serve`：`nx.json` 按这些名字配置缓存与顺序，`build` 会先跑上游依赖的 `build`，`serve` 是常驻进程、不缓存。

## 环境分层：infra/ 与 deploy/

仓库按环境切成两层，判断标准只有一句话：**这份文件会不会被本地开发者每天跑？**

| 目录 | 服务谁 | 允许 | 禁止 |
| --- | --- | --- | --- |
| `infra/` | 本机开发（localhost） | `build:`、弱密钥、端口直通、seed 数据 | 真实密钥、云上地址、发布逻辑 |
| `deploy/` | 非本地环境（staging / prod 等） | `image:`、外部注入的密钥键名 | `build:`、装依赖、提交真实密钥 |

- 本地编排、弱口令和种子数据放 `infra/`，见 [infra/README.md](infra/README.md)；`deploy/` 只放 Kubernetes / Helm 等镜像化清单，见 [deploy/README.md](deploy/README.md)。
- 两层不共享文件、不共享变量；`deploy/` 的 YAML 里出现 `build:` 会被 CI 的层规则检查拦下。
- 将来引入 Terraform / 云资源定义，放 `infra/terraform/`（或独立 `platform/`），不要和应用清单混进同一层：本地环境以小时计、云资源以月计，生命周期与权限边界不同。理由与代价见 [docs/adr/0001-infra-vs-deploy.md](docs/adr/0001-infra-vs-deploy.md)。

## 许可证

[MIT](LICENSE)
