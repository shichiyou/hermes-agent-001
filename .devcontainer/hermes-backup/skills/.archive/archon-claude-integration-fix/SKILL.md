---
name: archon-claude-integration-fix
description: Resolving an issue where Archon's dynamically created git worktrees cause Claude Code to hang due to the Workspace Trust dialog (first_event_timeout / Query aborted).
version: 1.1.0
author: Hermes Agent
license: MIT
---

# Archon + Claude Code Trust Issue Resolution

## Problem Statement
When running Archon workflows, the process frequently hangs for 60 seconds and fails with `Query aborted` or `claude.first_event_timeout`. Root cause: either a **nested Claude Code deadlock** (when Archon is invoked from inside another Claude Code session) or a **first-event timeout** that is too short for slow environments. The Archon command is ultimately a subprocess calling `claude`; if the outer session is also Claude Code, the two sessions compete for the same stdio or event loop.

## Physical Evidence
- **Symptom**: `first_event_timeout` in Archon logs.
- **Confirmation**: Manually running `claude "prompt" --add-dir <worktree_path>` resolves the issue immediately.
- **Confirmed root cause**: Running the workflow from inside Claude Code causes deadlock. The official docs (`troubleshooting.md`) state: "Nested Claude Code sessions can deadlock — the outer session waits for tool results that the inner session never delivers."
- **Confirmed fix**: Setting `ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000` before the `archon workflow run` command extends the timeout and resolves the abort.

## Resolution Strategy

### 1. The Right Solution: Official Environment Variables
The only robust and documented solutions are environment variables set **before** the `archon workflow run` invocation. These are explicitly documented in Archon's official troubleshooting docs.

**Extend first-event timeout:**
```bash
ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000 archon workflow run <workflow-name> "..."
```

**Suppress the nested-Claude warning** (if running from within Claude Code and not deadlocking):
```bash
ARCHON_SUPPRESS_NESTED_CLAUDE_WARNING=1 ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000 \
  archon workflow run <workflow-name> "..."
```

### 2. Run Archon from Outside Claude Code (Recommended by Docs)
The official docs recommend running `archon serve` from a regular shell **outside** Claude Code and using the Web UI or HTTP API. If you must use the CLI from inside Claude Code, use the environment variables above.

### 3. Infrastructure Prep (Pre-requisites)
Ensure required data directories exist to prevent silent spawn failures:
```bash
mkdir -p ~/.archon/workspaces ~/.archon/worktrees
```

## Deprecated / Ineffective Workarounds (Do NOT Use)

### ~~Configuration-based Mitigation~~ (Does NOT work)
Adding `additionalDirectories` to `~/.archon/config.yaml`:
```yaml
assistants:
  claude:
    additionalDirectories:
      - /absolute/path/to/your/project-root
```
*This does NOT prevent `first_event_timeout` on Archon >= 0.3.x. The timeout is governed by `ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS`, not directory trust.*

### ~~`--add-dir` flag~~ (Not applicable)
Manually appending `--add-dir <worktreePath>` to Claude Code's spawn arguments inside Archon's source was suggested in v1.0.0 of this skill but is neither documented by Archon nor tested as a stable fix. The official support channels do not recommend source modifications for this issue.

## Security Warning
**DO NOT** use `--dangerously-skip-permissions` or `--allow-dangerously-skip-permissions` as a production fix. These flags bypass all safety checks and grant the AI agent unrestricted filesystem access, violating the principle of least privilege.

## Verification Process
1. Ensure you are **not inside a Claude Code session** when invoking Archon CLI (or use the warning suppressor if you are).
2. Execute the workflow with the timeout variable:
   ```bash
   ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000 \
     archon workflow run <workflow-id> "prompt"
   ```
3. Monitor logs for `first_event_timeout` (should be absent).
4. Verify that the AI responds without 60-second hangs.
