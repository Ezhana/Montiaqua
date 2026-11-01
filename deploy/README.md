# deploy/

非本地环境的部署清单：staging / prod（以及需要时的共享开发环境）的 Kubernetes / Helm、环境变量键名和发布脚本。仓库当前只有这份说明，还没有子目录。

`deploy/` 只服务非本地环境，构建物来源只有一种：镜像。清单里只允许引用 `image:`，不 build、不装依赖，密钥在运行时从外部注入。

## 判断标准

和 `infra/` 用同一把尺子：**这份文件会不会被本地开发者每天跑？**

- 会——本地拉起服务、直连端口、灌种子数据，放 `infra/`（见 [infra/README.md](../infra/README.md)）。
- 不会——只被平台、CI 或发布流程在非本地环境消费，放 `deploy/`。

完整决策与代价见 [docs/adr/0001-infra-vs-deploy.md](../docs/adr/0001-infra-vs-deploy.md)。

## 硬规则

1. **只用 `image:`。** 每个工作负载引用项目构建并推到镜像仓库的 tag；不写 `build:`、不写 build context、不放 Dockerfile。
2. **不装依赖。** 不在部署清单或发布脚本里跑 `npm install`、`pip install`、`gradlew`；依赖在项目里，构建产物由 `nx affected -t build` 与镜像构建产出。
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

按需创建。`docker-compose` 属于本机开发，放 `infra/compose/`，不在这里。

## 消费 Nx 构建产物

部署前由 CI / 发布流水线构建并推镜像，`deploy/` 只取结果：

```bash
nx affected -t build --base=origin/main   # 产出构建物
# 镜像由项目自己的构建 / 发布 target 产出并推送，deploy/ 不参与
```

产物位置见对应项目 `project.json` 里 `build` target 的 `outputs`；镜像 tag 跟 Nx 项目名与 commit 对应，便于从部署对象反查项目。

## CI

CI 入口是根目录的 `.github/workflows/ci.yml` —— GitHub 只从 `.github/workflows/` 读 workflow，这是平台要求。CI 里的层规则检查会拒绝 `deploy/` 下出现 `build:` 的 YAML 和 Dockerfile；`deploy/` 存放它调用的脚本与流水线片段，两边各司其职。

## 环境

环境分 `staging` / `prod`（以及需要时的共享开发环境），差异通过变量注入：提交的是 `*.example` 模板，真实值来自 CI secret 或外部密钥管理。清单里的资源名、镜像名通常跟着 Nx 项目名走，便于从部署对象反查项目。

## 与相邻目录的关系

- `infra/` 是本机开发层（compose、弱密钥、端口直通、seed），两边不共享文件、不共享变量。
- `services/` 与 `clients/` 产出被部署的构建物与镜像。
- `tools/` 提供 `gen-api` 等仓库级脚本。
- 根 `justfile` 是这些命令的可选短别名。
