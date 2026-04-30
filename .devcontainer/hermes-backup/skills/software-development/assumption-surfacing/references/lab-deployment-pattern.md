# Lab Deployment Pattern: Before/After Verification of Assumption Surfacing

## Context

When applying Assumption Surfacing to a real repository, the key insight is that
simply adding the rule to agent instruction files is insufficient — you need to
**verify the behavioral change** across multiple models and agents.

## Pattern: Embedding into Agent Instruction Files

Agent instruction files (AGENTS.md, CLAUDE.md, .github/copilot-instructions.md)
are the deployment surface. Insert the Assumption Surfacing section into the
Requirements Analysis section of each file — this is where the self-check
naturally triggers.

### Insertion Point

```
Requirements Analysis
  └─ Step 6 (Log user response)
      └─ ### Assumption Surfacing — 前提の顕在化（MANDATORY）  ← INSERT HERE
  └─ User Stories
```

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