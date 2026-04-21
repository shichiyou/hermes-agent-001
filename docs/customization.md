# Customization Guide

This baseline intentionally exposes several repository-level defaults that many teams will want to
adjust before using it as a public template or internal standard.

## Locale And Timezone

The current baseline sets explicit locale and timezone defaults in the Dev Container definition and
the Dockerfile.

- Locale: `en_US.UTF-8`
- Timezone: `Etc/UTC`

These values are intentionally neutral for a public baseline, but they still should not be treated
as universal defaults.

If your team needs region-specific behavior, change the defaults or make them configurable through
documented variables. A Japanese business environment, for example, may prefer `ja_JP.UTF-8` and
`Asia/Tokyo`.

Relevant files:

- [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json)
- [.devcontainer/Dockerfile](../.devcontainer/Dockerfile)

## Home Volume Behavior

`/home/vscode` is mounted from a fixed Docker volume named `devcontainer-home`.

That means:

- sign-in state and caches survive rebuilds
- multiple worktrees in the same repository share the same Home state
- separate clones can collide if they reuse the same fixed volume name on the same host

This is convenient for day-to-day work, but it is worth documenting clearly if you publish a derived
template for wider consumption.

## Worktree Strategy

The baseline assumes that each worktree keeps its own project-local dependencies:

- `node_modules/`
- `.venv/`
- `package-lock.json`
- `uv.lock`

At the same time, Home-level caches and sign-in state stay shared.

This is a deliberate tradeoff. It keeps build and test dependencies isolated per worktree while
reusing expensive user-level state.

## Optional AI Integrations

The repository currently installs or supports several AI tools:

- Claude Code
- OpenAI Codex CLI
- GitHub Copilot CLI
- Ollama

For an OSS template, it is better to describe these as optional integrations rather than required
baseline features.

Recommended policy:

- keep the baseline usable without vendor sign-in
- separate required tooling from convenience tooling in documentation
- make support boundaries explicit in contributing and support docs

### Data Retention and Plan Requirements

The data retention policies of the bundled AI tools differ significantly between free and paid plans.
When working with sensitive or proprietary code, use a paid organizational plan for each tool.

| Tool | Free / Personal plan | Paid plan (Business / Enterprise / API) |
|------|----------------------|-----------------------------------------|
| Claude Code (Anthropic) | May be used for model training | Not used for training. Backend copy deleted within 30 days of user-initiated deletion. ZDR available |
| GitHub Copilot | Telemetry sent; individual plan data may be used | Business / Enterprise: not used for training |
| OpenAI Codex CLI | Free plan data may be used for training | Enterprise / Business: not used for training by default |
| Ollama | Runs fully locally — no data leaves the machine | — |

> **Note:** The "30 days" above refers to Anthropic's server-side backend deletion triggered by the user
> manually deleting a conversation. Local conversation history stored in `~/.claude/` persists indefinitely
> on the devcontainer home volume until you delete it manually.

Do not use the free or personal tier of any cloud-based AI tool with code that contains
intellectual property, credentials, or other confidential material.

#### Local Conversation History

All three AI CLI tools write local session data to the home volume:

| Path | Content | Cleanup command |
|------|---------|----------------|
| `~/.claude/` | Conversation history, session cache | `rm -rf ~/.claude/projects/` |
| `~/.copilot/logs/` | Operation logs | `find ~/.copilot/logs -type f -mtime +30 -delete` |
| `~/.copilot/session-state/` | Session state | `rm -rf ~/.copilot/session-state/` |
| `~/.codex/` | Session history, auth | `rm -rf ~/.codex/history/` |

The devcontainer rotates `~/.copilot/logs/` files older than `AI_LOG_RETENTION_DAYS` (default: 30) on
every container start. Conversation history in `~/.claude/` and `~/.codex/` is not rotated automatically
because it serves as a working context; remove it manually when no longer needed.

### API Keys and BYOK

The baseline does not set any AI vendor API keys. All tools launch in interactive sign-in mode by
default.

If you need to supply API keys (BYOK — Bring Your Own Key) or point a tool at an alternative model
endpoint, follow these rules to avoid leaking credentials through version control:

**Do not put API keys in `devcontainer.json` or `docker-compose.yml`.**  
Both files are committed to the repository. A key placed in `remoteEnv`, `containerEnv`, or
`environment:` will be visible to everyone with read access to the repo.

**Safe approaches:**

| Approach | How |
|----------|-----|
| Shell profile on the host | Set `export ANTHROPIC_API_KEY=…` in `~/.bashrc` or `~/.zshrc` on the host; devcontainer inherits it via `remoteEnv: { "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}" }` in `devcontainer.json` |
| `.env` file (git-ignored) | Create `.devcontainer/.env.local` (git-ignored, and separate from devcontainer-managed `.env`); load it manually in your shell session inside the container (`source .devcontainer/.env.local`) |
| Secret manager | Inject secrets at container startup via a secret manager (Azure Key Vault, GitHub Codespaces secrets, 1Password CLI, etc.) rather than plain environment variables |

**Using Ollama as a local backend:**

Ollama runs fully locally at `http://127.0.0.1:11434` and requires no API key. You can point Claude
Code or Codex CLI at it to avoid sending prompts to a cloud provider:

```bash
# Claude Code — use a locally served model
export ANTHROPIC_BASE_URL=http://127.0.0.1:11434
claude --model <ollama-model-tag>

# OpenAI Codex CLI — use a local OpenAI-compatible endpoint
# Set provider.base_url in codex.toml
```

When using a local model, no prompt data leaves the container. This is the recommended mode for
sensitive codebases that cannot use a paid organizational plan.

## Update Strategy

`update-tools.sh` intentionally mixes manifest pin refreshes, lockfile refreshes, and convenience updates.

- `node-deps` refreshes `package.json` dependency pins, then runs `npm update --package-lock-only` and `npm ci`
- `python-deps` refreshes `pyproject.toml` dependency pins, then runs `uv lock --upgrade` and `uv sync --dev`
- `node`, `npm`, and `python` refresh the pinned runtime versions used by `.devcontainer/devcontainer.json`
- selected global tools can update to the latest available release at execution time

`update-tools.sh` and `update-tools.sh --all` exclude `node-deps` and `python-deps` by default. Run those
targets explicitly when you want to refresh workspace dependencies.

Manifest pin refreshes stay within the current major version by default. For Python requirements, an existing
stricter upper bound is preserved.

That makes the baseline practical, but there is a tradeoff:

- project dependencies track the newest releases allowed by the current manifest ranges and pinned runtime choices
- rebuilds and manual syncs can rewrite `package.json`, `pyproject.toml`, `.devcontainer/devcontainer.json`, `package-lock.json`, and `uv.lock`, so you need to review and commit those files when you want the refreshed state to be reproducible

If you publish your own derivative, document that distinction explicitly.
