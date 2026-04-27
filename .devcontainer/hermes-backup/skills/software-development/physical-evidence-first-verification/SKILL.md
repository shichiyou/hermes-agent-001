---
name: physical-evidence-first-verification
description: A rigorous verification protocol to prevent AI "hallucination of completion" and cognitive bias by mandating physical evidence over memory or assumptions.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [verification, debugging, anti-hallucination, filesystem, physical-evidence]
    related_skills: [ai-agent-conduct, thinking-framework]
---

# Physical Evidence First Verification

## Trigger
Use this skill whenever a task involves state changes in the filesystem, configuration updates, or a claim of "completion." Especially critical when the user expresses doubt about the actual state or when working in environments with multiple similar directories (e.g., `hermes-agent-lab` vs `hermes-agent-001`).

## Core Principle
**"If it's not in the Raw Output, it didn't happen."**
Memory, session history, and command execution (without checking output) are "stories," not "evidence."

## Verification Protocol

### 1. Absolute Path Validation
- **Anti-Assumption**: Never assume the root directory.
- **Action**: Run `pwd` and `ls -d /workspaces/*` to identify all existing project roots before performing any operation.
- **Constraint**: Always use absolute paths to avoid ambiguity between multiple workspace folders.

### 2. The "Post-Action" Proof
- **The Gap**: Running `rm` or `write_file` does NOT mean the task is complete.
- **Requirement**: Every state-changing action MUST be followed by a verification call that proves the result.
    - If deleting: `ls` (expecting `NOT_FOUND`).
    - If writing: `read_file` (expecting specific content).
    - If moving: `ls` source (missing) AND `ls` destination (exists).

### 3. Cognitive Bias Shielding (Anti-Storytelling)
- **Memory vs. Reality**: When a user says "It's still there," ignore your internal memory of having deleted it. Assume your memory is wrong and the user's observation is the physical evidence.
- **Global Search**: When verifying the absence of a file, do not check only the suspected directory. Use `search_files` across the entire workspace to ensure no duplicates exist in sibling directories.

## Checklist for "Completion" Claim
Before stating a task is "complete," verify:
- [ ] Did I use absolute paths for all operations?
- [ ] Did I run a verification command AFTER the final action?
- [ ] Did I check for the file/state in ALL possible project roots?
- [ ] Am I reporting the `Raw Output` of the verification, or am I summarizing my "belief"?

## Pitfalls to Avoid
- **The "Execution = Success" Fallacy**: Thinking that because a command exited with 0, the desired outcome was achieved.
- **Directory Tunnel Vision**: Only checking `/workspaces/project-a` while `/workspaces/project-b` contains the actual target.
- **Deduplication Trust**: Relying on `dedup: true` from `read_file` without occasionally performing a fresh read to ensure the file hasn't been altered externally.
- **Moment-in-Time Git Assumption**: Treating an earlier `git status` snapshot as if it were still true later. Git working tree state is time-sensitive; if a user questions your report, re-run the inspection and report only the current observed state.

## Git Working Tree Revalidation
When discussing "uncommitted files" or whether a specific file is dirty/staged/untracked, do not rely on a single prior `git status`.

### Required cross-check
Run a compact set of commands and report all of them together:

```bash
git status --short --branch
git diff --name-status
git diff --cached --name-status
git ls-files --others --exclude-standard
git diff -- <specific-path>   # when a particular file is being disputed
```

### Reporting rule
- Describe these results as the **current** state, not as proof of what existed earlier.
- If an earlier observation no longer reproduces, say exactly that: the earlier output was seen then, but is not present in the current physical evidence.
- Before committing, verify staged scope again with `git diff --cached --name-status` so you do not narrate stale file membership.
