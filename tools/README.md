# tools/

仓库级维护工具放在这里：契约生成、依赖边界校验和其它跨项目脚本。每个工具是一个自包含目录；仓库当前只有这份说明，还没有子目录。

## 放什么

- `gen-api`：从 `services/contracts` 产出客户端与服务端代码
- `check-boundaries`：基于 Nx 项目依赖图做依赖校验
- 其它跨项目的仓库维护脚本

业务逻辑不在这里：应用与服务在 `clients/`、`services/`，工具只服务仓库维护。

## 结构

```text
tools/
└── gen-api/                    # 示例，按需创建
    ├── README.md               # 该工具的用法
    ├── project.json            # 作为 Nx 项目被发现
    ├── index.ts                # 运行入口
    └── package.json            # 该工具自己的依赖与锁文件
```

工具目录自带 README、运行入口和依赖清单，根目录不提供依赖文件；工具链与版本随工具自己走。每个工具目录里的 `project.json` 让它作为 Nx 项目被自动发现，根目录没有项目清单。

## gen-api

输入是 `services/contracts` 里的 OpenAPI / proto / JSON Schema，输出是客户端与服务端消费的生成代码。生成物回落到独立生成项目，或消费方项目内的 `generated/` 目录（按需创建）。生成是幂等的，文件头带来源注释，说明它来自 `tools/gen-api` 与哪份契约；接口变化时改契约再重新生成。

调用入口可以是根 `justfile` 的别名（工具落地后补一条），也可以是 CI 里的显式命令。

## check-boundaries

读 Nx 的项目依赖图（`nx graph --file=...`）检查依赖方向，例如客户端之间、服务之间、服务到客户端，以及客户端绕过契约直连服务内部的情况。命中时非零退出，CI 随之失败。

## 与相邻目录的关系

- `services/contracts` 是 `gen-api` 的输入
- `clients/` 与 `services/` 消费生成的代码
- `infra/` 在本地拉起依赖与服务；`deploy/` 只消费镜像化产物，CI 入口在 `.github/workflows/ci.yml`
