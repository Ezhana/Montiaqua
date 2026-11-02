# Montiaqua 根命令别名层：只把 docker compose 与 registry 命令包成短别名。
#
# 这里刻意不放编排逻辑：不发现项目、不批量执行、不判断变更。
# 编排的"脑子"只有两处：
#   - infra/compose/compose.yaml —— 声明式：服务、依赖顺序、端口、环境变量都在这里；
#   - 各项目的 Dockerfile       —— 命令式：镜像怎么构建、测试在哪个构建阶段跑。
# 因此删掉本文件不丢任何能力，直接敲 docker compose / docker push 完全等价；
# CI 也不依赖这些别名，直接调用 docker。取舍见 docs/adr/0002-compose-orchestration.md。

# 本地 compose 命令前缀：换路径只改这一行
COMPOSE := "docker compose -f infra/compose/compose.yaml"

# 默认配方：列出全部别名
default:
    @just --list

# ===========================================================================
# 本地环境：infra/compose/compose.yaml
# ===========================================================================

# 后台拉起本地环境；可只起部分服务：just up java-api
up *args:
    {{ COMPOSE }} up -d {{ args }}

# 重建镜像后再拉起
rebuild *args:
    {{ COMPOSE }} up -d --build {{ args }}

# 停止并移除容器与网络
down:
    {{ COMPOSE }} down --remove-orphans

# 重启容器（不重建镜像）
restart *args:
    {{ COMPOSE }} restart {{ args }}

# 查看容器状态
ps:
    {{ COMPOSE }} ps

# 跟踪日志；可指定服务：just logs java-api
logs *args:
    {{ COMPOSE }} logs -f --tail=200 {{ args }}

# 只构建镜像，不启动
build *args:
    {{ COMPOSE }} build {{ args }}

# 一次性执行命令（代码生成、边界检查等）：just run gen-api
run *args:
    {{ COMPOSE }} run --rm {{ args }}

# 在运行中的容器里开 shell：just sh java-api
sh service:
    {{ COMPOSE }} exec {{ service }} sh

# 校验 compose 文件能否解析
config:
    {{ COMPOSE }} config -q

# ===========================================================================
# 镜像 / registry：镜像名来自 compose 里的 image: 声明
# ===========================================================================

# 推送 compose 里声明的镜像
push *args:
    {{ COMPOSE }} push {{ args }}

# 拉取 compose 里声明的镜像
pull *args:
    {{ COMPOSE }} pull {{ args }}

# 登录 registry（不带参数时交互输入）
login registry="":
    docker login {{ registry }}
