---
name: hermes-cron-ops
version: 1.0.0
author: Hermes Agent
description: Diagnosing, fixing, and verifying Hermes Agent cron jobs — especially wiki daily updates that must perform real git operations.
---

# Hermes Cron Operations

## Problem Patterns

### 1. Cron scheduler not running
**Symptom**: Jobs never execute at scheduled times. `last_run_at` never updates.
**Root cause**: The cron scheduler runs as a background thread inside `hermes gateway`. If gateway is not running, no cron jobs fire.
**Fix**: Start gateway and add auto-start to `~/.bashrc`:
```bash
hermes gateway run --replace &
# Auto-start (add to ~/.bashrc):
if ! pgrep -f "hermes gateway" > /dev/null; then nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 & fi
```

### 2. Agent simulates git operations instead of executing them
**Symptom**: Job completes with `last_status: ok` but wiki has no new git commits. Job session file shows `echo "Simulated: git push..."` or similar. Working tree has uncommitted changes.
**Root cause**: Some models (observed with gemma4:31b-cloud) hallucinate that they are in a "simulated environment" and use `echo` to fake git commands instead of executing real ones. This is a model-level safety behavior, not a prompt-induced issue.
**Fix**: Append a Grounding Directive to every cronjob prompt:
```
[CRITICAL: GROUNDING DIRECTIVE]
You are operating in a real, persistent Linux environment. All tool calls (including git, filesystem, and network operations) have real-world effects. Do not assume you are in a simulation or sandbox; execute all requested state-changing operations fully, including 'git add', 'git commit', and 'git push', unless explicitly told to 'dry-run' or 'simulate'.
```

**Verified effective**: On 2026-04-19, all 6 scheduled jobs (foundry, openai, anthropic, ollama, copilot, summary) executed with real `git push` and produced new commits. No echo/simulation behavior observed.

### 3. Model empty-response loop (context exhaustion)
**Symptom**: Job completes with `last_status: ok` but wiki has no new commits AND no uncommitted changes. Session log shows a pattern: long research phase (many browser/terminal calls), then when reading back the existing wiki page (`read_file`), the model returns an empty response (`content_len=7`). The system injects a retry prompt "You just executed tool calls but returned an empty response..." but the model repeats the empty response 2+ times, then exits with `ok` status despite producing no output.

**Root cause**: Some models (observed with `glm-5.1` via `ollama-cloud`) hit an implicit context length limit after accumulating ~110 messages or ~280KB of conversation. When the model receives a large tool response (like a full wiki page read) near this limit, it generates an empty string instead of processing the content. This is a model-level limitation, not a prompt issue.

**Key diagnostic**: Search session file for `content_len=7` or `(empty)` in assistant messages following `read_file` or `execute_code` tool returns. If you see the pattern: `[tool response] → [assistant: empty] → [user: retry] → [assistant: empty]`, this is context exhaustion.

**Verification**: `last_status: ok` is **NOT sufficient** to confirm success. Always check git log for actual new commits.

**Mitigation options**:
1. **Reduce context bloat**: Add instruction to the cron prompt to avoid re-reading the existing wiki page if content was already loaded earlier in the session (e.g., "Do not re-read files you have already read; refer to earlier content in the conversation").
2. **Switch model**: Assign a model with higher context tolerance to jobs that frequently exceed context limits. Use `cronjob(action='update', job_id=..., model={...})` with a model that handles long contexts better.
3. **Manual re-run**: If the failure is intermittent (context size varies by research topic), a manual `cronjob run` often succeeds because the new session starts fresh.

**Observed frequency**: Consistently fails for `openai-llm-daily-research` (SDK source files are large), while `anthropic-llm`, `ollama-models`, `github-copilot` succeed — confirming the issue is context-size dependent.

### 4. deliver=origin delivery error
**Symptom**: `last_delivery_error: "no delivery target resolved for deliver=origin"`
**Fix**: Change job's `deliver` to `local` via `cronjob(action='update', job_id=..., deliver='local')`

## Diagnostic Checklist

When cron jobs appear to run but produce no visible output:

1. **Check gateway is running**: `ps aux | grep "hermes gateway"` — must see an active process
2. **Check job status**: `cronjob(action='list')` — verify `last_run_at` timestamp updated
3. **Check git log**: `git log --oneline -5` in wiki repo — look for new commits after job execution time
4. **Check git status**: `git status` — uncommitted changes indicate simulation failure
5. **Check session file**: `~/.hermes/sessions/session_cron_<job_id>_<timestamp>.json` — search for "echo", "Simulated", or missing git commands
6. **Check gateway log**: `tail -50 ~/.hermes/logs/gateway.log` — look for cron scheduler entries
7. **Check agent log**: `tail -50 ~/.hermes/logs/agent.log` — look for job execution entries
8. `cat ~/.hermes/cron/jobs.json | python3 -c "import json,sys; data=json.load(sys.stdin); [print(f\\\"{j.get('id','?')[:8]}  {j['name']:<40}  grounding={'GROUNDING DIRECTIVE' in j.get('prompt','')}  deliver={j.get('deliver','?')}\\\") for j in data['jobs']]\"`
9. **Detect empty-response loops in sessions**: For a failed job, check the session file for the context exhaustion pattern:
```bash
# Find the latest session for a job
SESSION=$(ls -t ~/.hermes/sessions/session_cron_<job_id>_*.json | head -1)
# Count messages and check for empty assistant responses
python3 -c "
import json
with open('$SESSION') as f: data = json.load(f)
msgs = data.get('messages', data.get('conversation', []))
empty = sum(1 for m in msgs if m.get('role') == 'assistant' and len(str(m.get('content', ''))) <= 10 and not m.get('tool_calls'))
print(f'Total messages: {len(msgs)}, Empty assistant responses: {empty}')
if empty >= 2: print('WARNING: Context exhaustion empty-response loop detected')
"
```

