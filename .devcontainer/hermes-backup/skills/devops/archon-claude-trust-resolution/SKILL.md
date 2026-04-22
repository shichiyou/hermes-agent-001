---
name: archon-claude-trust-resolution
description: Resolving "Query aborted" / "first_event_timeout" errors when running Archon workflows with Claude Code in non-interactive environments.
version: 1.1.0
author: Hermes Agent
license: MIT
---

# Archon & Claude Code Trust Resolution

## Problem
When running `archon workflow run`, Claude Code may fail with `Error: Query aborted` or `claude.first_event_timeout` after 60 seconds. This is typically caused by a "Workspace Trust" dialog being triggered in a non-interactive shell, causing the process to hang and eventually timeout.

## Root Causes
1. **Lack of Directory Trust**: Claude Code requires the CWD to be trusted. Archon creates dynamic worktrees in `~/.archon/worktrees/`. If these paths aren't trusted, Claude hangs on the trust prompt.
2. **Missing Git Root**: Archon relies on `git worktree`. If the project root where `archon` is launched is not a valid git repository (missing `.git` or no commits), the worktree creation is corrupted or partial, leading to Claude Code failing to initialize properly in that environment.

## Resolution Process

### 1. Establish Root Trust (Recursive trust)
Do NOT use `--dangerously-skip-permissions` as it does not establish permanent trust. Establish a permanent trust relationship for the Archon root directory to cover all dynamic worktrees.

- **Action**: Navigate to the Archon home directory and launch `claude` interactively.
  ```bash
  cd ~/.archon
  claude
  ```
- **Verification**: When the "Quick safety check" prompt appears, select `1. Yes, I trust this folder`.
- **Physical Proof**: Verify that a corresponding entry was created in `~/.claude/projects`.
  ```bash
  ls -la ~/.claude/projects
  ```

### 2. Ensure Valid Git Foundation
Archon requires the launch directory to be a valid git repository to correctly spawn worktrees.

- **Requirement**: The launch directory must have a `.git` folder and at least one commit (HEAD must exist).
- **Setup for Test/Isolation Environment**:
  ```bash
  cd /path/to/test-project
  git init -q
  echo '# Initial' > README.md
  git add README.md
  git commit -m 'Initial commit'
  ```

### 3. Integrated Verification
Run the workflow from the valid git root.

```bash
cd /path/to/test-project
archon workflow run <workflow-name>
```

## Pitfalls & Lessons Learned
- **The "Specific Folder" Trap**: Trusting a specific project folder (e.g., `~/.archon/worktrees/workspaces/my-project`) is insufficient because Archon creates unique sub-directories for each task. Trust the parent root `~/.archon` to ensure all future dynamic worktrees are covered.
- **Avoid Bypass Flags**: Using `--dangerously-skip-permissions` bypasses the check but does not persist trust in `~/.claude/projects`.
- **Isolation vs. Integrity**: When testing in an isolated directory, ensure that directory is first initialized as a git repository, otherwise Archon's worktree creation will be fundamentally broken.
