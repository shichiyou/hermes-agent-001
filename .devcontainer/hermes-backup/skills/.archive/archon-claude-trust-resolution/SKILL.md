---
name: archon-claude-trust-resolution
description: Resolving "Query aborted" / "first_event_timeout" errors when running Archon workflows with Claude Code in non-interactive environments.
version: 1.2.0
author: Hermes Agent
license: MIT
---

# Archon & Claude Code Trust Resolution

## Problem
When running `archon workflow run`, Claude Code may fail with `Error: Query aborted` or `claude.first_event_timeout` after 60 seconds. In non-interactive environments (e.g., within another Claude Code session or through a terminal tool), the root cause is typically a **nested Claude Code session deadlock**, not a "Workspace Trust" dialog.

## Root Causes
1. **Nested Claude Code Deadlock**: Running Archon workflows from inside another Claude Code session causes the outer session to wait for tool results that the inner (Archon-invoked) session never delivers. The official Archon troubleshooting docs state: "Nested Claude Code sessions can deadlock — the outer session waits for tool results that the inner session never delivers."
2. **Default 60-second Timeout**: The inner Claude Code session spawned by Archon has a `first_event_timeout` of 60 seconds by default. In slow environments, this may be insufficient.

## Resolution Process

### 1. Extend the First-Event Timeout (Official Fix)
Set the environment variable **before** running Archon. This is documented in the official Archon troubleshooting (`packages/docs-web/src/content/docs/reference/troubleshooting.md`).

- **Action**: Prefix your `archon workflow run` command with the timeout variable.
  ```bash
  ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000 archon workflow run ...
  ```
- **Verification**: The workflow should no longer abort at exactly 60s. Check logs for `claude.rate_limit_event` (normal, non-fatal) instead of `claude.first_event_timeout`.

### 2. Suppress the Nested-Cliude Warning (Official Fix)
If running from within Claude Code and the workflow is not actually deadlocking, suppress the warning:
  ```bash
  ARCHON_SUPPRESS_NESTED_CLAUDE_WARNING=1 ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS=120000 archon workflow run ...
  ```

### 3. Ensure Valid Git Foundation (Still Required)
Archon requires the launch directory to be a valid git repository to correctly spawn worktrees.

- **Requirement**: The launch directory must have a `.git` folder and at least one commit (HEAD must exist).
- **Setup**:
  ```bash
  cd /path/to/test-project
  git init -q
  echo '# Initial' > README.md
  git add README.md
  git commit -m 'Initial commit'
  ```

### 4. Run from the Target Repo Root (Official Pattern)
The official docs specify `cd /path/to/your/repository && archon workflow run ...`, not `archon workflow run --cwd /path/to/repo`. While `--cwd` exists as a CLI option, physical testing showed that `cd` into the repo root before running is the expected and tested pattern.

```bash
# Official pattern
cd /path/to/your/repository
archon workflow run archon-assist "What does this codebase do?"
```

## Rigorous Experiment Protocol (Clean-Start Requirement)

When testing Archon workflow execution, **any failure contaminates the experiment conditions**. Do NOT patch forward from a dirty state.

### Before Any Archon Test — Pre-Flight Checklist

1. **Confirm target repo has a `.git` directory and at least one commit.**
   ```bash
   cd /path/to/target-repo
   git log --oneline -1 && echo "OK" || echo "FAIL: no commits"
   ```

2. **Ensure NO `origin` remote is configured unless you INTEND to fetch from it.**
   Archon does NOT require a remote for local testing. An `origin` pointed at an unrelated repo (`coleam00/Archon`) causes Archon to synchronise the **wrong** codebase into worktrees, making your test a test of Archon-on-Archon instead of Archon-on-your-repo.
   ```bash
   git remote -v
   # Expected: (nothing)  or  only remotes that actually belong to this repo.
   ```

3. **Verify `.archon/config.yaml` contains ONLY documented keys.**
   The official `getting-started/configuration.md` example only shows `assistants:`, `commands: folder`, and `worktree: copyFiles`.  
   **Do NOT add:**
   - `worktree.baseBranch` — forces `git fetch origin <branch>` and will fail without origin.
   - `assistants.claude.additionalDirectories` — not a documented timeout fix.
   ```bash
   cat .archon/config.yaml 2>/dev/null || echo "No .archon/config.yaml — that's fine."
   ```

4. **Confirm the working directory is clean of previous worktree artifacts.**
   If a prior test created worktrees under `~/.archon/workspaces/` or `~/.archon/worktrees/`, remove them before claiming a new result.
   ```bash
   archon isolation list
   archon isolation cleanup --merged
   # Or manually remove stale dirs under ~/.archon/workspaces/ and ~/.archon/worktrees/
   ```

5. **Run from the repo root using `cd`, NOT `--cwd`.**
   ```bash
   cd /path/to/target-repo
   archon workflow run archon-assist "What does this codebase do?"
   ```

### Failure Response — Mandatory Rollback

If a workflow run fails (`Query aborted`, `first_event_timeout`, `Failed to fetch base branch`, etc.):

1. **STOP.** Do NOT apply "just one more config tweak".
2. **Record the EXACT error:** copy stdout/stderr and exit code.
3. **Identify all state changes caused by the failed run:**
   - New branches in `git branch -a`
   - New worktrees in `git worktree list`
   - New entries in `~/.archon/archon.db`
   - Any files written under `.archon/` or `~/.archon/workspaces/`
4. **Revert the environment to pre-test condition:**
   - Remove unintended remote: `git remote remove origin`
   - Remove extra worktrees: `git worktree remove <path>` + `git branch -D <branch>`
   - Remove `.archon/config.yaml` entries that are not in the official example.
   - Delete stale isolation rows in `~/.archon/archon.db` (or just the whole DB during pure CLI testing).
5. **Re-run from step 1 of the pre-flight checklist with ONE variable changed.**

## Pitfalls & Lessons Learned
- **Do NOT rely on `--cwd` as a substitute for `cd`**: While the CLI accepts `--cwd`, the official onboarding docs (`overview.md`, `quick-start.md`) show `cd` into the repo first. Physical execution with `--cwd` when `baseBranch: main` is set (without origin remote present) caused `Failed to fetch base branch from origin` errors that did not occur under `cd`. Additionally, using `--cwd` in past sessions produced abnormal worktree paths under `~/.archon/worktrees/workspaces/...` instead of the standard `~/.archon/workspaces/<owner>/<repo>/worktrees/` layout.
- **Avoid `worktree.baseBranch: main` in a repo without origin remote**: The `config.yaml` option is not in the official example configs. Setting it forces `git fetch origin <baseBranch>`, which fails when origin is absent — producing a false "network" error.
- **Avoid `additionalDirectories` workaround**: Setting `assistants.claude.additionalDirectories: ~/.archon/worktrees` in `~/.archon/config.yaml` is not documented as a fix for timeout issues and did not resolve `Query aborted` in physical testing. The real fix is `ARCHON_CLAUDE_FIRST_EVENT_TIMEOUT_MS`.
- **Never point a test repo's `origin` at an unrelated repository** (e.g., `coleam00/Archon`): Archon derives `codebase_id` from the remote URL. An unrelated origin causes Archon to clone the wrong codebase into worktrees, making the test evaluate Archon-on-Archon instead of Archon-on-your-target.
- **Do not report "success" until a clean re-run passes**: A single successful execution after several failed dirty attempts is not a verified fix. The fix must work from a freshly prepared environment.
