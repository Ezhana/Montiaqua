# 0002. 编排下沉到 compose 与镜像，just 只保留别名

- 状态：建议（模板按此实现）
- 日期：2026-11-03
- 相关：[justfile](../../justfile)、[infra/compose/compose.yaml](../../infra/compose/compose.yaml)、[infra/README.md](../../infra/README.md)、[deploy/README.md](../../deploy/README.md)、[0001-infra-vs-deploy.md](0001-infra-vs-deploy.md)

## 背景

模板原先用 Nx 编排：`nx.json` 描述 target 的缓存与顺序，项目靠 `project.json` 被自动发现，CI 用 `nx affected` 只跑受影响的项目。Nx 被移除的原因很直接：它是 Node 程序，而根目录刻意不绑定任何语言运行时。

Nx 去掉之后，编排逻辑放哪里有两种做法：

1. 写进 `justfile`——项目发现、批量执行、用 `git diff` 挑出受影响项目；
2. 交给容器工具链——`compose` 做声明式编排，镜像做命令式构建。

第一种做法很快会变成第二个小 Nx：用 shell 重新实现项目发现、依赖顺序与增量判断。它既和 compose 里的服务声明重复，又在根目录留下一份需要长期维护的调度代码。对一个"根目录只做编排"的模板来说，这等于把编排又写成了代码。

## 决策

编排的"脑子"只放在两处：

- **`infra/compose/compose.yaml`（声明式）**：服务清单、依赖顺序（`depends_on` + healthcheck）、端口直通、环境变量、一次性任务（`profiles`）都在这里。
- **各项目的 `Dockerfile`（命令式）**：镜像怎么构建、lint / test 放在哪个构建阶段、运行入口是什么，由项目自己的 Dockerfile 决定。

在此之上：

- **`justfile` 只做短别名**：把 `docker compose` 与 registry 命令包成 `just up`、`just logs`、`just build`、`just push` 这类一层转发。不含发现、循环、条件、批量或变更筛选；删掉 `justfile` 不丢任何能力。
- **镜像是产物边界**：本地用 `docker compose build` 构建，推到 registry 后用 `image:` 部署；`deploy/` 不 build、不装依赖。
- **CI 不依赖别名**：直接调用 `docker compose`；别名只服务日常手工操作。
- **模板建议**：以后要加编排能力，先问"这条逻辑能不能放进 compose 或 Dockerfile"；能放就不进别名，放不进去才加别名，而别名只做一层转发。

## 后果

- 好的方面：没有自研调度器要维护；项目发现、依赖顺序、网络、端口、健康检查都用 compose 的标准能力；构建与测试写在 Dockerfile 里，`docker build` 与 CI 共享同一份定义；`justfile` 变得可删；CI 逻辑极薄。
- 代价：没有 `affected` 这类增量筛选，CI 每次全量 `compose build`，增量靠镜像层缓存（BuildKit）承担；没有项目自动发现，加服务必须同时加 compose 条目；本地开发默认需要 Docker，不能只靠本机 toolchain。
- 代价：横跨多项目的 target 抽象消失（不再有"对所有项目跑 lint"），需要自己把这些阶段组织进 Dockerfile；`just` + `git` 的最小依赖也不再成立，Docker 成为编排的必需项。
- 代价：compose 与别名之间需要人工保持同步——别名只是转发，不校验 compose 里的服务名与镜像名。

## 备选方案

- **把编排逻辑写进 justfile**（项目发现 + 批量 + affected）：等于用 shell 重写一个小 Nx，与 compose 声明重复，放弃。
- **保留 Nx**：编排层依赖 Node，与"根目录不绑定语言"冲突，放弃。
- **Make / Taskfile 包 compose**：仍要维护一层转发，可读性不如 just；只做别名时 just 已经足够，放弃。
- **只写 shell 脚本**：没有 `--list` 与参数处理，别名层反而更难发现，放弃。