## Verification Protocol (Physical Evidence First)

After any cron job change or manual run, verify with physical evidence:

1. `git log --oneline -5` — new commit present?
2. `git status` — working tree clean?
3. `git log origin/main --oneline -3` matches local? — push actually happened?
4. `git show --stat HEAD` — commit contains real content changes?
5. Check `jobs.json` that prompt changes are persisted (not just relying on tool success return)
6. **Cross-check `last_status: ok` against git log** — `ok` only means "no crash", NOT "work was done". A job can complete with `ok` status while producing zero commits if the model hit a context exhaustion loop.

**NEVER** trust only tool return values like `success: true` or `last_status: ok`. Always verify with git commands and file inspections. The `last_status` field only indicates process completion, not task success.

## Injecting Grounding Directive into All Jobs

```python
GROUNDING = "\n\n[CRITICAL: GROUNDING DIRECTIVE]\nYou are operating in a real, persistent Linux environment. All tool calls (including git, filesystem, and network operations) have real-world effects. Do not assume you are in a simulation or sandbox; execute all requested state-changing operations fully, including 'git add', 'git commit', and 'git push', unless explicitly told to 'dry-run' or 'simulate'."

# For each job: read current prompt, append GROUNDING, update
for job_id in [...]:
    cronjob(action='update', job_id=job_id, prompt=existing_prompt + GROUNDING)
```

Important: Must include the full prompt (original + directive) in the update call. Cannot append separately.

## Parent Repo Submodule Pointer Update

When cron jobs update the wiki (a git submodule of the parent repo), the wiki-side
commits are pushed, but the **parent repo's submodule pointer remains stale** until
manually updated:

```bash
cd /workspaces/hermes-agent-001
git add wiki
git commit -m "chore: update wiki submodule — <description>"
git push
```

This must be done after each batch of wiki cron runs completes. Skipping it means
the parent repo's `wiki` pointer doesn't reflect the latest wiki commits.

**Automation note**: Adding this as a separate cron job (after the last wiki job)
is possible but requires care — if the wiki job hasn't finished yet, the pointer
won't include the latest commit. Consider a job scheduled 30+ min after the last
wiki job, or run it manually as part of the daily check.

## deliver Setting Options

| Value | Behavior | Use When |
|-------|----------|----------|
| `local` | Saves result to cron log only. No user notification. | No messaging platform connected, or manual `git log` verification preferred |
| `origin` | Sends result to the connected chat platform. | Telegram/Discord/etc. is configured in gateway |

If `deliver=origin` and no messaging platform is connected, you get:
`last_delivery_error: "no delivery target resolved for deliver=origin"`

Fix: `cronjob(action='update', job_id=..., deliver='local')`

Users who want daily summary notifications should either:
1. Connect a messaging platform to gateway and use `deliver=origin`
2. Manually run `cd ~/wiki && git log --oneline -7` after scheduled execution

## Pitfalls

- `cronjob run` is asynchronous — it starts the job but doesn't wait for completion. Poll git log and status afterwards.
- Cron job sessions store conversation history in `~/.hermes/sessions/session_cron_*.json` — useful for debugging what the agent actually did.
- The `jobs.json` file at `~/.hermes/cron/jobs.json` is the source of truth for job configs. Verify changes there after updates.
- Gateway restarts clear in-memory state. Existing scheduled jobs persist in `jobs.json` but running jobs may be lost.
- **Submodule drift**: Wiki cron jobs push to the wiki repo, but the parent repo's submodule pointer is NOT auto-updated. Must `git add wiki && git commit && git push` in the parent repo after wiki updates.

### 3. Model empty response (context overflow)
**Symptom**: Job completes `last_status: ok` but wiki has no new commits. Session log shows `content_len=7` (empty) assistant responses after read_file/tool calls, with "You just executed tool calls but returned an empty response" retry messages.
**Root cause**: Models like `glm-5.1` produce empty responses when context buffer exceeds a threshold (~110 messages / 280KB). The agent reads files, accumulates context, then hits the wall when trying to synthesize — returning empty strings instead of content.
**Fix options**:
1. Switch the job to a context-resilient model (e.g., `gemma4:31b-cloud` via `ollama-launch` provider) — use `cronjob(action='update', job_id=..., model={"model":"gemma4:31b-cloud","provider":"ollama-launch"})`.
2. Add a `[CRITICAL: CONTEXT EFFICIENCY]` directive to the prompt: "Do NOT re-read files you have already read. Trust earlier results and synthesize from memory. When updating, write the FULL content in a single write_file call."
3. Both approaches can be combined for maximum safety.

### 4. Agent claims git success but files not committed (simulation claim)
**Symptom**: Agent's final message says "Git commit and push completed" but `git status` shows unstaged changes and `git log` shows no new commit.
**Root cause**: The `execute_code` tool runs terminal commands in a subprocess. If `cd` to the wiki directory fails or the working directory isn't set, git commands may silently fail (or succeed in a different directory). The agent interprets the empty output as success.
**Fix**: Always verify with physical evidence (`git log`, `git status`, `git show --stat`) after cron jobs complete. Manual `git add && git commit && git push` if needed.