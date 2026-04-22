---
name: claude-code-workspace-trust
description: Resolving Claude Code Workspace Trust issues in dynamic directory environments
---

# Claude Code Workspace Trust in Dynamic Environments

## Trigger
Using AI agents (like Archon) that dynamically create git worktrees/directories and spawn Claude Code instances in non-interactive shells, leading to `claude.first_event_timeout` (approx 60s) and `Query aborted` errors.

## Root Cause
Claude Code requires a "Workspace Trust" confirmation for any directory not previously trusted. In non-interactive environments, the prompt `Quick safety check: Is this a project you created or one you trust?` is invisible, causing the process to hang until the calling agent's timeout is reached.

## Solution: Parent Directory Trust (The "Golden Path")
The most robust way to resolve this is to trust the highest possible root directory where all dynamic worktrees are created.

### Steps
1. **Identify the Root**: Determine the top-level directory managing all dynamic workspaces (e.g., for Archon, this is `~/.archon`).
2. **Interactive Trust**:
   - `cd <ROOT_DIRECTORY>`
   - Run `claude` interactively.
   - Select `1. Yes, I trust this folder`.
3. **Physical Verification**:
   - Check `ls -la ~/.claude/projects`.
   - Ensure a directory corresponding to the root exists.
4. **Inheritance Test**:
   - `mkdir -p <ROOT_DIRECTORY>/test-child`
   - `cd <ROOT_DIRECTORY>/test-child`
   - Run `echo 'exit' | claude`
   - **Success Criteria**: The command exits immediately without printing the "Quick safety check" prompt.

## Pitfalls
- **Bypassing vs. Trusting**: Using `--dangerously-skip-permissions` only bypasses the check for that specific execution; it does NOT register the directory as trusted in `~/.claude/projects`.
- **Partial Trust**: Trusting a specific worktree folder will not protect other worktrees. Always trust the common ancestor.
