# Montiaqua

English | [简体中文](README.md)

## Name

**Montiaqua** /mɒnˈtiːəkwə/ — mont (mountain) + aqua (water): a water source that rises in the high mountains and spreads widely; great water from the mountain plains. The template keeps that image: from one source, spreading into a multilingual network of waterways.

Montiaqua is a GitHub Template Repository for a polyglot monorepo, meant to host clients and services. It provides only the skeleton: the root holds the orchestration configuration and documentation, projects are added when needed, and Nx handles scheduling.

## Design

- **The root only orchestrates.** `nx.json` describes target caching and ordering (`namedInputs` / `targetDefaults`), `justfile` is an optional layer of command aliases, and `.github/workflows/ci.yml` is the CI placeholder.
- **Projects are defined by `project.json`.** Each client, service, and contracts project keeps a `project.json` in its own directory, and Nx discovers it automatically; there is no project list at the root.
- **Projects bring their own toolchain.** The root has no `package.json`, lockfile, or version file; language, build tool, and versions follow each project's own build files.
- **Cross-language work goes through contracts.** Interfaces live in `services/contracts` (OpenAPI / proto / JSON Schema); clients and services consume the same contract, and generated code is produced by `tools/gen-api`.
- **CI looks only at changes.** `nx affected` keeps CI to affected projects; while the repository has no projects, this pipeline passes as a no-op.

## Layout

```text
/
├── README.md                     # this file (Chinese)
├── README.en.md                  # English version
├── LICENSE
├── .gitignore                    # shared ignore rules for all languages
├── .editorconfig                 # cross-language indentation / line endings
├── nx.json                       # Nx: namedInputs / targetDefaults
├── justfile                      # optional command aliases
│
├── clients/README.md             # where web / desktop / mobile / bff go
├── services/README.md            # where java-api / python-api / contracts go
├── deploy/README.md              # where docker-compose / k8s go
├── tools/README.md               # where gen-api, boundary checks, etc. go
│
├── docs/
│   └── adr/README.md             # optional: architecture decision records
│
└── .github/workflows/ci.yml      # placeholder: install Nx, then run affected
```

`clients/`, `services/`, `deploy/`, and `tools/` currently contain only their own READMEs and no subdirectories; `docs/adr/` holds just its README. `docs/adr` is an optional directory; delete it if you don't need it.

## Usage

```bash
npm install --global nx     # after creating a repo from the template; or just use npx nx
nx graph                    # an empty graph at this point
```

Adding a project means creating a directory and putting a `project.json` in it (a web client here):

```json
{
  "name": "web-portal",
  "projectType": "application",
  "sourceRoot": "clients/web-portal/src",
  "targets": {
    "serve": { "executor": "nx:run-commands", "options": { "command": "npm run dev", "cwd": "clients/web-portal" } },
    "build": { "executor": "nx:run-commands", "options": { "command": "npm run build", "cwd": "clients/web-portal" } },
    "lint": { "executor": "nx:run-commands", "options": { "command": "npm run lint", "cwd": "clients/web-portal" } },
    "test": { "executor": "nx:run-commands", "options": { "command": "npm run test", "cwd": "clients/web-portal" } }
  }
}
```

```bash
nx show projects            # list the projects Nx has discovered
nx run web-portal:build
```

The directory naming convention is `clients/<platform>-<name>` (web / desktop / mobile / bff) and `services/<language>-<name>` (java / python / go / node …), with contracts fixed at `services/contracts`. Target names follow `lint`, `test`, `build`, `e2e`, `typecheck`, `serve`: `nx.json` configures caching and ordering by these names, `build` runs the `build` of upstream dependencies first, and `serve` is a long-running process that is not cached.

## Deployment

docker-compose, Kubernetes / Helm, environment variable templates, and release scripts live in `deploy/`; see [deploy/README.md](deploy/README.md).

## License

[MIT](LICENSE)
