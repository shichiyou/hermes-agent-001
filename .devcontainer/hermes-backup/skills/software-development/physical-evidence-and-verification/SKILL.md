---
name: physical-evidence-and-verification
description: >
  Unified discipline for preventing AI hallucination of success and enforcing
  truth-through-tools. Covers anti-storytelling culture, physical-evidence
  gates, filesystem/Git verification protocols, ghost-completion recovery,
  and structured root-cause analysis. Use on every task involving state
  changes, completion claims, debugging, or trust disputes.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags:
      - verification
      - anti-hallucination
      - physical-evidence
      - integrity
      - debugging
      - root-cause
      - git
      - filesystem
    related_skills:
      - ai-agent-conduct
      - thinking-framework
      - systematic-debugging
---

# Physical Evidence & Verification Discipline

> **“If it’s not in the Raw Output, it didn’t happen.”**

This skill is a **class-level umbrella** for trustworthy execution. It replaces the fragmented collection of one-session verification protocols with a single, coherent discipline: **never report success without physical proof**.

## When to Use
- The user expresses distrust in a completion claim.
- Any task modifies files, Git state, configuration, or running processes.
- You need to recover from a discrepancy between your memory and `git status`.
- You are debugging an issue and want to avoid symptom-level fixes.
- You are establishing a culture of verifiable execution for a project.

---

## Part I — Core Culture: Anti-Hallucination & Anti-Storytelling

### 1. Language Rules
- Replace adjectives of success with objective statements.
  - ❌ "Successfully deleted the file."
  - ✅ "`rm` exited 0; `ls` now returns `No such file or directory`."
- Replace belief statements with evidence labels.
  - ❌ "I think the issue is X."
  - ✅ "Hypothesis: X. Evidence (pending) → [tool call] → [raw output]."

### 2. The Evidence-First Gate
**Rule**: Conclusion must NEVER precede Evidence.
- **Incorrect**: "The fix is X, so I will patch it. [Tool Call]"
- **Correct**: "[Tool Call] → [Raw Output] → 'Based on the output above, the issue is X. Therefore I will patch it.'"

### 3. The Anti-Storytelling Gate
Prohibit the construction of "success stories."
- Identify and purge phrases that imply a smooth process when evidence shows failure.
- Instead, explicitly list: `Attempt 1 (Failed) → Evidence → Analysis → Attempt 2 ...`

### 4. Map ≠ Territory Gate
Explicitly separate the Model (documentation, memory, LLM knowledge) from the Territory (current filesystem / process / git state).
- Before any `patch` or `write_file`, perform a `read_file` regardless of memory.
- State: "My internal model says X, but the physical territory shows Y. I will act on Y."

### 5. Local-vs-External Gate
When referencing both external sources AND local project state in the same answer, keep them strictly separate.
- **Incorrect**: "In this project we use deterministic gates to replace human approvals" (when `AGENTS.md` still says "Wait for approval").
- **Correct**: "External guide A says to use deterministic gates. Checking local files… [read_file] Local state shows manual gates. Therefore deterministic gates are a hypothesis, not an implemented fact."

### 6. Inversion Gate (Falsification)
A solution is not verified until a failure scenario has been attempted and refuted.
- After a fix: "How would this fail? I will now attempt to trigger that failure."

---

## Part II — Execution Protocol: Physical Evidence First

### 1. Pre-Execution Baseline
Before changing state, establish truth:
```bash
pwd
ls -la
git status --short --branch
```
Identify exactly what exists and what is missing.

### 2. Absolute Path Discipline
- Never assume root directory.
- Run `pwd` + `ls -d /workspaces/*` to disambiguate similar directories.
- Always use absolute paths in operations.

### 3. Post-Action Proof (Mandatory)
Every state-changing action must be followed by verification:
| Action | Required Follow-up |
|--------|-------------------|
| `write_file` / `patch` | `read_file` to prove exact content |
| `rm` / `rm -rf` | `ls` expecting NOT_FOUND |
| `mv` | `ls` source (missing) AND destination (exists) |
| `git add` | `git diff --cached --name-status` |
| `git commit` | `git log --oneline -1` + `git status` clean |

### 4. Compound Shell Chain Hazard (Partial Success Before Failure)
When multiple shell actions are chained in one command (`A && B && C`), a later failure does **not** undo an earlier state change.

Example class:
- `git add ... && printf ... && git commit ...`
- if `printf` or another "harmless" helper fails, `git add` may already have succeeded while `git commit` never ran.

Protocol:
1. After any chained-command failure, assume **partial execution is possible**.
2. Re-check physical state immediately (`git status --short --branch`, `git diff --cached --name-status`, `git log --oneline -1`, `ls`, etc.).
3. Resume from the verified state; do **not** blindly rerun the whole chain if that could duplicate or mis-sequence actions.
4. Prefer separating state-changing actions from decorative separators/logging helpers, or use safe forms like `printf '%s\n' '---LABEL---'` / `printf -- '---LABEL---\n'`.

Why this matters: shell helper failures can create the illusion that "nothing happened" when the index, filesystem, or process state has already changed.

### 5. Cognitive Bias Shielding
- If the user says "It's still there," assume your memory is wrong and their observation is correct.
- When verifying absence, search globally (`search_files`) — not just the suspected directory.
- Do not rely on an earlier `git status` snapshot as still true; re-run if questioned.

