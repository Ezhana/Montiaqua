# clients/

面向用户的客户端应用放在这里：web、desktop、mobile，以及某个客户端专属的 bff 边缘层。每个子目录是一个独立的 Nx 项目；仓库当前只有这份说明，还没有子目录。

## 放什么

- 用户直接使用的应用：`clients/web-portal`、`clients/desktop-admin`、`clients/mobile-app`
- 某个客户端专属的边缘层：`clients/bff-gateway`
- 客户端之间显式抽出的共享 library：`clients/web-shared-ui`

后端服务、环境编排、跨语言契约都不在这里：分别在 `services/`、`infra/` 与 `deploy/`、`services/contracts`。

## 命名与结构

目录名通常是 `<platform>-<name>`，platform 取 `web`、`desktop`、`mobile`、`bff`，Nx 项目名与目录名一致。

| platform | 示例目录（按需创建） | 常见 targets |
| --- | --- | --- |
| web | `clients/web-portal` | serve / build / e2e / lint / test |
| desktop | `clients/desktop-admin` | serve / build / lint / test |
| mobile | `clients/mobile-app` | serve / build / e2e / lint / test |
| bff | `clients/bff-gateway` | serve / build / lint / test |

```text
clients/
└── web-portal/                 # 示例，按需创建
    ├── project.json            # Nx 项目定义
    ├── src/
    ├── e2e/
    ├── package.json            # 该项目自己的依赖清单
    └── README.md
```

共享 library 的结构相同，`projectType` 写成 `library`。

## 接入 Nx

每个项目靠自己的 `project.json` 被 Nx 自动发现。根目录没有项目清单，也没有 `package.json`；加一个客户端就是建目录、在其中放 `project.json`，根配置保持不动，`nx show projects` 里就会出现它。

```json
{
  "name": "web-portal",
  "projectType": "application",
  "targets": {
    "serve": { "executor": "nx:run-commands", "options": { "command": "npm run dev", "cwd": "clients/web-portal" } },
    "build": { "executor": "nx:run-commands", "options": { "command": "npm run build", "cwd": "clients/web-portal" } },
    "lint": { "executor": "nx:run-commands", "options": { "command": "npm run lint", "cwd": "clients/web-portal" } },
    "test": { "executor": "nx:run-commands", "options": { "command": "npm run test", "cwd": "clients/web-portal" } }
  }
}
```

target 名沿用 `lint`、`test`、`build`、`e2e`、`typecheck`、`serve`：`nx.json` 按这些名字配置缓存与顺序，`build` 会先跑上游依赖的 `build`，`serve` 是常驻进程、不缓存。

## 与相邻目录的关系

- `services/` 提供后端与契约；客户端消费 `services/contracts` 经 `tools/gen-api` 生成的代码。
- `infra/` 在本地用 compose 直接 build 当前代码起客户端与依赖，端口直通到宿主机。
- `deploy/` 只消费镜像化的构建产物；`bff-*` 的部署形态接近服务，归属仍是某个客户端。
- CI 入口是 `.github/workflows/ci.yml`，用 `nx affected` 跑受影响的项目，并检查 `deploy/` 的层规则。
