# Project Initialization Guide

This guide explains how to use `ai-devcontainer-baseline` as a template to start a new project.
The Japanese version is at [project-init.ja.md](project-init.ja.md).

If you prefer to delegate the initialization steps to an AI coding agent, see
[.github/prompts/project-init.prompt.md](../.github/prompts/project-init.prompt.md).

## Overview

`ai-devcontainer-baseline` is not an application. It is a copyable starting point.
To use it for a real project you:

1. Copy the repository content without its Git history.
2. Rename the working folder (this determines the Dev Container Home volume name).
3. Replace template-owned identifiers (author, package names, CODEOWNERS).
4. Optionally adjust locale, timezone, and tool versions.
5. Create a fresh Git repository and push it to GitHub.
6. Open it in a Dev Container and verify the baseline.

This entire process runs on the **host**, before the Dev Container starts.

## Prerequisites

- Git
- Docker Desktop or a compatible Docker engine
- VS Code with the Dev Containers extension
- GitHub CLI (`gh`) authenticated to your account or organization

## Step 1: Copy the repository

Pick one of the following methods. All of them produce a new working copy with no Git history
linking back to the template.

### Method A: GitHub CLI (recommended)

```bash
gh repo clone shichiyou/ai-devcontainer-baseline <NEW_FOLDER_NAME> -- --depth 1
rm -rf <NEW_FOLDER_NAME>/.git
git -C <NEW_FOLDER_NAME> init -b main
```

### Method B: "Use this template" button

On the GitHub repository page, click **Use this template → Create a new repository**,
then clone the new repository locally.

### Method C: ZIP download

Download the repository as a ZIP from GitHub, extract it, rename the folder, and run
`git init -b main` inside it.

## Step 2: Choose and lock the folder name

The Dev Container creates a named Docker volume for `/home/vscode` based on the workspace folder name.

Specifically, [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) runs:

```text
docker volume create devcontainer-home-${localWorkspaceFolderBasename}
```

and writes `DEVCONTAINER_HOME_VOLUME=devcontainer-home-<folder>` to `.devcontainer/.env`,
which [.devcontainer/docker-compose.yml](../.devcontainer/docker-compose.yml) consumes.

**Consequences:**

- Different folder names produce different Home volumes. Multiple projects on the same host
  stay isolated.
- Renaming the folder **after** the first container start leaves the old Home volume orphaned.
  Choose the final folder name before Step 7.

## Step 3: Mandatory changes

Replace every template-owned identifier with your project's values.

| File | Field or string | Replace with |
|---|---|---|
| [CODEOWNERS](../CODEOWNERS) | `@tanaka-yasunobu` (all lines) | `@<GITHUB_USERNAME>` |
| [package.json](../package.json) | `"name": "monorepo"` | `"name": "<PROJECT_NAME>"` |
| [package.json](../package.json) | `"author": "Tanaka Yasunobu"` | `"author": "<AUTHOR_NAME>"` |
| [pyproject.toml](../pyproject.toml) | `name = "monorepo"` | `name = "<PROJECT_NAME>"` |
| [pyproject.toml](../pyproject.toml) | `description = "Python/TypeScript monorepo workspace"` | your project description |
| [pyproject.toml](../pyproject.toml) | `authors = [{ name = "Tanaka Yasunobu" }]` | `authors = [{ name = "<AUTHOR_NAME>" }]` |
| [LICENSE](../LICENSE) | `Copyright (c) 2026 Tanaka Yasunobu` | `Copyright (c) <YEAR> <AUTHOR_NAME>` |
| [README.md](../README.md) | Title, description, and any author mention | your project's text |
| [docs/README.ja.md](README.ja.md) | Same as README.md (Japanese version) | your project's text |
| [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) | `"name": "Ubuntu Dev Container"` | `"name": "<CONTAINER_DISPLAY_NAME>"` |

Run a final check to confirm no stale identifiers remain:

```bash
grep -rn "tanaka-yasunobu\|Tanaka Yasunobu\|\"monorepo\"\|name = \"monorepo\"" \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.git .
```

The command should produce no matches in source files after Step 3 is complete.

## Step 4: Optional changes

These defaults work out of the box but can be adjusted for your team.

| Area | File | Default |
|---|---|---|
| Locale | `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile` | `en_US.UTF-8` |
| Timezone | `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile` | `Etc/UTC` |
| Node.js / Python / CLI versions | `.devcontainer/devcontainer.json` features, `.devcontainer/Dockerfile` ARGs | see files |
| AI agent policies | `.github/copilot-instructions.md`, `AGENTS.md`, `.claude/settings.json`, `.codex/rules/default.rules` | strict bilingual policy, secret-directory protection |

See [customization.md](customization.md) for details about locale, timezone, Home volume
behavior, worktrees, AI integrations, and the update strategy.

## Step 5: Create the GitHub repository

From the new project folder:

```bash
gh repo create <OWNER>/<REPO_NAME> --private --source=. --remote=origin
```

Use `--public` instead of `--private` when appropriate.
The command both creates the repository on GitHub and wires up `origin`.

## Step 6: Initial commit and push

```bash
git add -A
git commit -m "chore: initialize from ai-devcontainer-baseline"
git push -u origin main
```

Verify afterwards:

```bash
git log --oneline -1
git status
```

Both commands should confirm a clean tree with your initial commit.

## Step 7: Open in Dev Container

1. Open the new folder in VS Code.
2. Run the command **Dev Containers: Reopen in Container**.
3. Wait for `.devcontainer/post-create.sh` to finish (it refreshes version pins and installs AI CLIs).

## Step 8: Verify the baseline

Inside the Dev Container:

```bash
npm ci
uv sync --dev
npm run lint
npm run test:shells
npm run test
```

These match the smoke CI pipeline in [.github/workflows/ci.yml](../.github/workflows/ci.yml).
All five commands should complete without errors.

## Troubleshooting

### The Home volume conflicts with another project

Each workspace folder name maps to `devcontainer-home-<folder>`. If you reused a folder name
from a previous derivation you may pick up its Home state. Remove the old volume with:

```bash
docker volume rm devcontainer-home-<old-folder>
```

before opening the container.

### `docker volume create` fails during `initializeCommand`

The `initializeCommand` in `devcontainer.json` suppresses volume creation errors, but if
`.devcontainer/.env` was not written the compose step will fall back to the generic
`devcontainer-home` volume. Re-run `Dev Containers: Rebuild Container` so the
`initializeCommand` runs again.

### `gh repo create` fails with authentication errors

Run `gh auth login` and confirm the account has permission to create repositories in the
chosen owner.

## Next steps

- Review [customization.md](customization.md) for locale, timezone, and AI tooling defaults.
- Populate `apps/` and `packages/` with your project code.
- Adjust `.github/copilot-instructions.md` and `AGENTS.md` to match your team's policies.
