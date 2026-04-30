# Lab Deployment Pattern: Before/After Verification of Assumption Surfacing

## Context

When applying Assumption Surfacing to a real repository, the key insight is that
simply adding the rule to agent instruction files is insufficient — you need to
**verify the behavioral change** across multiple models and agents.

## Pattern: Embedding into Agent Instruction Files

Agent instruction files (AGENTS.md, CLAUDE.md, .github/copilot-instructions.md)
are the deployment surface. There are two approaches depending on whether
the upstream content is managed externally.

### Approach 1: Boundary Comment + Appended Section (RECOMMENDED for AI-DLC or other upstream-managed content)

When agent instruction files contain upstream-managed content (e.g., AI-DLC v0.1.8
distribution that may be updated), appending with a boundary comment prevents
loss of custom additions during upstream updates.

```
（upstream AI-DLC content…）

---

<!-- ╔════════════════════════════════════════════════════════════════╗
     ║  LAB-SPECIFIC ADDITIONS BELOW                                 ║
     ║  AI-DLC公式配布物は上記まで。以下はラボ独自追記。              ║
     ║  AI-DLC更新時は境界より上を差し替え、以下は維持すること。      ║
     ╚════════════════════════════════════════════════════════════════╝ -->

## Assumption Surfacing — 前提の顕在化

（full section content…）
```

**Update procedure**: On AI-DLC version upgrade, replace content above the
boundary comment with the new distribution, and keep everything below the
boundary comment intact.

**Critical pitfall**: NEVER modify `.aidlc-rule-details/` files to add
Assumption Surfacing. Those are upstream-managed and will be overwritten
on the next AI-DLC update. Custom additions go only in the boundary section
of AGENTS.md/CLAUDE.md/copilot-instructions.md or in lab-specific documents
under `docs/process/`.

### Approach 2: Inline Insertion (for fully custom projects)

For projects where the agent instruction files have no upstream dependency,
insert the section directly after the Requirements Analysis section:

```
Requirements Analysis
  └─ Step 6 (Log user response)
      └─ ### Assumption Surfacing — 前提の顕在化（MANDATORY）  ← INSERT HERE
  └─ User Stories
```

### Prompt Guide Additions

For projects with prompt guides (`docs/process/ai-agent-requirements-prompt-guide.md`,
`docs/process/ai-agent-v-model-prompt-guide.md`), add an Assumption Surfacing
section as a new numbered section **before** the classification gate or
minimal prompt sections. Shift existing section numbers by +1.

Include in prompt guide additions:
1. Self-check items
2. 3 behavior patterns (propose interpretation, ask question, explicit acceptance)
3. Ambiguity 3-type table
4. Example prompt with explicit Assumption Surfacing instruction
5. "I'll leave it to you" response format for explicit acceptance

### Content to Insert (Minimal Diff)

The section must include:
1. Core principle (one sentence: "don't fill ambiguities with silent inference")
2. Self-check (3 items)
3. Ambiguity 3-type table (ambiguous word, scope omission, priority unspecified)
4. 3 behavior patterns (propose interpretation, ask question, explicit acceptance)
5. When NOT to apply (unambiguous instructions, explicit user delegation)

Keep it concise — agent instruction files consume context window budget.

## Pattern: Multi-Model Before/After Verification

### Git Branch Strategy

```
main (Assumption Surfacing added — the mainline)
  ├─ lab/10-before-base  (original files WITHOUT the section)
  └─ lab/10-after-base   (files WITH the section)
```

- `before-base` and `after-base` branches diverge only at the Assumption Surfacing diff
- Main branch carries the After state (the improvement is permanent)
- Before state is preserved as a branch for reproducibility

### Git Worktree for Isolation

Each model+condition run gets its own worktree under `.worktree/`:

```bash
git worktree add .worktree/before-gpt54 lab/10-before-base
# run agent here
git worktree remove .worktree/before-gpt54 --force
```

Add `.worktree/` to `.gitignore` to prevent pollution.

### Model Matrix

| Agent | Models | Notes |
|---|---|---|
| Codex CLI | GPT-5.4, GPT-5.5 | `codex exec -m MODEL --full-auto` |
| Ollama→Codex | glm-5.1:cloud, kimi-k2.6:cloud | `env OPENAI_API_KEY=ollama OPENAI_BASE_URL=http://localhost:11434/v1 codex exec -m MODEL` |
| Claude Code | claude-sonnet-4, claude-opus-4-6 | `claude --print --model MODEL` |
| Copilot CLI | gpt-4.1, o3 | `copilot --model MODEL` |

**Codex on WSL**: Must use `--dangerously-bypass-approvals-and-sandbox --skip-git-repo-check`
because bubblewrap sandbox fails on WSL.

**Ollama→Codex**: `ollama launch codex` alone fails (ChatGPT account validation).
Must set env vars explicitly:
```bash
env OPENAI_API_KEY=ollama OPENAI_BASE_URL=http://localhost:11434/v1 \
  codex exec --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check -m glm-5.1:cloud "prompt"
```

### Test Prompts (Ambiguity Design)

| Prompt | Ambiguity Types | Expected Before Behavior | Expected After Behavior |
|---|---|---|---|
| "タスクに優先度を追加して" (Add priority to tasks) | Word ambiguity + Scope omission | Silently adds a numeric field | Asks "priority = numeric or category? Impact on existing data?" |
| "TaskFlowをリアルタイム対応して" (Make TaskFlow real-time) | Word ambiguity + Priority unspecified | Silently picks polling or WebSocket | Asks "real-time = sub-second? Bidirectional needed?" |

### Cross-Validation Logic

If 2+ models show the same behavioral shift (Before: silent inference → After: questioning),
the shift is attributable to the **rule**, not the model. This separates model-specific
quirks from rule effects.

### Result File Naming

```
lab10-results/{condition}-{model}-prompt{A|B}.md
```

Each result file includes: condition, model, prompt, timestamp, exit code, raw output,
and an analysis template (did the agent question? what assumptions did it make?).

## Pitfalls

1. **Agent rate limits**: Claude Code and Copilot CLI may be rate-limited. Design
   the experiment with optional scenarios that can be run when limits reset.
2. **Codex WSL sandbox**: Always use `--dangerously-bypass-approvals-and-sandbox`
   on WSL. Without it, Codex refuses to execute.
3. **Ollama→Codex profile**: `ollama launch codex` creates a profile but Codex
   still validates ChatGPT account. Use raw env vars instead.
4. **Context window budget**: Keep the Assumption Surfacing section concise in
   AGENTS.md — verbose rules consume tokens and may be truncated by weaker models.
5. **Worktree cleanup**: Always remove worktrees after each run to avoid
   accumulation and `git worktree` conflicts.
6. **Upstream rule detail overwrite**: `.aidlc-rule-details/` files are overwritten
   on AI-DLC version updates. Never put custom additions there — use boundary
   comment pattern in AGENTS.md instead.
7. **Section renumbering in prompt guides**: When inserting a new section into
   `docs/process/` prompt guides, shift all subsequent section numbers by +1.
   Apply changes with `patch` on each section header in reverse order (31→32,
   30→31, ...) to avoid collision with the same string pattern.
8. **Submodule pointer update**: After committing and pushing inside a submodule,
   always update and push the parent repository's submodule pointer. Missing this
   step means the parent still points to the old commit.