# AI Dev Container Baseline for Python and TypeScript Monorepos

> **This repository is OSS-ready.** All code comments are in English. Primary documentation is in English; supplementary Japanese documentation is available at [docs/README.ja.md](docs/README.ja.md).

This repository is a VS Code Dev Container baseline for Python and TypeScript monorepos.
It provides a reproducible container setup, project-local dependencies, and optional AI coding
tool integrations.

The repository is intended as a template or starting point rather than a finished application.
If you derive your own baseline from it, treat locale, timezone, AI tooling, and Home volume
defaults as example choices that you can customize for your team.

## What This Repository Is

- A Dev Container baseline for VS Code
- A Python and TypeScript monorepo starter
- A local-first development environment with project-local Node.js and Python dependencies
- A baseline that can integrate AI CLIs, without requiring them to be the core workflow

## Who This Is For

- Teams that want a shared development container for Python and TypeScript work
- Repositories that want project-local `node_modules/` and `.venv/` instead of global tool drift
- Contributors who want optional AI tooling without making vendor-specific accounts mandatory for everyone

## What You Get

### Infrastructure and CLIs

- Azure CLI
- GitHub CLI
- Git
- Docker with Compose support through Docker-outside-of-Docker

### Languages and Runtimes

- Node.js 24
- Python 3.14

### Package Management and Build Tooling

- npm
- uv
- TypeScript
- tsx
- Turbo
- Vite

### Linting and Testing

- Biome
- Ruff via the VS Code extension
- Vitest
- pytest
- bats for shell script tests

### Optional AI Integrations

- Claude Code
- OpenAI Codex CLI
- GitHub Copilot CLI
- Ollama

These integrations are convenience features. The baseline should still be understandable and usable
even if you do not sign in to any AI vendor service.

## Quick Start

### Prerequisites

- Docker Desktop or a compatible Docker engine
- VS Code with the Dev Containers extension

### Open The Baseline

1. Clone this repository.
2. Open it in VS Code.
3. Run Dev Containers: Reopen in Container.
4. Wait for `.devcontainer/post-create.sh` to refresh pinned versions in `package.json`, `pyproject.toml`, and `.devcontainer/devcontainer.json`, refresh lockfiles, sync dependencies, and install optional AI CLIs.
5. Run the baseline checks:

```bash
npm ci
uv sync --dev
npm run lint
npm run test:shells
npm run test
```

