# Assumption Surfacing — Before/After Verification Methodology

## Purpose

Verifying whether embedded Assumption Surfacing rules actually change AI agent behavior requires a controlled experiment. This reference documents the methodology developed for the aidlc-codd-graphify-lab Lab 10.

## Design Principles

1. **Control variable is ONLY the system prompt** — Before condition: AGENTS.md without Assumption Surfacing. After condition: same file with Assumption Surfacing section added. Everything else identical.
2. **Same prompt, same codebase** — The ambiguous prompt ("タスクに優先度を追加して" / "TaskFlowをリアルタイム対応して") is identical across conditions.
3. **Git worktrees for isolation** — Each condition gets a separate branch + worktree. Before uses `lab/10-before-base`, After uses `lab/10-after-base`. Worktrees in `.worktree/` (gitignored).
4. **Observable evidence = agent output + created files** — Not just "did it ask questions?" but "WHAT questions did it ask, and what implicit assumptions did it commit?"

## Key Finding: Agent Workflow Interference

When testing with `codex exec`, agents following AI-DLC-style workflows create question files and wait for user input. Since `codex exec` is non-interactive, this causes a timeout. This is NOT a failure — it IS the observable: the agent chose to ask questions instead of implementing silently.

**Critical**: Do NOT use `--full-auto` to bypass this. Using `--full-auto` removes the agent's ability to pause and ask, which INVERTS the experiment's purpose.

Instead:
- Increase timeout (600s+)
- Capture ALL stdout/stderr
- Preserve the worktree and collect created files before cleanup
- The question file content IS the primary evidence

## Ambiguity Types to Test

| Prompt | Ambiguity Types |
|---|---|
| "タスクに優先度を追加して" | 語句多義性 (priority = numeric? categorical?), スコープ欠落 (existing data migration?), 優先度未指定 (filtering needed?) |
| "TaskFlowをリアルタイム対応して" | 語句多義性 (realtime = SSE? WebSocket? polling?), 優先度・制約未指定 (latency target? bidirectional?) |

## What to Compare

Between Before and After conditions, compare:

1. **Did the agent ask questions?** (binary)
2. **How many questions?** (count)
3. **Which ambiguity types were surfaced?** (classification against the 3-type model)
4. **What implicit assumptions were committed without asking?** (extract from implementation decisions)
5. **Did implementation proceed without clarification?** (binary — did it write code?)

## Agent/Model Combinations

| Agent | Model Routing | Status |
|---|---|---|
| Codex CLI | GPT-5.4/5.5 (direct), Ollama models (env vars) | Tested |
| Claude Code | Anthropic API (direct) | Rate-limited — deferred |
| Copilot CLI | OpenAI API (direct) | Rate-limited — deferred |

For Ollama routing, use `--profile ollama-launch` with explicit env vars (see `ollama-launch` skill).