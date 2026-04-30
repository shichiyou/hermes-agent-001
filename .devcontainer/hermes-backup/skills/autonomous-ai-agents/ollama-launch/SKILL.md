---
name: ollama-launch
description: Launch CLI coding agents (Claude Code, Copilot CLI, Codex CLI, Hermes) using local Ollama models via the `ollama launch` subcommand. Verified on Ollama v0.20.7/v0.21.0.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [Ollama, CLI-Agent, Local-LLM, Launch, Integration]
    related_skills: [claude-code, codex, copilot, hermes-agent]
---

# ollama launch — Route CLI Agents Through Local Ollama Models

`ollama launch` (Ollama v0.20+) configures environment variables and config files so that CLI coding agents route their LLM calls through a local Ollama server instead of their default cloud API endpoints.

## Prerequisites

- Ollama v0.20+ installed and running (`ollama serve`)
- At least one model pulled: `ollama pull gemma4:31b-cloud` or `ollama pull glm-5.1:cloud`
- The target CLI agent installed (claude, codex, copilot, hermes, etc.)

## Supported Integrations (10 total)

From source code inspection of `cmd/launch/registry.go`:

| Agent | Binary | Status | Notes |
|-------|--------|--------|-------|
| claude | `claude` | Verified | Routes via ANTHROPIC_BASE_URL |
| codex | `codex` | Partial | Needs env var workaround (see below) |
| copilot | `copilot` | Verified | Routes via COPILOT_PROVIDER_BASE_URL |
| hermes | `hermes` | Verified | Writes hermes config + gateway setup |
| opencode | `opencode` | Untested | |
| openclaw | `openclaw` | Untested | |
| droid | `droid` | Untested | |
| pi | `pi` | Untested | |
| cline | `cline` | Untested | Hidden entry |
| vscode | `code` | Untested | |

## Basic Usage

```bash
# Launch an agent with a specific Ollama model
ollama launch <agent> --model <model> -y

# Examples
ollama launch hermes --model gemma4:31b-cloud -y
ollama launch claude --model glm-5.1:cloud -y
ollama launch copilot --model glm-5.1:cloud -y
```

The `-y` flag auto-confirms any prompts.

## Model Routing

`ollama launch` sets environment variables to route API calls:

| Agent | Env Var Set | Value |
|-------|------------|-------|
| claude | ANTHROPIC_BASE_URL | http://localhost:11434/v1 |
| claude | ANTHROPIC_API_KEY | ollama |
| codex | OPENAI_BASE_URL | http://localhost:11434/v1 |
| codex | OPENAI_API_KEY | ollama |
| copilot | COPILOT_PROVIDER_BASE_URL | http://localhost:11434/v1 |
| copilot | COPILOT_PROVIDER_API_KEY | ollama |
| hermes | Config file | Writes hermes config.yaml |

## Passing Arguments to Agents

Use `--` to separate `ollama launch` flags from agent-specific flags:

```bash
# Claude Code with prompt (print mode)
ollama launch claude --model glm-5.1:cloud -y -- -p "Say hello" --dangerously-skip-permissions

# Copilot CLI with prompt
ollama launch copilot --model glm-5.1:cloud -y -- -p "Say hello"
```

## Verified Working Patterns

### Hermes Agent
```bash
ollama launch hermes --model gemma4:31b-cloud -y
```
Launches Hermes v0.10.0+ interactively. Model configured in hermes config.

**Pitfall:** The `--` separator causes Hermes to interpret subsequent `-p` as a profile name, not a prompt flag. For non-interactive testing, use `delegate_task` or run `hermes` directly with env vars.

### Claude Code
```bash
# Interactive (requires TTY)
ollama launch claude --model glm-5.1:cloud -y

# Print mode (one-shot, no TTY needed)
ollama launch claude --model glm-5.1:cloud -y -- -p "Say hello in one word." --dangerously-skip-permissions
```

**Important:** Claude Code v2.1.112+ has REMOVED the `--acp` flag. ACP communication is only available via Hermes Agent's `delegate_task`, not as a standalone `claude --acp` command.

