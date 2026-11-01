# services/

后端服务和跨语言契约放在这里：每个服务子目录是一个独立的 Nx 项目，契约固定在 `services/contracts`。仓库当前只有这份说明，还没有子目录。

## 放什么

- 后端服务：`services/java-api`、`services/python-worker`、`services/go-gateway`
- 跨语言契约：`services/contracts`（OpenAPI / proto / JSON Schema）
- 服务侧显式抽出的共享 library：`services/java-shared-core`

客户端、部署编排不在这里：分别在 `clients/`、`deploy/`。

## 命名与结构

目录名通常是 `<language>-<name>`，language 取该服务的主语言（`java`、`python`、`go`、`node` 等），Nx 项目名与目录名一致。契约是例外，位置固定为 `services/contracts`。

| 类型 | 示例目录（按需创建） | 常见 targets |
| --- | --- | --- |
| Java 服务 | `services/java-api` | lint / test / build |
| Python 服务 | `services/python-worker` | lint / test / build |
| Go 服务 | `services/go-gateway` | lint / test / build |
| 契约 | `services/contracts` | lint |

```text
services/
├── java-api/                   # 示例，按需创建
│   ├── project.json
│   ├── build.gradle.kts        # 该服务自己的构建文件
│   ├── src/
│   └── README.md
└── contracts/                  # 示例，按需创建
    ├── project.json
    └── openapi/
```

## 接入 Nx

每个项目靠自己的 `project.json` 被 Nx 自动发现，根目录没有项目清单；加一个服务就是把目录和 `project.json` 放进 `services/`，根配置保持不动。每个服务自带构建文件与锁文件，工具与版本随各自项目走；根目录里也没有 `package.json`、lockfile 或版本文件。

```json
{
  "name": "java-api",
  "projectType": "application",
  "targets": {
    "lint": { "executor": "nx:run-commands", "options": { "command": "./gradlew check", "cwd": "services/java-api" } },
    "test": { "executor": "nx:run-commands", "options": { "command": "./gradlew test", "cwd": "services/java-api" } },
    "build": { "executor": "nx:run-commands", "options": { "command": "./gradlew build", "cwd": "services/java-api" }, "outputs": ["services/java-api/build/libs"] }
  }
}
```

## 契约

`services/contracts` 放接口规范与版本化产物，是客户端与服务端共同的接口来源。生成代码由 `tools/gen-api` 从这里产出，回落到独立生成项目或消费方项目内的 `generated/` 目录（按需创建）。

## 与相邻目录的关系

- `clients/` 消费契约生成的代码；两边通过契约对接，而不是共享源码。
- `deploy/` 消费 Nx 构建产物，服务镜像与清单按项目名对应。
- `tools/` 里的 `gen-api` 以本目录的契约为输入；CI 入口是根 `.github/workflows/ci.yml`。
