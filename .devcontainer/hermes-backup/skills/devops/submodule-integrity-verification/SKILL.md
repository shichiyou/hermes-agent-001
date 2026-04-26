---
name: submodule-integrity-verification
description: Rigorous protocol for managing and verifying Git submodules, specifically focused on avoiding detached HEAD states and ensuring alignment with remote tracking branches.
---

# Submodule Integrity Verification Protocol

## Trigger
Use this skill whenever modifying files within a Git submodule, especially when the agent is operating in a detached HEAD state or when `git status` reports `modified content` for a submodule directory.

## Core Philosophy
A submodule is not just a directory; it is a pointer to a specific commit in another repository. Verification is only complete when the pointer in the parent repository aligns with a named branch (e.g., `main`) in the submodule repository.

## Detailed Workflow

### 1. Physical State Audit (The "No-Assume" Phase)
Before any commit or merge, execute these three checks:
- **Parent perspective**: `git status` (Check if the submodule is marked as modified).
- **Submodule perspective**: `cd <submodule> && git status` (Check if it is on a branch or `detached HEAD`).
- **Remote perspective**: `cd <submodule> && git fetch origin && git log --oneline --graph --all` (Identify if the local state has diverged from `origin/main`).

### 2. The "Clean Alignment" Procedure
If the submodule is in a `detached HEAD` state or diverged from remote:
1. **Backup Local Work**: Identify the commit hash of the local changes (e.g., `617e9a4`).
2. **Hard Reset to Remote**: `git checkout main && git reset --hard origin/main`. This eliminates the "diverged" state and establishes a known-good baseline.
3. **Surgical Re-application**: `git cherry-pick <local-commit-hash>`.
4. **Conflict Resolution**: If conflicts occur, manually inspect the file using `read_file`, resolve based on the latest remote logic, and `git cherry-pick --continue`.
5. **Branch Validation**: Verify the current state is `* main` and not `detached HEAD`.

### 3. Parent-Submodule Synchronization
Once the submodule internal state is a clean linear progression of `origin/main`:
- `cd ..`
- `git add <submodule-dir>`
- `git commit -m "chore: update <submodule> reference to latest main"`

### 4. Converting an Existing Tracked Directory into a Submodule
When replacing an already-tracked normal directory with a submodule at the same path, do not assume `git rm -r <path>` removes the physical directory. It removes tracked files, but ignored or previously untracked generated artifacts can remain and cause `git submodule add <url> <path>` to fail with:

```text
fatal: '<path>' already exists and is not a valid git repo
```

Safe procedure:
1. Preserve the directory content first by copying it outside the parent repository, e.g. `~/workspace/repos/<repo-name>`.
2. Initialize and push the independent repository from that copy. Verify `HEAD == origin/main` before touching the parent pointer.
3. In the parent repository, run `git rm -r <path>`.
4. Before deleting the leftover physical directory, inspect it:
   - `find <path> -maxdepth 4 -type f | sort | sed -n '1,200p'`
   - `git ls-files --others --exclude-standard <path> | sort`
   - `git status --ignored --short <path> | sed -n '1,160p'`
5. If the remaining files are only disposable/generated artifacts already excluded from the independent repository (for example `.venv/`, `.aidlc/`, `__pycache__/`, `.pytest_cache/`, tool scan caches), remove the physical directory: `rm -rf <path>`.
6. Run `git submodule add <url> <path>`.
7. Verify the parent index has mode `160000` for `<path>` and `.gitmodules` points to the same URL as the submodule's internal `origin`.
8. Commit and push the parent, then verify `git clone` + `git submodule update --init --recursive` in a clean temporary directory.

Important distinction: a clean `git submodule update --init --recursive` checkout normally leaves submodules in `HEAD (no branch)` detached state. That is acceptable for reproducible checkout if the checked-out commit equals `origin/main`. For active development inside the submodule, explicitly `git checkout main && git pull --ff-only`.

## Pitfalls & Anti-Patterns
- **The "Status Illusion"**: Thinking `git add .` in the parent repository saves submodule content. (It only saves the commit hash pointer).
- **The "Detached Commit"**: Committing while in `detached HEAD`. This creates a "ghost commit" that is lost if the branch is switched without a merge.
- **The "Formal Plan Trap"**: Presenting a plan to the user as a substitute for actual physical exploration. Always execute the "Audit" phase before presenting the "Execution" plan.

## Verification Criteria
- `cd <submodule> && git branch` $\rightarrow$ Must show `* main`.
- `cd <submodule> && git log` $\rightarrow$ Must show a linear path from `origin/main` to the latest local commit.
- Parent `git status` $\rightarrow$ Must be `working tree clean`.
