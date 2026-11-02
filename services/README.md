# services/

后端服务和跨语言契约放在这里：每个服务子目录是一个独立项目——一个 `Dockerfile` 加它自己的构建文件；契约固定在 `services/contracts`，它不是运行时项目。仓库当前只有这份说明，还没有子目录。

## 放什么

- 后端服务：`services/java-api`、`services/python-worker`、`services/go-gateway`
- 跨语言契约：`services/contracts`（OpenAPI / proto / JSON Schema）
- 服务侧显式抽出的共享 library：`services/java-shared-core`

客户端、环境编排不在这里：分别在 `clients/`、`infra/` 与 `deploy/`。

## 命名与结构

目录名通常是 `<language>-<name>`，language 取该服务的主语言（`java`、`python`、`go`、`node` 等），项目名与目录名一致。契约是例外，位置固定为 `services/contracts`。

| 类型 | 示例目录（按需创建） | 常见形态 |
| --- | --- | --- |
| Java 服务 | `services/java-api` | 容器运行（JRE 运行时镜像） |
| Python 服务 | `services/python-worker` | 容器运行（解释器运行时镜像） |
| Go 服务 | `services/go-gateway` | 容器运行（静态二进制，可 distroless） |
| 契约 | `services/contracts` | 不作为镜像，由 `tools/gen-api` 消费 |

```text
services/
├── java-api/                   # 示例，按需创建
│   ├── Dockerfile              # 镜像怎么构建，lint / test 在 build 阶段跑
│   ├── build.gradle.kts        # 该服务自己的构建文件
│   ├── src/
│   └── README.md
└── contracts/                  # 示例，按需创建
    └── openapi/                # 契约原文，由 tools/gen-api 消费
```

每个服务自带构建文件与锁文件，工具与版本随各自项目走；根目录里没有项目清单、`package.json`、lockfile 或版本文件。

## 项目结构与接入 compose

一个服务项目成立的条件是：目录里有 `Dockerfile`，并且 `infra/compose/compose.yaml` 的 `services:` 里有一条 service 指向它。没有根项目清单，也不用改 `justfile`——加一个服务就是建目录、写 `Dockerfile`、在 compose 里加一条 service。

`Dockerfile` 用多阶段构建：构建阶段跑 lint / test / build，运行时阶段只带可执行产物。Java 服务的典型形态：

```dockerfile
# services/java-api/Dockerfile
FROM gradle:8.10-jdk21 AS build
WORKDIR /src
COPY . .
RUN ./gradlew --no-daemon check test build

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY --from=build /src/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

`./gradlew check test build` 是构建阶段里的普通一步：`docker compose build java-api` 失败就说明 lint / test / 编译不过，CI 构建镜像时顺带执行，不需要另设一条"跑测试"的流程。

在 `infra/compose/compose.yaml` 里为它加一条 service：

```yaml
services:
  java-api:
    build:
      context: ../../services/java-api
    image: ghcr.io/<org>/java-api:${GIT_SHA:-local}
    ports:
      - "8080:8080"
    env_file:
      - ../env/.env
    depends_on:
      postgres:
        condition: service_healthy
```

- `build.context` 指向项目目录，Dockerfile 名固定为 `Dockerfile`；
- `ports` 把服务端口直通到宿主机，本地可以直接 curl 或挂调试器；
- `env_file` 注入本地变量，模板在 `infra/env/.env.example`，复制成 `infra/env/.env` 后生效；
- `depends_on` + `condition: service_healthy` 表达"等数据库健康检查通过再起"，数据库的 healthcheck 写在 compose 里，不写 sleep 等待脚本。

数据库那一侧同样只是 compose 里的一个 service，健康检查决定它什么时候算就绪：

```yaml
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-local-only}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 10
```

运行 `just up java-api` 即按依赖顺序构建并启动；`just build` / `just push` 走同一份 compose 声明，镜像 tag 是项目名 + commit。

## 契约

`services/contracts` 放接口规范与版本化产物，是客户端与服务端共同的接口来源。它不是运行时镜像：生成代码由 `tools/gen-api` 从这里产出，回落到独立生成项目或消费方项目内的 `generated/` 目录（按需创建）。

契约需要校验时，也做成 compose 的一次性任务（`profiles`），而不是给契约目录加一个自己的脚本入口：

```yaml
  gen-api-check:
    build:
      context: ../../tools/gen-api
    profiles: ["tools"]
    volumes:
      - ../../services/contracts:/contracts:ro
    command: ["--check", "/contracts"]
```

`just run gen-api-check` 跑一次就退出；CI 里直接 `docker compose run --rm gen-api-check`。

## 与相邻目录的关系

- `clients/` 消费契约生成的代码；两边通过契约对接，而不是共享源码。
- `infra/compose/compose.yaml` 在本地用 compose 直接 build 服务代码，依赖与端口直通都只对本机生效；`infra/env/.env` 提供弱口令与账号。
- `deploy/` 只消费镜像：CI 按 compose 声明 `docker compose build` / `push`，服务镜像与清单按项目名对应。
- `tools/` 里的 `gen-api` 以本目录的契约为输入，用 compose `profiles` 声明成一次性任务；CI 入口是 `.github/workflows/ci.yml`。
