# 这是可选的薄命令层：只把常用 Nx 命令包成短别名，方便手动执行。
# 真正的逻辑一律放在各项目的 target 或 tools/ 脚本里，根目录不承载业务逻辑；
# 所以删掉这个文件不会丢失任何能力——下面每条命令都能用 `npx nx ...` 等价手打。

# 不传参数时列出所有可用配方（默认行为）
default:
    @just --list

# 打开 Nx 的项目依赖图（浏览器可视化）
graph:
    npx nx graph

# 列出 Nx 能发现的全部项目（用于确认 project.json 是否被正确发现）
projects:
    npx nx show projects

# 对所有项目并行执行同一个 target，例如 run lint / run test / run build
run target:
    npx nx run-many -t {{target}}

# 只对受影响的项目执行 targets，默认 lint test build
affected targets="lint test build":
    npx nx affected -t {{targets}}

# 透传任意参数给 nx，作为兜底入口（不写死任何版本，跟随全局安装的 nx）
nx +args:
    npx nx {{args}}
