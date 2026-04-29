---
name: claude-code-headless-operations
description: >
  Resolve Claude Code first_event_timeout, Query aborted, and Workspace Trust issues
  in non-interactive shells, agent environments, and dynamically-created directory
  workflows (Archon, CI, cron, subagents). Covers env-var fixes, parent-directory
  trust, nested-deadlock avoidance, and clean-experiment protocols.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags:
      - claude-code
      - archon
      - headless
      - trust
      - timeout
      - non-interactive
      - worktree
    related_skills:
      - physical-evidence-and-verification
      - experience-repository-setup
      - workspace-hygiene
---

# Claude Code Headless Operations

> **Running Claude Code in non-interactive environments where the Workspace Trust dialog is invisible and the 60-second default timeout kills sessions.**

This skill is a **class-level umbrella** for operating Claude Code inside scripts, subagents, CI pipelines, cron jobs, and orchestrators like Archon that create dynamic git worktrees. It replaces the fragmented session-specific timeout fixes with a single playbook.

## When to Use
- `claude.first_event_timeout` or `Query aborted` appears in logs.
- Archon (or another orchestrator) spawns Claude Code inside a non-interactive shell.
- Dynamic worktrees/directories (e.g., `~/.archon/workspaces`) trigger the invisible Workspace Trust prompt.
- You need a reproducible, clean-start protocol for validating Claude Code integrations.

---

## Part I — Immediate Fixes (Environment & Process)

### A. Extend the First-Event Timeout (Official Fix)
The inner Claude Code session spawned by Archon defaults to 60 seconds. In slow or constrained environments this is insufficient.

```bash
ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000 archon workflow run <workflow-id> "prompt"
```
- Set this **before** every `archon workflow run` invocation.
- Verify absence of `claude.first_event_timeout` in logs; `claude.rate_limit_event` is normal and non-fatal.

### B. Suppress Nested-Claude Warning (Official Fix)
If you must run Archon from inside an existing Claude Code session, suppress the deadlock warning:

```bash
ARCHON_SUPPRESS_NESTED_CLAUDE_WARNING=1 \
  ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000 \
  archon workflow run <workflow-id> "prompt"
```
- This does **not** prevent the actual deadlock risk — see Part II.

### C. Run from Outside Claude Code (Golden Path)
The official docs recommend starting `archon serve` from a regular shell **outside** any Claude Code session and using the Web UI or HTTP API. If the CLI must be used from inside Claude Code, use the env vars above, but accept elevated deadlock risk.

---

## Part II — Parent Directory Trust (The Golden Path)

### Problem
Claude Code requires a "Workspace Trust" confirmation for any directory not previously trusted. In non-interactive environments the prompt is invisible, causing a hang until the caller's timeout is reached.

### Solution: Trust the Common Ancestor
Trust the highest-level directory under which all dynamic worktrees are created (e.g., `~/.archon`), so every child directory inherits trust automatically.

1. **Identify the root**: Determine the top-level directory managing dynamic workspaces.
2. **Interactive one-time trust**:
   ```bash
   cd <ROOT_DIRECTORY>
   claude   # interactive session
   # Select: 1. Yes, I trust this folder
   ```
3. **Physical verification**:
   ```bash
   ls -la ~/.claude/projects
   # Ensure a directory matching the root exists.
   ```
4. **Inheritance test**:
   ```bash
   mkdir -p <ROOT_DIRECTORY>/test-child
   cd <ROOT_DIRECTORY>/test-child
   echo 'exit' | claude
   ```
   **Success**: Exits immediately without printing "Quick safety check".

### Pitfall: Bypass vs. Trust
- ❌ `--dangerously-skip-permissions` bypasses the check for that single execution but does **not** register the directory as trusted in `~/.claude/projects`. It also violates least-privilege and must never be used in production.
- ✅ Interactive trust is persistent and safe.

---

## Part III — Clean-Environment Protocol (Rigorous Experiment Checklist)

