---
name: hermes-devcontainer-persistence
description: Ensure Hermes Agent services auto-start and config persists across dev container rebuilds
version: 1.0
---

# Hermes Agent Dev Container — Persistence & Auto-Start

## Overview
Strategy for ensuring Hermes Agent services (Gateway, Dashboard) auto-start on container restart, and that configuration/skills/data survive home volume loss during dev container rebuilds.

## Data Locations

**Home volume** (`devcontainer-home-hermes-agent-lab`, external:true):
- Hermes source + venv (~1.4GB, re-installable)
- Main configuration file (API keys are empty or literal "ollama" — safe for git; actual secrets in auth.json)
- Authentication credentials file (never commit to git)
- Skills directory (hub skills re-installable, custom ones lost on volume deletion)
- Agent memory files (MEMORY.md, USER.md)
- Cron job definitions
- Custom agent instructions (SOUL.md)

**Workspace bind mount** (`/workspaces/hermes-agent-lab/`):
- Git repo, wiki submodule — always safe across rebuilds
- Wiki symlink points here

**Key**: External volume survives `docker compose down` but NOT `docker volume rm`. Need backup strategy.

## Dev Container Lifecycle Hooks (execution order)

1. **`initializeCommand`** — runs on HOST before container creation
2. **`onCreateCommand`** (`on-create.sh`) — first boot only
3. **`postCreateCommand`** (`post-create.sh`) — after features installed, first boot only
4. **`postStartCommand`** (`post-start.sh`) — EVERY container start

**Critical**: Lifecycle scripts run non-interactively. Shell startup files with interactive guards are NOT sourced by these hooks. Always use the lifecycle scripts for auto-start configuration.

## Auto-Start Configuration

**Problem**: Gateway auto-start only works on interactive shell sessions. Dashboard has no auto-start. Post-start.sh runs on every container start regardless.

**Solution**: Add Hermes service startup to `post-start.sh` using the same pattern as the existing Ollama server startup in that file.

