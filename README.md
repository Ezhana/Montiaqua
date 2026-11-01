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
├── deploy/README.md              # docker-compose / k8s 的位置
├── tools/README.md               # gen-api、边界校验等脚本的位置
│
├── docs/
│   └── adr/README.md             # 可选：架构决策记录
│
└── .github/workflows/ci.yml      # 占位：安装 Nx 后跑 affected
```

`clients/`、`services/`、`deploy/`、`tools/` 下目前只有各自的 README，没有子目录；`docs/adr/` 也只有一份说明。`docs/adr` 是可选目录，不用可以删掉。

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

## 部署

docker-compose、Kubernetes / Helm、环境变量模板和发布脚本放在 `deploy/`，说明见 [deploy/README.md](deploy/README.md)。

## 许可证

[MIT](LICENSE)
