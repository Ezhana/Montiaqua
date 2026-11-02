# Montiaqua

English | [简体中文](README.md)

## Name

**Montiaqua** /mɒnˈtiːəkwə/ — mont (mountain) + aqua (water): a water source that rises in the high mountains and spreads widely; great water from the mountain plains. The template keeps that image: from one source, spreading into a multilingual network of waterways.

Montiaqua is a GitHub Template Repository for a polyglot monorepo, meant to host clients and services. It provides only the skeleton: the root holds aliases and documentation, projects are added when needed, and Docker Compose orchestrates them.

## Design

- **The root carries no orchestration logic.** `justfile` only wraps `docker compose` and registry commands as short aliases (`just up`, `just logs`, `just push` …); deleting it loses no capability. The orchestration "brain" lives in exactly two places:
  - `infra/compose/compose.yaml`: declarative — services, dependency order, ports, environment variables, one-shot tasks;
  - each project's `Dockerfile`: imperative — how the image is built, and which build stage runs lint / test.
- **This is a template recommendation.** When adding an orchestration capability, first ask whether it can live in compose or a Dockerfile; if it can, keep it out of the aliases; only if it cannot, add an alias — and the alias does one layer of forwarding only. The tradeoffs are in [ADR 0002](docs/adr/0002-compose-orchestration.md).
- **A project = Dockerfile + its own toolchain.** Adding a project = create a directory, put a `Dockerfile` and its own build files there, add one service in compose; the root has no project list, and `justfile` needs no change. Language, build tool, and versions follow the project's own build files.
- **Cross-language work goes through contracts and images.** Interfaces live in `services/contracts` (OpenAPI / proto / JSON Schema); clients and servers consume the same contract, and generated code is produced by `tools/gen-api`; the unit of execution is the image, and services communicate over the compose network.
- **Environments are layered by "run locally every day".** `infra/` serves local development only, `deploy/` serves non-local environments only; the test is whether a local developer runs the file every day.
- **CI builds all images.** There is no affected-project filtering: CI runs `docker compose build` / `push` directly, and incrementality comes from image-layer caching; while the repository has no services, it only validates the compose file and passes as a no-op.

## Layout

```text
/
├── README.md                     # Chinese version
├── README.en.md                  # this file (English)
├── LICENSE
├── .gitignore                    # shared ignore rules for all languages
├── .editorconfig                 # cross-language indentation / line endings
├── justfile                      # only wraps docker compose / registry commands as short aliases
│
├── clients/README.md             # where web / desktop / mobile / bff go
├── services/README.md            # where java-api / python-api / contracts go
├── infra/
│   ├── README.md                 # local dev: compose / weak credentials / port passthrough / seed
│   ├── compose/compose.yaml      # where local orchestration is declared: services / deps / ports / env
│   └── env/.env.example          # local variable template, copy it to .env
├── deploy/README.md              # non-local: image: manifests / externally injected secrets
├── tools/README.md               # where gen-api, boundary checks, and other one-shot tasks go
│
├── docs/
│   └── adr/
│       ├── README.md             # optional: architecture decision records
│       ├── 0001-infra-vs-deploy.md        # layering rule: local dev vs non-local deploy
│       └── 0002-compose-orchestration.md  # orchestration choice: compose + images, just keeps aliases only
│
└── .github/workflows/ci.yml      # validates compose, and checks the layer rule
```

`clients/`, `services/`, `deploy/`, and `tools/` currently contain only their own READMEs; `infra/` already has a compose and env skeleton (`services` is empty). `docs/adr/` holds two records beyond its README: `0001` the layering rule and `0002` the orchestration choice; `docs/adr` is still an optional directory — delete it together with those records if you don't need it.

## Usage

The only prerequisites are Docker (compose v2) and `just`. `just` is a pure alias layer; without it, `docker compose` does exactly the same things directly.

```bash
just --list      # list all aliases
just up          # docker compose up -d
just ps          # show container status
just logs java-api
just down        # stop and remove containers and networks
```

Local environment: copy `infra/env/.env.example` to `infra/env/.env` (once). Services, dependency order, ports, and environment variables all live in `infra/compose/compose.yaml`.

Adding a service takes three steps:

1. Write a `Dockerfile` in the project directory: multi-stage build, run lint / test in the build stage, and the runtime stage carries only artifacts.
2. Add an entry under `services:` in `infra/compose/compose.yaml`: `build.context` points at the project directory, ports pass straight through to the host.
3. `just up <service>`.

Images and the registry:

```bash
just build       # docker compose build
just push        # docker compose push; image names come from image: in compose
just pull        # docker compose pull
```

Alias table — every alias is just one layer of forwarding:

| Alias | Equivalent command |
| --- | --- |
| `just up [service…]` | `docker compose up -d` |
| `just rebuild [service…]` | `docker compose up -d --build` |
| `just down` | `docker compose down --remove-orphans` |
| `just restart [service…]` | `docker compose restart` |
| `just ps` / `just logs [service…]` | `docker compose ps` / `docker compose logs -f` |
| `just build [service…]` / `just run …` / `just sh <service>` | `docker compose build` / `run --rm` / `exec … sh` |
| `just config` | `docker compose config -q` |
| `just push [service…]` / `just pull [service…]` / `just login [registry]` | `docker compose push` / `pull`, `docker login` |

Suggestions for splitting orchestration work:

- Write dependency order as compose `depends_on` + healthcheck; do not script `sleep` waits.
- Put lint / test into the `Dockerfile` build stage, so CI runs them while building images.
- For one-shot tasks such as code generation and boundary checks, declare them as services with compose `profiles` and run them via `just run gen-api`.
- Do not add project discovery, loops, batch runs, or change filtering to `justfile` — that is orchestration logic, and it belongs in compose and Dockerfiles.

## Environment layers: infra/ and deploy/

The repository is split into two layers by environment, and the test is a single question: **will a local developer run this file every day?**

| Directory | Serves | Allowed | Not allowed |
| --- | --- | --- | --- |
| `infra/` | local development (localhost) | `build:`, weak credentials, port passthrough, seed data | real secrets, cloud endpoints, release logic |
| `deploy/` | non-local environments (staging / prod etc.) | `image:`, externally injected secret key names | `build:`, installing dependencies, committed real secrets |

- Local orchestration, weak credentials, and seed data live in `infra/`; see [infra/README.md](infra/README.md). `deploy/` holds only image-based Kubernetes / Helm manifests; see [deploy/README.md](deploy/README.md).
- The two layers share no files and no variables; a `build:` in `deploy/` YAML is caught by the CI layer check.
- Images are built by CI from the compose declarations and pushed to the registry; `deploy/` only consumes `image:` and never rebuilds.
- When Terraform / cloud resource definitions arrive, put them in `infra/terraform/` (or a standalone `platform/`), never mixed with application manifests in the same layer: local environments have an hourly lifetime, cloud resources a monthly one, with different permission boundaries. Rationale and costs are in [docs/adr/0001-infra-vs-deploy.md](docs/adr/0001-infra-vs-deploy.md).

## License

[MIT](LICENSE)