These commands match the smoke CI workflow in [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Project Layout

```text
.
├── .devcontainer/           # Dev Container definition and setup scripts
│   ├── devcontainer.json    # Container configuration, features, extensions, env vars
│   ├── Dockerfile           # Base image plus system tooling
│   ├── on-create.sh         # One-time Home volume initialization
│   ├── post-create.sh       # Project dependency sync and optional AI CLI setup
│   ├── post-start.sh        # Startup-time background service checks
│   └── scripts/
│       ├── lib/            # Shared shell script libraries
│       │   ├── logging.sh  # Unified logging functions
│       │   ├── retry.sh    # Retry utilities with exponential backoff
│       │   ├── version.sh  # Version comparison functions
│       │   └── workspace.sh # Workspace detection utilities
│       └── update-tools.sh  # Tool update helper
├── apps/                    # Intended application workspace area
├── packages/                # Intended shared package workspace area
├── docs/                    # Supporting documentation
├── tests/                   # bats-based shell script tests
├── package.json             # npm workspace root
├── pyproject.toml           # uv workspace root
├── turbo.json               # Turborepo task definitions
└── biome.json               # JS/TS formatting and linting config
```

The `apps/` and `packages/` directories are part of the intended monorepo shape. They may remain
empty until you add real packages or applications.

## Using This Repository As A Template

If you are starting a new project from this baseline, follow
[docs/project-init.md](docs/project-init.md). It walks through copying the repository,
replacing template-owned identifiers, creating a GitHub repository, and verifying the
baseline. An AI agent prompt that automates the same steps is available at
[.github/prompts/project-init.prompt.md](.github/prompts/project-init.prompt.md).

## Customization

The current baseline ships with explicit defaults for locale, timezone, Home volume sharing, and AI
tool setup. Those defaults are repository choices, not universal requirements.

See [docs/customization.md](docs/customization.md) for:

- locale and timezone defaults
- Home volume behavior
- worktree usage
- optional AI integrations
- update strategy and tradeoffs

## Updating Tools

You can refresh tools without rebuilding the container:

```bash
update-tools.sh
update-tools.sh npm
update-tools.sh node-deps
update-tools.sh node-deps-check
update-tools.sh python-deps
update-tools.sh python-deps-check
update-tools.sh uv claude-code
./.devcontainer/scripts/check-package-updates.sh
./.devcontainer/scripts/check-python-package-updates.sh
update-tools.sh --list
update-tools.sh --versions
```

The update helper now refreshes three kinds of version pins intentionally:

- manifest pins in `package.json` and `pyproject.toml`
- runtime feature pins in `.devcontainer/devcontainer.json` for the next rebuild
- lockfiles and local environments in `node_modules/` and `.venv/`

In practice, `node-deps` refreshes `package.json` dependency pins, then runs `npm update --package-lock-only`
before `npm ci`. `python-deps` refreshes `pyproject.toml` dependency pins, then runs `uv lock --upgrade`
before `uv sync --dev`. The `node`, `npm`, and `python` update paths also refresh the pinned versions used by
the Dev Container baseline on the next rebuild.

`update-tools.sh` and `update-tools.sh --all` update the default tool set only. They do not run `node-deps`
or `python-deps` unless you request those targets explicitly.

When `node-deps` or `python-deps` refresh manifest pins, they stay within the current major version by default.
For Python requirements, the refresh step also preserves an existing stricter upper bound when one is already
present.

That keeps rebuilds and worktree syncs close to the newest releases allowed by your current tool choices,
but it can dirty `package.json`, `pyproject.toml`, `package-lock.json`, `uv.lock`, and
`.devcontainer/devcontainer.json` until you review and commit the refreshed pins.

`node-deps-check` and `./.devcontainer/scripts/check-package-updates.sh` report three buckets separately:
package.json range updates, lockfile or `node_modules/` sync-only updates, and `npm audit` findings.

`python-deps-check` and `./.devcontainer/scripts/check-python-package-updates.sh` report Python dependency
specifier updates, `uv.lock` refresh candidates, environment sync drift, and `uv audit` findings.

## Shared Libraries

The `.devcontainer/scripts/lib/` directory contains shared shell script libraries used by the setup scripts:

- `logging.sh` - Unified logging functions with log levels (DEBUG, INFO, WARN, ERROR)
- `retry.sh` - Retry utilities with exponential backoff support
- `version.sh` - Version comparison and normalization functions
- `workspace.sh` - Workspace detection and validation utilities

These libraries are loaded by `on-create.sh`, `post-create.sh`, `post-start.sh`, and `update-tools.sh`.

## Validation and CI

GitHub Actions smoke CI is defined in [.github/workflows/ci.yml](.github/workflows/ci.yml).

The current CI verifies:

- executable permissions on `.devcontainer/*.sh`
- `npm ci`
- `uv sync --dev`
- `npm run lint`
- `npm run test:shells`
- `npm run test`

Run the same sequence locally before opening a pull request.

## Worktree Workflow

This baseline assumes you may keep multiple worktrees under `.worktree/` while reusing the same
shared `/home/vscode` volume.

Example:

```bash
mkdir -p .worktree
git worktree add .worktree/feature-a -b feature-a
git worktree add .worktree/feature-b -b feature-b
```

When you add a new worktree, run dependency sync commands inside that worktree because
`postCreateCommand` only runs when the Dev Container itself is created:

```bash
./.devcontainer/scripts/update-tools.sh node-deps
./.devcontainer/scripts/update-tools.sh node-deps-check
./.devcontainer/scripts/update-tools.sh python-deps
./.devcontainer/scripts/update-tools.sh python-deps-check
```

## Troubleshooting

If a worktree is missing dependencies, rerun the local sync commands:

```bash
./.devcontainer/scripts/update-tools.sh node-deps python-deps
```

If a shell script fails with `Permission denied`, verify the executable bit:

```bash
find .devcontainer -type f -name '*.sh' -exec test -x {} \; -print
```

If Ollama does not respond after container start, inspect the logs:

```bash
tail -n 20 ~/.local/state/ollama/post-start.log
tail -n 20 ~/.local/state/ollama/server.log
```

If the shared Home state becomes inconsistent, remove the Docker volume on the host and reopen the container:

```bash
docker volume rm devcontainer-home
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contributor workflow and repository expectations.

## License

This repository is released under the [MIT License](LICENSE).

[MIT](LICENSE) © Tanaka Yasunobu
