# tools/

仓库级维护工具放在这里：契约生成、依赖边界校验和其它跨项目任务。每个工具是一个自包含目录——`Dockerfile` + 运行入口 + 依赖清单；仓库当前只有这份说明，还没有子目录。

工具不是常驻服务，而是**一次性任务**：镜像里带工具链，compose 里用 `profiles: ["tools"]` 声明，`just run gen-api` 跑一次就退出。

## 放什么

- `gen-api`：从 `services/contracts` 产出客户端与服务端代码
- `check-boundaries`：按目录约定做依赖方向检查（扫描源码里的跨目录引用）
- 其它跨项目的仓库维护任务

业务逻辑不在这里：应用与服务在 `clients/`、`services/`，工具只服务仓库维护。

## 结构

```text
tools/
└── gen-api/                    # 示例，按需创建
    ├── README.md               # 该工具的用法
    ├── Dockerfile              # 工具镜像：构建阶段跑 lint / test 并编译入口
    ├── index.ts                # 运行入口
    └── package.json            # 该工具自己的依赖与锁文件
```

工具目录自带 README、运行入口和依赖清单，根目录不提供依赖文件；工具链与版本随工具自己走。

## 声明为 compose 一次性任务

工具目录的 `Dockerfile` 同样分两段：构建阶段装依赖、跑 lint / test、编译入口；运行时阶段只带产物。输入输出不进镜像，靠 volume 与命令参数给出：

```dockerfile
# tools/gen-api/Dockerfile
FROM node:22-alpine AS build
WORKDIR /app
ENV CI=true
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run lint && npm run test && npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
ENTRYPOINT ["node", "dist/index.js"]
```

在 `infra/compose/compose.yaml` 的 `services:` 下加一条 service，并放进 `profiles: ["tools"]`：

```yaml
services:
  gen-api:
    build:
      context: ../../tools/gen-api
    profiles: ["tools"]
    volumes:
      - ../../services/contracts:/contracts:ro      # 输入：契约原文
      - ../../clients:/clients                      # 输出：生成代码回落到消费方
      - ../../services:/services
```

profiles 让工具不进入 `just up` 的常驻集合：只有显式 `run` 时才构建镜像并执行一次。运行：

```bash
just run gen-api                      # docker compose run --rm gen-api
just run gen-api --check              # 只校验契约，不写文件
just run check-boundaries             # 单独跑边界检查
```

`just run` 只做一层转发（`docker compose run --rm`），参数原样传给工具镜像的入口；CI 不经过别名，直接写 `docker compose run --rm gen-api` 这类显式命令。

## gen-api

输入是 `services/contracts` 里的 OpenAPI / proto / JSON Schema，输出是客户端与服务端消费的生成代码。生成物回落到独立生成项目，或消费方项目内的 `generated/` 目录（按需创建）。生成是幂等的：同样的输入产出同样的文件，文件头带来源注释，说明它来自 `tools/gen-api` 与哪份契约；接口变化时改契约再重新生成，而不是手改生成物。

输入 / 输出路径通过 volume 与命令参数给出（`--contracts`、`--out` 之类），不写死在镜像里，因此同一个镜像在本地和 CI 里都指向当前工作区。

## check-boundaries

直接扫描源码中的 `import` / 模块引用，按 `clients/`、`services/`、`tools/` 的目录归属判断依赖方向：客户端不得直连服务内部实现、服务不得依赖客户端、工具可以读两侧但两侧不反向依赖工具。命中时非零退出，CI 随之失败。

它不做依赖图建模、不做增量判断：目录归属就是唯一判据，因此不依赖任何构建系统，也不需要额外的图工具。

## 与相邻目录的关系

- `services/contracts` 是 `gen-api` 的输入
- `clients/` 与 `services/` 消费生成的代码
- `infra/compose/compose.yaml` 用 `profiles` 声明这些一次性任务；`deploy/` 只消费镜像化产物
- CI 入口在 `.github/workflows/ci.yml`，需要时加一步显式 `docker compose run --rm <tool>`