Key points for the implementation:
- Use `pgrep -f` with specific process names (e.g., `pgrep -f "hermes gateway"` not just `pgrep -f "hermes"`)
- Start Gateway before Dashboard
- Use `--no-open` flag for Dashboard (prevents browser launch in headless container)
- Add wait loops to confirm process startup (don't just fire-and-forget)
- Default Dashboard port: 9119, host: 127.0.0.1
- VS Code auto-forwards localhost ports

## Backup and Restore Strategy

**Git-tracked backup directory**: `.devcontainer/hermes-backup/`

Contains:
- Sanitized config template (API keys redacted)
- SOUL.md, memories, cron jobs, custom skills
- Shell environment additions file
- `.gitignore` excluding sensitive files (auth, real config)

**Restore trigger**: Detect empty home volume (missing config.yaml) in `on-create.sh`, then restore from backup directory.

**DR recovery guard** (`~/.hermes/.dr_recovery` marker):
- Set automatically by `on-create.sh` when restoring from backup or installing Hermes fresh
- Prevents automated backup from running on an unstable environment (missing auth, no hub skills, etc.)
- Backup script (`backup-hermes-config.sh`) exits immediately when marker exists
- `post-start.sh` also checks the marker and skips backup with a log warning
- Hourly cron job calls the same backup script, so the guard applies there too
- **User must manually remove the marker after completing setup**: `rm ~/.hermes/.dr_recovery`
- Rationale: running backup on an unstable environment would capture incomplete state and potentially commit noise to Git

**Automated backup schedule** (supplements manual runs):
- **Hourly**: Hermes cron job `hermes-config-backup` (schedule `0 * * * *`) runs the backup script and auto-commits+pushes changes
- **Boot-time**: `post-start.sh` runs backup script on every container start, auto-commits+pushes changes
- Both skip commit when no diff detected (noise-free)
- Both are SKIPPED entirely when `.dr_recovery` marker exists

**Hermes re-installation**: If `hermes` command not found in `on-create.sh`, install via official installer.

**Sensitive file handling**:
- API keys must NEVER be committed to git
- After restore, user must run `hermes setup` to re-enter credentials
- Consider VS Code Dev Container Secrets for credential management

**New host setup checklist** (cannot be automated):
1. `gh auth login` — browser-based GitHub authentication (required for private wiki push)
2. `hermes setup` — re-enter API keys for all providers
3. `git config --global user.name/email` — restore from backup template
4. `ollama pull <model>` — download required models (list in `ollama-models.txt`)

## Cross-Host Clone: 3-Layer Defense

Goal: a fully functional clone on a **different physical host PC** from `git clone` alone.

### Layer 1 — Git-managed (auto-restore on `git clone`)

Everything in the workspace repo restores automatically:
- Dev Container definitions (`.devcontainer/`)
- Hermes backup directory (`.devcontainer/hermes-backup/`)
- Documentation (`docs/`)
- Wiki submodule (`wiki/` → `git submodule update --init`)

### Layer 2 — Backup (semi-auto restore via `on-create.sh`)

Stored in `.devcontainer/hermes-backup/`, restored when home volume is empty:
- `config.yaml` — main Hermes config (API keys redacted if sensitive)
- `SOUL.md` — custom agent instructions
- `memories/` — MEMORY.md, USER.md
- `cron/jobs.json` — cron job definitions
- `bashrc-additions.sh` — WIKI_PATH, wiki symlink, gateway auto-start
- `skills/` — **custom (non-hub) skills only** (13 identified below)
- `gitconfig-template` — user name/email for restoration
- `dot-env-template` — .env with secrets **commented out** (not placeholder-ized), non-secrets preserved. Hermes treats ANY non-empty .env value as "already configured" and skips key entry, so `OLLAMA_API_KEY=YOUR_OLLAMA_API_KEY_HERE` causes HTTP 401. Commented-out lines like `# OLLAMA_API_KEY=` are safely ignored.
- `ollama-models.txt` — list of required Ollama models

### Layer 3 — Manual (authentication credentials, cannot be automated)

Must be configured manually on each new host:
1. **`hermes auth add`** — add API keys per provider (e.g., `hermes auth add ollama-cloud --type api-key`)
2. **`gh auth login`** — browser-based GitHub authentication (required for private wiki push)
3. **`git config --global user.name/email`** — git identity (can be templated from backup)
4. **`ollama pull <model>`** — download required models listed in `ollama-models.txt`

**Do NOT use placeholder values in .env** — Hermes reads ANY non-empty value as "already configured" and skips setup, causing HTTP 401 errors. Sensitive env vars must be **commented out** (`# OLLAMA_API_KEY=`) not given placeholder values (`OLLAMA_API_KEY=YOUR_..._HERE`).

### Custom Skills Registry (non-hub, must be backed up)

13 skills that are NOT from the hub and must be included in backup:

| Category | Skill | Size |
|---|---|---|
| autonomous-ai-agents | copilot | 6.0KB |
| autonomous-ai-agents | ollama-launch | 5.9KB |
| creative | creative-ideation | 6.3KB |
| devops | discord-secure-setup | 11.9KB |
| devops | hermes-cron-ops | 6.9KB |
| devops | hermes-devcontainer-persistence | 3.9KB |
| research | agile-meta-thinking | 13.3KB |
| research | thinking-framework | 9.4KB |
| research | wiki-daily-research | 5.5KB |
| research | wiki-daily-summary | 4.1KB |
| research | wiki-research-browser | 4.4KB |
| software-development | ai-agent-conduct | 7.5KB |
| software-development | root-cause-analysis | 2.9KB |

Hub-installed skills (79 as of 2026-04-20) are listed in `~/.hermes/skills/.bundled_manifest` and can be re-installed via `hermes skills install`.

### Authentication Inventory

Current auth state that must be manually recreated on a new host:
- `~/.hermes/auth.json` — 4 providers: openai-codex, copilot, ollama-cloud, anthropic (NEVER commit to git)
- `~/.config/gh/hosts.yml` — GitHub OAuth token (browser-based, cannot be scripted)
- `~/.gitconfig` — user.name, user.email, credential helpers (template in backup)
- SSH keys — currently not used (HTTPS + gh credential helper used instead)

## Implementation Status (branch: feat/devcontainer-persistence)

All P0/P1 tasks are **implemented and committed**. P2 validation remains.

| # | Priority | Task | File(s) | Commit | Status |
|---|---|---|---|---|---|
| 1 | P0 | Gateway + Dashboard auto-start | `post-start.sh` | `c8233d6` | ✅ Done |
| 2 | P0 | forwardPorts for Dashboard | `devcontainer.json` | `01038e0` | ✅ Done |
| 3 | P1 | Backup script (non-hub skill sync) | `scripts/backup-hermes-config.sh` | `94e0bbc` | ✅ Done |
| 4 | P1 | Initial backup snapshot + .gitignore | `hermes-backup/` | `34a3d98` | ✅ Done |
| 5 | P1 | Config restore + install check + auth warnings | `on-create.sh` | `7cdeeec` | ✅ Done |
| 6 | P1 | Docs update with implementation status | `docs/devcontainer-operations.md` | `1f61df1` | ✅ Done |
| 7 | P2 | Validate on fresh host | Manual | — | ✅ DR Test #3 passed (2026-04-21) |
| 8 | P2 | Automated backup (hourly cron + boot-time) | `cron job` + `post-start.sh` | — | ✅ Done |
| 9 | P1 | DR recovery guard (.dr_recovery marker) | `on-create.sh`, `post-start.sh`, `backup-hermes-config.sh` | `4b68792` | ✅ Done |
| 10 | P1 | Hermes install GitHub Raw URL (Bot Challenge fix) | `on-create.sh` | `cd02077` | ✅ Done |
| 11 | P1 | Claude Code fallback install | `on-create.sh`, `post-create.sh` | `4b68792` | ✅ Done |
| 12 | P2 | pyproject.toml IFS tab→0x1E delimiter fix | `scripts/lib/manifest.sh` | `4b68792` | ✅ Done |

### Key Implementation Details

**post-start.sh** — Gateway first, then 10s health-check wait, then Dashboard with `--no-open`, then 60s HTTP health-check (`curl` on port 9119). Logs success or timeout warning to `post-start.log`.

**on-create.sh** — Restore triggers when config.yaml is missing (empty volume). Copies from hermes-backup/, creates wiki symlink, applies bashrc additions and gitconfig template. Installs hermes if command not found. Warns about missing auth.

**backup-hermes-config.sh** — 3-tier execution (hourly cron + boot-time + manual). Detects custom skills via `.hub_install` marker exclusion. Generates bashrc-additions.sh, gitconfig-template, ollama-models.txt from live environment. Both automated triggers only commit when `git diff` detects changes (noise-free).

**hermes-backup/.gitignore** — Excludes auth.json, raw .env file, sessions/, hermes-agent/, bin/, state files, databases, locks, logs. The `dot-env-template` is tracked in Git (secrets **commented out** like `# OLLAMA_API_KEY=  # Set via hermes auth add or hermes setup`).

## DR Recovery Playbook -- New Host Setup

Complete procedure for bringing up a functional clone on a **different physical host PC** from `git clone` alone.

### Step 0: Clone & Open

VS Code -> `Dev Containers: Clone Repository in Container Volume...` -> enter repo URL

All subsequent steps run inside the container terminal.

### Step 1: Automated (no action needed)

`on-create.sh` runs automatically and:
- Restores config, SOUL.md, memories, cron, custom skills from `hermes-backup/`
- Deploys the env template with sensitive lines **commented out** (not placeholder values)
- Injects bashrc additions (WIKI_PATH, wiki symlink, gateway auto-start)
- Applies gitconfig template (user name, email, gh credential helper)
- Creates wiki symlink
- Installs Hermes Agent via official installer
- **Creates `~/.hermes/.dr_recovery` marker** (disables all automated backup)

After this, `post-start.sh` runs and:
- Starts Ollama server
- Starts Hermes Gateway + Dashboard
- **Skips backup** (`.dr_recovery` detected)

### Step 2: Manual Setup

| Item | Command | Purpose | Automatable? | DR Test Result |
|---|---|---|---|---|
| 2a | `gh auth login` | GitHub OAuth (browser required) | No | — |
| 2b | `hermes auth add ollama-cloud --type api-key` | Add Ollama Cloud API key to credential pool | No | ⚠️ `hermes setup` skips when .env has any non-empty value — use `hermes auth add` instead |
| 2c | `hermes setup model` | Configure providers (only if .env has empty/commented keys) | No | ✅ Works when .env uses commented-out format |
| 2f | Verify `auth.json` exists | `ls ~/.hermes/auth.json` | N/A | **Must exist before Hermes can authenticate** — 401 without it |
| 2d | `ollama pull <model>` | Download required models | Yes but slow | — (cloud models, no local pull needed) |
| 2e | `hermes skills install <name>` | Supplement missing hub skills | Partial | — |

**DR Test Observation**: `hermes setup` Quick setup flow on new host:
1. Provider/model selection → Select `ollama-cloud` or `custom`
2. API key input (OLLAMA_API_KEY etc.)
3. Messaging platform → Discord shows "already configured" (env restored by on-create.sh)
4. Gateway service install attempted → WSL systemd not running → shows manual start instructions
5. Ripgrep warning (not installed) → fallback to grep

**Important**: `hermes setup` detected existing Discord config from env backup and skipped it.
Only truly manual steps are: API key entry (Steps 2b/2c) and `gh auth login` (Step 2a).

### Step 3: Stability Verification

Confirm ALL of the following before proceeding:

| Check | Command | Expected | DR Test Result |
|---|---|---|---|
| GitHub auth | `gh auth status` | Authenticated | — (not yet tested) |
| Hermes auth | Check providers in config | Provider keys exist | ✅ ollama-cloud configured |
| Env credential placeholders | `hermes config` | No placeholder values | ✅ Discord tokens filled from backup |
| Ollama models | `ollama list` | Required models present | — (cloud models, no local pull) |
| Gateway | `pgrep -f "hermes gateway"` | PID returned | ⚠️ systemd failed (WSL); manual start required |
| Dashboard | HTTP GET on port 9119 | 200 (may take ~35 min) | — (not yet tested) |
| DR marker | `ls -la ~/.hermes/.dr_recovery` | File exists (do NOT remove yet) | ✅ marker created by on-create.sh |
| Hermes command | `hermes --version` | Version output | ✅ installed successfully via GitHub Raw URL |

### Step 4: Lift DR Recovery Mode

Remove the marker file at `~/.hermes/.dr_recovery`

This re-enables:
- Boot-time backup in `post-start.sh`
- Hourly backup cron job
- All future automated backup/commit/push

### Step 5: First Backup and Verification

Run `bash .devcontainer/scripts/backup-hermes-config.sh`, then `git diff .devcontainer/hermes-backup/`

Review diff. If intentional (auth state changes, skill updates, etc.), stage, commit and push.

### Important Constraints

- **Same Discord Bot token on 2 hosts = conflict.** If running old and new hosts in parallel, use a different bot token on one of them. DR Test confirmed: Gateway service install fails on WSL (no systemd), manual start required.
- **Dashboard first-start takes ~35 minutes** -- process exists immediately but HTTP readiness takes much longer.
- **`hermes setup` cannot be fully automated** -- it requires interactive input (provider selection, API key entry). However, on DR recovery, Discord config is auto-restored from backup and shows "already configured".
- **Gateway systemd install fails on WSL** -- `hermes gateway install` attempts systemd service creation which fails. Use tmux or nohup instead.
- **ripgrep not installed by default on fresh container** -- Hermes falls back to grep. Run `sudo apt install -y ripgrep` for full functionality.

1. **Interactive shell guard** — Content after `case $- in *i*)` in shell config never executes in lifecycle scripts. Use `post-start.sh`.
2. **pgrep specificity** — Use distinct patterns for each Hermes process.
3. **External volume limits** — Survives compose down but not volume deletion. Maintain git-tracked backups.
4. **Dashboard browser flag** — Without `--no-open`, Dashboard hangs trying to launch a browser.
5. **API keys excluded from git** — config.yaml is safe to commit (all api_key values are empty or literal "ollama", secrets are in auth.json only). auth.json is in .gitignore. Re-enter via `hermes setup` after restore.
6. **Wiki symlink** — Should be recreated in lifecycle scripts for rebuild resilience. Currently in bashrc-additions.sh.
7. **Hermes source directory** — Large (~1.4GB) but fully re-installable. Never include in backups.
8. **gh auth login requires browser** — Cannot be automated in lifecycle scripts. Must be done manually on new host.
9. **forwardPorts needed for Dashboard** — VS Code may not auto-detect port 9119.
10. **Gateway must start before Dashboard** — Dashboard depends on Gateway API. Use health-check wait loop (10s timeout).
11. **Dashboard initialization is extremely slow** — Roughly 35 minutes from nohup launch until port 9119 starts listening. Always verify with HTTP health check, not just process existence.
12. **Dashboard logs go to agent.log** — When launched via nohup redirect, dashboard.log stays 0 bytes. Actual output appears in `~/.hermes/logs/agent.log`.
13. **post-start.sh runs twice on container start** — VS Code may trigger it multiple times. `pgrep` guards prevent duplicate launches.
14. **Verification checklist for Dashboard status** — Use HTTP health check, not just `pgrep`. The process can exist without the HTTP server being ready.
15. **Ollama models not in backup** — Cloud models require explicit `ollama pull`. List them in `ollama-models.txt`.
16. **Custom skills identification** — Hub skills have `.hub_install` marker or appear in `.bundled_manifest`. Only back up skills without these markers.
17. **Backup freshness: automated (hourly cron + boot-time)** — Two automatic triggers plus manual. Both skip when `.dr_recovery` exists.
18. **Git credential helper is dynamic** — VS Code credential helper path changes on each update. Only `gh auth git-credential` is stable.
19. **Interactive shell guard in .bashrc** — Content inside `case $- in *i*)` block only executes in interactive shells. Bashrc additions must be injected inside this guard.
20. **.env template secret handling** — Sensitive variables (keys, tokens, passwords, allowed_users, home_channel) are **commented out** in the template (`# OLLAMA_API_KEY=  # Set via hermes auth add`). Do NOT use placeholder values like `YOUR_*_HERE` — Hermes treats any non-empty .env value as "already configured" and skips key entry, resulting in HTTP 401 errors.
21. **.env restore with comment detection** — on-create.sh copies dot-env-template to .env if missing, then warns about both commented-out credentials (needs `hermes auth add`) and any legacy `YOUR_*_HERE` placeholders (must be replaced or commented out).
22. **Dashboard auto-start fails silently when npm install/build fails** — If `npm install` fails, Dashboard process exits immediately with no retry. Consider adding a pre-start build check.
23. **Terminal session SIGINT after background process launch** — Use `background=true` or `nohup ... >log 2>&1 &` with subshell pattern.
24. **DR recovery mode prevents backup noise** — The `.dr_recovery` marker blocks backup entirely on unstable environments. Do NOT automate marker removal.
25. **Hermes install URL must use GitHub Raw** — `hermes.nousresearch.com/install.sh` returns HTTP 429 Vercel Bot Challenge (`x-vercel-mitigated: challenge`) to curl. Use `raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh` instead (no Bot Challenge). on-create.sh now uses the GitHub Raw URL.
26. **Claude Code lost after home volume mount** — Dockerfile installs Claude Code to `/home/vscode/.local/`, which is hidden by the home volume overlay if the volume was freshly created. on-create.sh now includes a fallback install that re-installs Claude Code when the binary is absent.
27. **POSIX IFS tab delimiter collapses empty fields** — `IFS=$'\t' read` treats tab as IFS whitespace, so consecutive tabs (empty fields like `group_name=""`) collapse into a single delimiter, causing field misalignment. Fix: use a non-whitespace delimiter (ASCII 0x1E Record Separator) for tab-delimited records that may contain empty fields. This affected `pyproject_dependency_records` → `refresh_pyproject_dependency_pins` pipeline, causing `uv remove` to receive bare specifiers (e.g., `>=1.14.0`) without package names.
28. **429 incident lesson (thinking-framework)** — When encountering HTTP errors, ALWAYS check response headers/body first (`curl -sSI` or `curl -v`) to classify the root cause (rate limit vs Bot Challenge vs WAF) before deciding retry strategy. Jumping to tactics (retry count, backoff) without Issue Thinking (MECE classification of the error) leads to escalating fixes on a wrong foundation. See `thinking-framework` skill for the full analysis.
29. **auth.json missing on DR host causes HTTP 401** — `auth.json` (credential_pool) is never committed to git and not included in backup. On a DR host, after `on-create.sh` restores the .env template, `auth.json` is absent. If .env has placeholder values like `OLLAMA_API_KEY=YOUR_OLLAMA_API_KEY_HERE`, Hermes reads them as "already configured" and skips key entry entirely (`_model_flow_api_key_provider` in `hermes_cli/main.py` checks `if existing_key: ... print("✓") ... skip`). **Fix (immediate)**: Use `hermes auth add ollama-cloud --type api-key` to register real credentials. **Fix (root cause)**: The backup script now outputs sensitive env vars as **commented-out** lines (`# OLLAMA_API_KEY=`) instead of placeholder values, so `get_env_value()` returns empty and `hermes setup` correctly prompts for key entry.
30. **VS Code Dev Container Secrets for DR auth automation** — `devcontainer.json` supports a `"secrets"` field that prompts for values at container creation and exposes them as environment variables inside the container. This is the recommended way to automate credential injection without committing secrets to git. Schema: `"secrets": { "OLLAMA_API_KEY": "Ollama Cloud API Key" }`. The container sees `$OLLAMA_API_KEY` and `on-create.sh` can call `hermes config set` to populate `auth.json` from it.
31. **Cron job prompt workspace path must match actual repo location** — The automated backup cron job (`hermes-config-backup`) references a hardcoded workspace path (e.g., `/workspaces/hermes-agent-lab`). If the actual repo is at a different path (e.g., `/workspaces/hermes-agent-001`), the backup script won't be found. Always verify the workspace path matches the cron job prompt before running. If there's a mismatch, discover the correct path first (`find /workspaces -name "backup-hermes-config.sh"`) and run from there.