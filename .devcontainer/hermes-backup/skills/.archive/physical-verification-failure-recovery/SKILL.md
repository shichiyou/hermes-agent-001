---
name: physical-verification-failure-recovery
description: Protocol for recovering from "Ghost Completion" and Git-indexed inconsistencies where tool outputs claim success but physical state (git status) contradicts it.
---

# Physical Verification & Recovery Protocol

## Trigger Conditions
- Claiming a task is "completed" without a subsequent `read_file` or `ls` verification.
- `git status` reporting "modified content" for a directory without listing individual files, while the agent believes it has committed everything.
- Discrepancy between AI's internal state (memory of action) and the environment's physical evidence.

## Steps for Recovery

### 1. Stop All Forward Progress
- Immediate cessation of the primary task.
- Prohibit any "destructive" operations (e.g., `rm`, `reset --hard`) until the exact nature of the inconsistency is identified.

### 2. Diagnostic Probe (The "Truth" Phase)
- Run `git status` to identify the exact scope of inconsistency.
- If a directory is marked as `modified content` without file details, check for hidden `.git` files/directories within that folder.
- Use `ls -la` to verify if `.git` is a directory (standard repo) or a file (potential submodule/worktree pointer or corruption).
- Read the content of any anomalous `.git` files to determine if they are pointers or remnants.

### 3. Truth-Based Correction
- **If .git is a remnant/file block:** Only remove it AFTER confirms that all content changes are physically present in the `.md` files themselves.
- **Forcing Index Alignment:** Use `git add <path>` specifically for the problematic directory to force the parent repository to re-scan the contents.
- **Zero-Tolerance Verification:** Loop `git status` until the output is exactly `nothing to commit, working tree clean`.

## Pitfalls
- **Confirmation Bias:** Trusting the `exit_code: 0` of a `git commit` without checking if the index actually captured the changes.
- **Premature Deletion:** Attempting to "fix" a Git status by deleting metadata before verifying the data (content files) is safe.
- **Context Hallucination:** Confusing previous session goals with current instructions (requires immediate reset and apology).

## Verification Criteria
- `git status` must show a completely clean working tree.
- All specific changes requested must be visible in the raw output of `read_file`.
