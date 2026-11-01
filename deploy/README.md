# deploy/

部署侧的配置放在这里：容器编排、Kubernetes / Helm 清单、环境变量模板和发布脚本。仓库当前只有这份说明，还没有子目录。

## 放什么

- `docker-compose` 编排，按环境分子目录
- `k8s` / `helm` 清单与 chart
- 环境变量模板：`env/*.example`
- 发布、回滚脚本，以及可被 CI 调用的流水线片段

业务代码与构建逻辑不在这里：项目在 `clients/` 和 `services/`，构建由各项目的 target 完成。

## 结构

```text
deploy/
├── docker-compose/
│   └── dev/                    # 示例，按需创建
├── k8s/
│   └── staging/
├── helm/
│   └── <chart>/
├── scripts/
└── env/
    └── app.env.example
```

## 消费 Nx 构建产物

部署前先由 Nx 构建，部署侧只取产物：

```bash
nx affected -t build --base=origin/main
nx run java-api:build
```

产物位置见对应项目 `project.json` 里 `build` target 的 `outputs`；`deploy/` 里不做构建和依赖安装。项目本身仍由各自的 `project.json` 被 Nx 自动发现，根目录没有项目清单，`deploy/` 只消费 `nx run` / `nx affected` 的结果。

## CI

CI 入口是根目录的 `.github/workflows/ci.yml` —— GitHub 只从 `.github/workflows/` 读 workflow，这是平台要求。`deploy/` 存放它调用的脚本与流水线片段，两边各司其职。

## 环境

环境分 `dev` / `staging` / `prod`，差异通过变量注入：提交的是 `*.example` 模板，真实值来自 CI secret 或外部密钥管理。清单里的资源名、镜像名通常跟着 Nx 项目名走，便于从部署对象反查项目。

## 与相邻目录的关系

- `services/` 与 `clients/` 产出被部署的构建物
- `tools/` 提供 `gen-api` 等仓库级脚本
- 根 `justfile` 是这些命令的可选短别名