When testing or integrating Claude Code headlessly, **any failure contaminates the experiment conditions**.

### Pre-Flight Checklist

1. **Valid git foundation in the target repo**
   ```bash
   cd /path/to/target-repo
   git log --oneline -1 && echo "OK" || echo "FAIL: no commits"
   ```
   Archon requires `.git` and at least one commit.

2. **No unrelated `origin` remote**
   ```bash
   git remote -v
   ```
   An `origin` pointed at an unrelated repo (e.g., `coleam00/Archon`) causes Archon to clone the wrong codebase into worktrees, making the test evaluate Archon-on-Archon instead of Archon-on-your-repo.

3. **Clean `.archon/config.yaml`**
   ```bash
   cat .archon/config.yaml 2>/dev/null || echo "No config — that's fine."
   ```
   Keep **only** documented keys (`assistants`, `commands: folder`, `worktree: copyFiles`).
   Do **not** add:
   - `worktree.baseBranch` — forces `git fetch origin <branch>`, which fails without `origin`.
   - `assistants.claude.additionalDirectories` — not a documented timeout fix.

4. **Clean worktree artifacts**
   ```bash
   archon isolation list
   archon isolation cleanup --merged
   # Or manually remove stale dirs under ~/.archon/workspaces/ and ~/.archon/worktrees/
   ```
   Previous failed runs may leave dirty state that poisons the next run.

5. **Run from the repo root using `cd`, NOT `--cwd`**
   ```bash
   cd /path/to/target-repo
   archon workflow run archon-assist "What does this codebase do?"
   ```
   Physical testing showed that `--cwd` produces abnormal worktree paths and `Failed to fetch base branch` errors, while `cd` follows the official tested pattern.

6. **Infrastructure directories exist**
   ```bash
   mkdir -p ~/.archon/workspaces ~/.archon/worktrees
   ```

### Failure Response — Mandatory Rollback
If a workflow run fails (`Query aborted`, `first_event_timeout`, `Failed to fetch base branch`, etc.):

1. **STOP.** Do not apply "just one more config tweak".
2. **Record the exact error:** stdout, stderr, exit code.
3. **Identify all state changes** caused by the failed run:
   - New branches (`git branch -a`)
   - New worktrees (`git worktree list`)
   - New `~/.archon/archon.db` entries
   - Files written under `.archon/` or `~/.archon/workspaces/`
4. **Revert the environment** to pre-test condition:
   - Remove unrelated remote: `git remote remove origin`
   - Remove extra worktrees: `git worktree remove <path> && git branch -D <branch>`
   - Strip non-official keys from `.archon/config.yaml`
   - Delete stale isolation rows (or the whole DB during pure CLI testing)
5. **Re-run from step 1 with exactly ONE variable changed.**

---

## Part IV — Root Cause Summary

| Symptom | Most Likely Cause | Fix |
|---|---|---|
| `Query aborted` at ~60s | Nested Claude Code deadlock | Run from outside Claude Code, or suppress warning + extend timeout |
| `first_event_timeout` | 60-second default too short | `ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000` |
| Hang at start, no error output | Workspace Trust dialog invisible | Parent-directory trust (Golden Path) |
| `Failed to fetch base branch` | `worktree.baseBranch: main` without `origin` remote | Remove `baseBranch` from config.yaml |
| Abnormal worktree paths | Using `--cwd` instead of `cd` | Switch to `cd /repo && archon workflow run ...` |

---

## Security Warning
- **Never** use `--dangerously-skip-permissions` or `--allow-dangerously-skip-permissions` in production. These bypass all safety checks and grant unrestricted filesystem access, violating least privilege.
- Trust directories through the official interactive flow, not through CLI bypass flags.

---

## Related Skills
- `physical-evidence-and-verification` — truth-through-tools discipline for every state-changing operation.
- `experience-repository-setup` — isolated test repos with submodules for methodology evaluation.
- `workspace-hygiene` — routing artifacts away from parent repo pollution.
