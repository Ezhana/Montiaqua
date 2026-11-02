# deploy/

非本地环境的部署清单：staging / prod（以及需要时的共享开发环境）的 Kubernetes / Helm、环境变量键名和发布脚本。仓库当前只有这份说明，还没有子目录。

`deploy/` 只服务非本地环境，构建物来源只有一种：镜像。清单里只允许引用 `image:`，不 build、不装依赖，密钥在运行时从外部注入。

## 判断标准

和 `infra/` 用同一把尺子：**这份文件会不会被本地开发者每天跑？**

- 会——本地拉起服务、直连端口、灌种子数据，放 `infra/`（见 [infra/README.md](../infra/README.md)）。
- 不会——只被平台、CI 或发布流程在非本地环境消费，放 `deploy/`。

完整决策与代价见 [docs/adr/0001-infra-vs-deploy.md](../docs/adr/0001-infra-vs-deploy.md)。

## 硬规则

1. **只用 `image:`。** 每个工作负载引用镜像仓库里的 tag，tag 来自 compose 的 `image:` 声明（项目名 + commit）；不写 `build:`、不写 build context、不放 Dockerfile。
2. **不装依赖、不构建。** 不在部署清单或发布脚本里跑 `npm install`、`pip install`、`gradlew`；镜像由 CI 用 `docker compose build` / `docker compose push` 产出，`deploy/` 只取结果。
3. **密钥外部注入。** 仓库里只有键名模板（`env/*.example`，值为空或占位符），真实值来自 CI secret 或外部密钥管理（Vault / KMS / k8s Secret）；`.env` 已被 `.gitignore` 忽略。
4. **按环境分目录。** `k8s/staging`、`k8s/prod`、`env/*.example` 一一对应；差异靠变量注入，不复制粘贴整份清单。
5. **不服务本机。** 本地 compose、端口直通、seed 数据、弱密钥一律在 `infra/`，`deploy/` 不提供本地入口。

## 结构

```text
deploy/
├── k8s/
│   ├── staging/
│   └── prod/
├── helm/
│   └── <chart>/
├── scripts/                    # 发布、回滚、灰度，可被 CI 调用
└── env/
    ├── staging.env.example     # 只有键名与占位符
    └── prod.env.example
```

按需创建。`docker-compose` 属于本机开发，放 `infra/compose/`，不在这里；`deploy/` 也不出现在 compose 的 `services:` 里。

## 消费构建产物

`deploy/` 消费的是 registry 里的镜像。镜像按 `infra/compose/compose.yaml` 里的声明构建：每条带 `image:` 的 service 就是一个待构建、待推送的镜像，CI 全量执行，不做变更筛选：

```bash
# CI / 发布流水线（不在 deploy/ 里执行）
docker compose -f infra/compose/compose.yaml build
docker compose -f infra/compose/compose.yaml push
```

`deploy/` 的清单只引用结果，tag 用项目名 + commit，便于从部署对象反查项目：

```yaml
# deploy/k8s/prod/java-api.yaml（示意）
spec:
  containers:
    - name: java-api
      image: ghcr.io/<org>/java-api:<sha>
```

`deploy/` 不构建、不拉源码、不跑安装命令；环境差异靠注入的变量与镜像 tag 表达。

## CI

CI 入口是根目录的 `.github/workflows/ci.yml` —— GitHub 只从 `.github/workflows/` 读 workflow，这是平台要求。CI 直接调用 `docker compose`，不经过 `justfile` 的别名；其中的层规则检查会拒绝 `deploy/` 下出现 `build:` 的 YAML 和 Dockerfile。`deploy/` 存放它调用的脚本与流水线片段，两边各司其职。

## 环境

环境分 `staging` / `prod`（以及需要时的共享开发环境），差异通过变量注入：提交的是 `*.example` 模板，真实值来自 CI secret 或外部密钥管理。清单里的资源名、镜像名跟着项目名走，便于从部署对象反查项目。

## 与相邻目录的关系

- `infra/` 是本机开发层（compose、弱密钥、端口直通、seed），两边不共享文件、不共享变量。
- `services/` 与 `clients/` 的源码由 compose 声明成镜像，CI 构建并推 registry，`deploy/` 只消费 `image:`。
- `tools/` 提供 `gen-api` 等一次性任务镜像，不参与部署。
- 根 `justfile` 只是给人用的别名层，可删；CI 与 `deploy/` 都不依赖它。
