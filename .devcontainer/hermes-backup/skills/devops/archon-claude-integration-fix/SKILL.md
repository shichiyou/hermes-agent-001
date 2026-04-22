---
name: archon-claude-integration-fix
description: Resolving an issue where Archon's dynamically created git worktrees cause Claude Code to hang due to the Workspace Trust dialog (first_event_timeout / Query aborted).
version: 1.0.0
author: Hermes Agent
license: MIT
---

# Archon + Claude Code Trust Issue Resolution

## Problem Statement
When running Archon workflows, the process frequently hangs for 60 seconds and fails with `Query aborted` or `claude.first_event_timeout`. This is caused by Claude Code's **Workspace Trust** mechanism: it detects that the dynamically created `${ARCHON_DATA}/worktrees/...` directory is not trusted and attempts to show an interactive trust dialog, which is blocked in Archon's non-interactive subprocess environment.

## Physical Evidence
- **Symptom**: `first_event_timeout` in Archon logs.
- **Confirmation**: Manually running `claude "prompt" --add-dir <worktree_path>` resolves the issue immediately.
- **Ineffective workaround**: Adding the parent directory (`~/.archon/worktrees`) to `config.yaml`'s `additionalDirectories` does not resolve the issue, as Claude Code requires explicit trust for the specific leaf directory of the worktree.

## Resolution Strategy

### 1. Infrastructural Prep (Pre-requisites)
Ensure required data directories exist to prevent silent spawn failures:
```bash
mkdir -p ~/.archon/workspaces ~/.archon/worktrees
```

### 2. The "Right" Solution: Dynamic Trust Injection
The only robust and secure solution is to ensure the `worktreePath` is passed to Claude Code using the `--add-dir` flag at runtime.

**Implementation Logic:**
Inside the Archon codebase (where the `ClaudeClient` spawns the process):
- Identify the absolute path of the current worktree.
- Append `--add-dir <worktreePath>` to the arguments array passed to the `spawn` call.

### 3. Configuration-based Mitigation (Partial/Limited)
If source modification is not an option, you can try adding common project roots to `~/.archon/config.yaml`:
```yaml
assistants:
  claude:
    additionalDirectories:
      - /absolute/path/to/your/project-root
```
*Note: This may not work for randomly named worktrees depending on the version of Claude Code's trust model.*

## Security Warning
**DO NOT** use `--dangerously-skip-permissions` or `--allow-dangerously-skip-permissions` as a production fix. These flags bypass all safety checks and grant the AI agent unrestricted filesystem access, violating the principle of least privilege.

## Verification Process
1. Execute the workflow: `archon workflow run <workflow-id> "prompt"`
2. Monitor logs for `first_event_timeout`.
3. Verify that the AI responds without 60-second hangs.