### 5. Git Working Tree Revalidation
When discussing uncommitted files or dirty state, run a compact cross-check:
```bash
git status --short --branch
git diff --name-status
git diff --cached --name-status
git ls-files --others --exclude-standard
git diff -- <specific-path>   # when a file is disputed
```
Describe these as the **current** state, not as proof of what existed earlier. If an earlier observation no longer reproduces, say exactly that.

---

## Part III — Recovery: Ghost Completion & Git Inconsistencies

### Trigger Conditions
- Claiming "completed" without a subsequent `read_file` or `ls`.
- `git status` reports "modified content" for a directory but lists no individual files.
- Tool output claimed success but physical state contradicts it.

### Recovery Steps
1. **Stop all forward progress.** No destructive ops until truth is known.
2. **Diagnostic probe**: `git status`, `ls -la`, check for hidden `.git` files/directories inside the flagged path.
   - If `.git` is a file, read it (may be a submodule/worktree pointer).
   - If `.git` is a remnant, confirm content files are physically present before removing it.
3. **Force alignment**: `git add <path>` specifically to force the parent repo to re-scan contents.
4. **Zero-tolerance loop**: Re-run `git status` until output is exactly `nothing to commit, working tree clean`.

### Verification Criteria
- `git status` shows a completely clean working tree.
- All requested changes are visible in `read_file` raw output.

---

## Part IV — Structured Root Cause Analysis (RCA)

Use this for systemic failures or when a symptom keeps recurring.

### Phase 1: Establish Ground Truth (Physicality)
Collect raw, objective data:
- **Filesystem**: `ls -la`, `git status`, `read_file` on affected files.
- **Processes**: `ps aux`, check zombie/orphan states.
- **Logs**: `tail -n 100 agent.log gateway.log errors.log`.
- **Result**: A "Current State" snapshot representing absolute truth.

### Phase 2: Gap Analysis (Expectation vs. Reality)
- Identify the exact point where execution diverged from the plan.
- Map symptoms: "The agent reported X, but the system shows Y."
- Develop 2–3 plausible hypotheses (env misconfig, silent crash, model hallucination).

### Phase 3: Hypothesis Testing (Scientific Method)
- Isolate: reproduce the failure in a minimal setup.
- Verify: the fix must produce a predictable, verifiable physical change.
- Document Before/After for each test.

### Phase 4: Permanent Mitigation (Structural Fix)
- Patch the underlying skill, SOP, or configuration.
- Update project wiki with the new failure mode and detection method.
- Re-run the failing case to prove the fix works.

### Final Report Template
1. **Symptom**: What went wrong
2. **Root Cause**: The technical why
3. **Physical Proof**: Log / Git / process output proving the fix
4. **Recurrence Prevention**: What was changed in the system/SOP

---

## Pitfalls to Avoid
- **Execution = Success Fallacy**: Exit code 0 does not mean the desired outcome occurred.
- **Conceptual Simulation**: Never "act" as if a tool was run. If a tool is missing, report it immediately.
- **Apology Loop**: Replace long apologies with an immediate, correct physical operation.
- **Summary Trap**: Always provide Raw Output first; never summarize complex logs into a digest that hides errors.
- **Partial Cleanup**: For submodule removal, follow the full protocol — do not use `rm -rf` alone.
- **Confirmation Bias**: Trusting a `success: true` tool response without checking the actual index.
- **Premature Deletion**: Do not delete Git metadata before verifying data (content files) is safe.
- **Context Hallucination**: Confusing previous session goals with current instructions — requires immediate reset.
- **Cognitive Arrogance**: Using meta-analysis ("I am realizing my arrogance") as a substitute for procedural rigor.

---

## Editor / Extension Configuration Triage

When a VS Code / editor / extension setting appears to be ignored, apply this sequence before attributing the problem to the extension:

1. Physically confirm the local config file contains the setting (`read_file`).
2. Check the editor's official documentation for the claimed syntax and scope.
   - Important: undocumented JSON shapes are hypotheses, not supported features.
3. Search editor issues for explicit support gaps or feature requests.
   - An open feature request is strong evidence the configuration form is unsupported.
4. Inspect the extension manifest (`package.json`) for the setting declaration and its `scope`.
5. Inspect extension runtime code to see how the setting is read (global/workspace/workspace-folder/resource).
6. Search extension issues/comments for maintainer-confirmed workarounds.

Key diagnostic rule:
- Separate `the setting key exists` from `the host editor supports that scoping syntax`.
- If the editor never maps the configuration into a valid scope, the extension cannot honor it.

See also: `references/editor-extension-config-triangulation.md` for a VS Code × Biome multi-root example.

## Quick-Reference Checklist
Before claiming completion:
- [ ] Absolute paths used for all operations?
- [ ] Verification command run AFTER the final action?
- [ ] File/state checked in ALL possible project roots?
- [ ] Raw output provided, not a belief summary?
- [ ] Git status re-run if more than a few minutes have passed?
- [ ] Failure scenario attempted and refuted (Inversion Gate)?
- [ ] User approval obtained before proceeding to next major step?

---

## Related Skills
- `ai-agent-conduct` — behavioral guardrails for agents.
- `thinking-framework` — structured problem-solving (Issue → Hypothesis → Strategy → Tactics).
- `systematic-debugging` — 4-phase debugging protocol.
- `workspace-hygiene` — preventing repository pollution.