### GitHub Copilot CLI
```bash
# Print mode
ollama launch copilot --model glm-5.1:cloud -y -- -p "Say hello in one word."
```

Copilot CLI v1.0.31+ supports `--acp --stdio` for agent-to-agent communication via `delegate_task`.

### Codex CLI — Special Workaround Required

`ollama launch codex` alone FAILS because Codex still tries ChatGPT account validation even after profile configuration. You need BOTH the profile AND explicit environment variables:

```bash
env OPENAI_API_KEY=ollama OPENAI_BASE_URL=http://localhost:11434/v1 \
  codex exec --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check \
  --profile ollama-launch \
  -m glm-5.1:cloud "Your prompt here"
```

**Why:** `ollama launch codex` writes an `ollama-launch` profile to codex config, but Codex's startup validation checks for a ChatGPT account before loading the profile, causing an immediate error. The environment variables bypass this check.

**WSL Note:** Codex's sandbox (bubblewrap) fails on WSL by default. Always use `--dangerously-bypass-approvals-and-sandbox` on WSL.

**No ACP support:** Codex CLI cannot be used via `delegate_task(acp_command=...)`. Always use `terminal` with `codex exec`.

**OLLAMA_HOST env var:** Always use `$OLLAMA_HOST` (typically `127.0.0.1:11434`) instead of hardcoding `localhost:11434` or `127.0.0.1:11434` in Codex config `base_url`. The env var is set by Ollama and may differ across environments (containers, remote servers, custom ports). Hardcoding breaks portability. In `~/.codex/config.toml`, set `base_url = "http://127.0.0.1:11434/v1/"` (resolving OLLAMA_HOST at config-write time), or prefer the `env` approach: `OPENAI_BASE_URL=http://$OLLAMA_HOST/v1`.

**Codex exec timeout with interactive workflows:** When an agent follows a workflow that creates question files and waits for user input (e.g., AI-DLC Requirements Analysis), `codex exec` will hang because it cannot provide interactive responses. The agent output up to the timeout point IS valid data — the question files it created are observable results. Increase timeout (e.g., 600s) and capture the output + created files before cleanup. Do NOT use `--full-auto` to bypass this; it inverts the purpose of observing whether the agent asks questions.

## Recommended Models

From `cmd/launch/models.go`:

| Model | Use Case |
|-------|----------|
| `gemma4:31b-cloud` | General purpose (Hermes default) |
| `glm-5.1:cloud` | General purpose (Claude/Copilot/Codex) |
| `gpt-oss-3:cloud` | Alternative |

Cloud-tagged models (`-cloud`) offload to remote inference when local resources are insufficient.

## Pitfalls

1. **Codex CLI requires env var workaround** — `ollama launch codex` alone is insufficient; set OPENAI_API_KEY=ollama and OPENAI_BASE_URL explicitly
2. **Claude Code `--acp` removed** — v2.1.112+ no longer supports `--acp`. Use `delegate_task` for ACP, or `-p` for print mode
3. **Hermes `-p` misparse** — After `--`, `-p` is interpreted as a Hermes profile name, not a prompt flag
4. **WSL sandbox** — Codex CLI fails on WSL without `--dangerously-bypass-approvals-and-sandbox --skip-git-repo-check`
5. **`--` separator required** — Agent-specific flags must come after `--` to avoid being parsed by `ollama launch`
6. **Ollama must be running** — `ollama serve` or `ollama serve &` must be active before launching agents
7. **Use `OLLAMA_HOST` env var, never hardcode `localhost`** — In devcontainers and WSL, `localhost` may not resolve correctly. Always read `$OLLAMA_HOST` (typically `127.0.0.1:11434`) and construct the base URL as `http://${OLLAMA_HOST}/v1/`. Hardcoding `http://localhost:11434/v1` in config files (e.g. `~/.codex/config.toml`) breaks when the Ollama server binds to a different interface inside a container.
8. **Ollama cloud models have parallel request limits** — Cloud-tagged models (`-cloud`) typically allow 3 concurrent requests. When running multiple evaluations serially (e.g. Before/After comparison experiments), ensure sequential execution — do not parallelize calls to the same cloud model.