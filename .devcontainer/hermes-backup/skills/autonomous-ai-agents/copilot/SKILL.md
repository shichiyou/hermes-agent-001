---
name: copilot
description: Delegate coding tasks to GitHub Copilot CLI agent. Full agentic capabilities — build, edit, debug, and refactor code through natural language conversations. Requires Copilot subscription and the copilot CLI installed.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [Coding-Agent, Copilot, GitHub, Code-Review, Refactoring]
    related_skills: [claude-code, codex, hermes-agent]
---

# GitHub Copilot CLI

Delegate coding tasks to [GitHub Copilot CLI](https://github.com/github/copilot-cli) — a fully agentic coding assistant that runs in your terminal, powered by the same agentic harness as GitHub's Copilot coding agent.

## Key Facts (verified 2026-04-20)

- **Model**: Auto model selection GA — `auto` routes to GPT-5.4, GPT-5.3-Codex, Sonnet 4.6, Haiku 4.5 etc. based on plan/policies. Manual selection still available via `/model`. Opus 4.7 GA (7.5x multiplier, promo pricing until Apr 30). Opus 4.5/4.6 being retired in favor of Opus 4.7.
- **ACP Support**: Yes — `copilot --acp` enables Agent Communication Protocol
- **Subscription**: Active Copilot subscription required (Plus, Pro, Business, Enterprise, or Edu). **Note: New Copilot Pro trials paused as of April 10, 2026.**
- **Agentic**: Can build, edit, debug, and refactor code autonomously
- **MCP**: Ships with GitHub MCP server by default; supports custom MCP servers
- **LSP**: Supports Language Server Protocol for code intelligence
- **Autopilot mode** (experimental): Shift+Tab to cycle modes; agent continues until task complete
- **Agent Skills** (`gh skill`): New CLI command (gh v2.90.0+) to discover, install, manage, and publish agent skills. Follows the open Agent Skills spec (agentskills.io). Works across Copilot, Claude Code, Cursor, Codex, Gemini CLI. Supports version pinning (`--pin`), content-addressed change detection, and `gh skill publish` for validation/publishing.
- **Auto model discount**: auto mode gives 10% discount on premium request multipliers (e.g., 1x → 0.9x)
- **Data residency**: US + EU regions now supported; FedRAMP Moderate compliant. 10% multiplier increase for data-resident requests. Japan/Australia planned later in 2026.

## Prerequisites

Install the Copilot CLI using your preferred method (see official docs at https://github.com/github/copilot-cli). Version 1.0.31+ confirmed working.

On first launch, authenticate with:
- GitHub OAuth: Use `/login` slash command
- Personal Access Token: Set `GH_TOKEN` or `GITHUB_TOKEN` env var (requires "Copilot Requests" permission)

## Orchestration via Hermes

### Mode 1: ACP via delegate_task (PREFERRED)

```python
delegate_task(
    goal="Implement user authentication with JWT tokens",
    acp_command="copilot",
    context="Working in /path/to/project. Use existing db module.",
    toolsets=["terminal", "file"]
)
```

ACP mode (`copilot --acp --stdio`) enables structured communication. This is the cleanest integration path and handles authentication, tool use, and result parsing automatically.

### Mode 2: Print mode (`-p`) via terminal

Non-interactive one-shot tasks:

```python
terminal(command="copilot -p 'Add error handling to all API calls in src/'", workdir="/path/to/project", timeout=120)
```

### Mode 3: Interactive via tmux

For multi-turn sessions:

```python
# Start session
terminal(command="tmux new-session -d -s copilot -x 140 -y 40")
terminal(command="tmux send-keys -t copilot 'cd /path/to/project && copilot' Enter")

# Wait for startup, then send task
terminal(command="sleep 5 && tmux send-keys -t copilot 'Refactor the auth module to use JWT tokens' Enter")

# Monitor
terminal(command="sleep 20 && tmux capture-pane -t copilot -p -S -60")

# Exit
terminal(command="tmux kill-session -t copilot")
```

## CLI Flags Reference

| Flag | Effect |
|------|--------|
| `-p, --prompt <text>` | Non-interactive print mode (exits when done) |
| `--acp` | Start as ACP server (for agent-to-agent communication) |
| `--banner` | Show splash banner on launch |
| `--experimental` | Enable experimental features (Autopilot mode, etc.) |

## Slash Commands (Interactive Mode)

| Command | Purpose |
|---------|---------|
| `/login` | Authenticate with GitHub |
| `/model` | Switch AI model (Claude Sonnet 4.5, GPT-5, etc.) |
| `/lsp` | View LSP server status |
| `/feedback` | Submit feedback |
| `/experimental` | Toggle experimental mode |

## LSP Configuration

Create `~/.copilot/lsp-config.json` (user-level) or `.github/lsp.json` (repo-level):

```json
{
  "lspServers": {
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "fileExtensions": {
        ".ts": "typescript",
        ".tsx": "typescript"
      }
    }
  }
}
```

## Pitfalls & Gotchas

1. **Copilot subscription required** — won't work without an active subscription. **New Pro trials paused since April 10, 2026.**
2. **Organization policy can block** — if org admin disabled Copilot CLI, authentication won't help
3. **ACP mode requires authentication** — ensure `GH_TOKEN` env var or `/login` has been completed before using `delegate_task`
4. **Auto model selection is GA** — default routing is now `auto` (GPT-5.4, GPT-5.3-Codex, Sonnet 4.6, Haiku 4.5). Opus 4.5/4.6 being retired in favor of Opus 4.7.
5. **Autopilot mode deducts premium requests** — each prompt costs one premium request from your monthly quota. Auto mode gives 10% discount on multipliers.
6. **PAT authentication** needs "Copilot Requests" permission specifically, not general repo access
7. **`gh skill`** requires GitHub CLI v2.90.0+ — older versions won't have the command

## Verification Smoke Test

```python
# Via delegate_task (ACP)
delegate_task(
    goal="Create hello-copilot.txt with 'Hello from GitHub Copilot CLI!' and read it back",
    acp_command="copilot",
    toolsets=["terminal", "file"]
)

# Via terminal (print mode)
terminal(command="copilot -p 'What is 2+2? Just respond with the number.'", timeout=30)
```