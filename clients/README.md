# clients/

面向用户的客户端应用放在这里：web、desktop、mobile，以及某个客户端专属的 bff 边缘层。每个子目录是一个独立项目——一个 `Dockerfile` 加它自己的构建文件；仓库当前只有这份说明，还没有子目录。

## 放什么

- 用户直接使用的应用：`clients/web-portal`、`clients/desktop-admin`、`clients/mobile-app`
- 某个客户端专属的边缘层：`clients/bff-gateway`
- 客户端之间显式抽出的共享 library：`clients/web-shared-ui`

后端服务、环境编排、跨语言契约都不在这里：分别在 `services/`、`infra/` 与 `deploy/`、`services/contracts`。

## 命名与结构

目录名通常是 `<platform>-<name>`，platform 取 `web`、`desktop`、`mobile`、`bff`，项目名与目录名一致。

| platform | 示例目录（按需创建） | 常见形态 |
| --- | --- | --- |
| web | `clients/web-portal` | 容器运行（构建产物 + nginx 运行时） |
| desktop | `clients/desktop-admin` | 构建镜像产出安装包（不在 compose 中常驻） |
| mobile | `clients/mobile-app` | 构建镜像产出 apk / ipa（不在 compose 中常驻） |
| bff | `clients/bff-gateway` | 容器运行 |

"常见形态"描述的是它在镜像与 compose 里的样子，不限定工具链：web 与 bff 有可运行的镜像并常驻 compose；desktop 与 mobile 的镜像是一次性构建器——`docker compose build` 之后从镜像里取安装包，容器本身不常驻、不映射端口。

```text
clients/
└── web-portal/                 # 示例，按需创建
    ├── Dockerfile              # 镜像怎么构建，lint / test 在 build 阶段跑
    ├── src/
    ├── e2e/
    ├── package.json            # 该项目自己的依赖清单
    └── README.md
```

共享 library 的结构更窄：同样是一个目录，但通常没有 `Dockerfile` 与运行入口，由消费它的项目在自己的构建阶段里一起带上。

## 项目结构与接入 compose

一个客户端项目成立的条件是：目录里有 `Dockerfile`，并且 `infra/compose/compose.yaml` 的 `services:` 里有一条 service 指向它。没有根项目清单，也不用改 `justfile`——加一个客户端就是建目录、写 `Dockerfile`、在 compose 里加一条 service。

`Dockerfile` 用多阶段构建：构建阶段装依赖、跑 lint / test / build，运行时阶段只带产物。web 客户端的典型形态：

```dockerfile
# clients/web-portal/Dockerfile
FROM node:22-alpine AS build
WORKDIR /app
ENV CI=true
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run lint && npm run test && npm run build

FROM nginx:1.27-alpine AS runtime
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

lint 与 test 是构建阶段里的普通一步：`docker compose build web-portal` 失败就说明 lint / test 不过，CI 构建镜像时顺带执行，不需要另设一条"跑测试"的流程。

在 `infra/compose/compose.yaml` 里为它加一条 service：

```yaml
services:
  web-portal:
    build:
      context: ../../clients/web-portal
    image: ghcr.io/<org>/web-portal:${GIT_SHA:-local}
    ports:
      - "3000:80"
    depends_on:
      java-api:                      # 运行期依赖；静态站点不需要时整段删掉
        condition: service_healthy
```

- `build.context` 指向项目目录，Dockerfile 名固定为 `Dockerfile`；
- `ports` 把运行时端口直通到宿主机，本地浏览器和 curl 直接访问；
- `depends_on` + healthcheck 表达运行顺序（例如 bff 等后端健康后再起），不写 sleep 等待脚本；
- `image` 是镜像名与 tag：项目名 + commit，本地没传 `GIT_SHA` 时回退到 `local`；
- 构建期常量（例如 API base URL）用 `build.args` 传入，不在镜像里写死环境。

compose 是唯一的声明处，`just up web-portal`、`just build`、`just push` 都只是转发到它；跨服务顺序由 compose 的 `depends_on` / healthcheck 决定，客户端不自己拉起依赖。

desktop / mobile 这类产物型项目同样用 compose 声明，但只 build、不常驻：镜像里放构建工具链，`docker compose build` 或在 CI 里 `docker compose run --rm` 产出安装包，不写 `ports`。

## 与相邻目录的关系

- `services/` 提供后端与契约；客户端消费 `services/contracts` 经 `tools/gen-api` 生成的代码。
- `infra/compose/compose.yaml` 在本地直接 build 工作区当前代码起客户端与依赖，端口直通宿主机；变量来自 `infra/env/.env`。
- `deploy/` 只消费镜像：CI 按 compose 声明 `docker compose build` / `push`，部署清单里只出现 `image:`。
- `.github/workflows/ci.yml` 校验 compose 并检查 `deploy/` 的层规则；客户端镜像由 CI 全量构建，没有 affected 这类变更筛选，增量靠镜像层缓存（BuildKit），也没有项目发现。
