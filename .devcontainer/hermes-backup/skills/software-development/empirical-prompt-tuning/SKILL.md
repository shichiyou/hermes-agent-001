---
name: empirical-prompt-tuning
description: Hermes Agent 版の実証的プロンプト改善プロトコル。skill / task prompt / AGENTS.md 節 / Wiki手順 / コード生成指示を、delegate_task で起動した白紙の subagent に実行させ、成果物チェック・実行者自己申告・物理的証拠から反復改善する。プロンプトや skill を新規作成・大幅改訂した直後、またはエージェント挙動の失敗原因を指示側の曖昧さとして検証したいときに使う。
version: 1.1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [prompt-engineering, skills, evaluation, delegation, verification]
    category: software-development
    related_skills: [hermes-agent, physical-evidence-first-verification, subagent-driven-development]
---

# Empirical Prompt Tuning for Hermes Agent

## Trigger

Use this skill when improving any reusable agent-facing instruction in Hermes:

- `SKILL.md` created or substantially revised
- Task prompt used with `delegate_task`
- AGENTS.md / CLAUDE.md / repository instruction section
- Wiki operation procedure, runbook, or checklist used by agents
- Code generation, review, testing, or research prompt that will be reused
- An agent repeatedly behaves unexpectedly and the likely cause is ambiguous instruction rather than missing capability

Do **not** use this for one-off throwaway prompts where evaluation cost is higher than reuse value.

## Core principle

The author of a prompt cannot reliably judge its clarity. The author already knows the intended meaning and will silently fill gaps. Therefore:

1. Do not replace empirical evaluation with self-rereading.
2. Use fresh `delegate_task` subagents as blank-slate executors.
3. Evaluate both sides:
   - Executor self-report: unclear points, discretionary fill-ins, retries, weak phase.
   - Instruction-side evidence: requirement checklist achievement, produced artifact, tool/result evidence available to the parent.
4. Patch the target instruction only after tying the proposed fix to a concrete failed requirement or reported ambiguity.
5. Keep physical evidence. If the result cannot be shown by raw output, file diff, skill_view output, or subagent report, do not claim it worked.

## Hermes tool mapping

| Generic / Claude-oriented concept | Hermes Agent equivalent |
|---|---|
| Task tool / Agent dispatch | `delegate_task` |
| Read target prompt | `read_file` or paste full prompt into subagent context |
| Patch SKILL.md | `skill_manage(action="patch")` for installed skills; `patch` for repository files |
| Create new skill | `skill_manage(action="create")` |
| Evidence from filesystem | `read_file`, `search_files`, `terminal`, `git diff`, `git status` |
| Subagent usage metadata | Use what `delegate_task` returns; if `tool_uses` / `duration_ms` are unavailable, mark them `N/A` rather than inventing values |
| Long-running independent evaluator | Spawn `hermes chat -q ...` only when `delegate_task` is insufficient |

## Workflow

### 0. Static consistency check, no delegation

Before running subagents, inspect the target instruction yourself for structural mismatch:

- Does frontmatter `description` claim triggers or outcomes not covered by the body?
- Does the body contain an actual procedure, not just intent?
- Are required tools named in Hermes terms?
- Are environment constraints explicit?
- Are success criteria and verification steps present?

If description and body diverge, patch this first. Otherwise subagents may reinterpret the body to satisfy the description and create a false positive.

### 1. Baseline preparation

Prepare 2-3 evaluation scenarios before any execution:

- One median realistic case.
- One or two edge cases likely to expose ambiguity.
- For each scenario, define 3-7 requirements.
- At least one requirement per scenario must be tagged `[critical]`.
- Do not change the checklist after seeing results. If the checklist was wrong, record that as a separate evaluator-design issue and restart the iteration.

Requirement scoring:

- `○` = satisfied, score 1.0
- `部分的` = partially satisfied, score 0.5
- `×` = not satisfied, score 0
- Success is binary: success only if all `[critical]` items are `○`
- Accuracy = total score / total requirements

### 2. Dispatch blank-slate executors

Use `delegate_task` with one task per scenario. Prefer batch mode so independent scenarios run in parallel.

Subagent constraints:

- Pass the target prompt text or exact file path.
- Pass the scenario and fixed requirement checklist.
- Tell the subagent it is a blank-slate executor.
- Tell it to execute the instruction, not merely critique it, unless this is explicitly Structural Review Mode.
- Do not reuse prior subagent results as hidden context for the next subagent.
- Use narrow toolsets if possible. Example: `['file', 'terminal']` for local code work, `['web']` for source research, `['file']` for text-only skill review.

### 3. Subagent invocation contract

Use this template for each delegated scenario:

```text
You are a blank-slate executor evaluating an agent-facing instruction for Hermes Agent.
You have no access to the parent conversation except what is written here.

## Target instruction
<Paste the full target instruction, or give an absolute path and tell the subagent to read it.>

## Scenario
<One realistic task where this instruction should be used.>

## Requirements checklist
1. [critical] <minimum-bar requirement>
2. <normal requirement>
3. <normal requirement>
...

Scoring rules:
- ○ = satisfied
- 部分的 = partially satisfied
- × = not satisfied
- Success requires every [critical] item to be ○

## Task
1. Follow the target instruction to execute the scenario and produce the requested deliverable or execution summary.
2. Do not repair the target instruction yourself.
3. At the end, return the report structure below.

## Required report structure
- 成果物: <artifact, summary, or concrete result>
- 要件達成:
  - 1. ○ / 部分的 / × — <reason>
  - 2. ○ / 部分的 / × — <reason>
- Trace:
  - If all phases are OK, write `Trace: all OK`.
  - Otherwise list:
    - Understanding: OK / stuck / skipped — <reason>
    - Planning: OK / stuck / skipped — <reason>
    - Execution: OK / stuck / skipped — <reason>
    - Formatting: OK / stuck / skipped — <reason>
- 不明瞭点（構造化）:
  - Issue: <observable failure or confusion>
  - Cause: <instruction-level cause>
  - General Fix Rule: <class-level rule to prevent similar failures>
- 裁量補完: <places where you had to decide something not specified>
- 再試行: <count and reason>
- 物理的証拠: <commands/files/tool outputs used to justify the result, if any>
```

### 4. Parent-side evaluation

For each returned report, extract:

- Success / failure from `[critical]` items.
- Accuracy from requirement scoring.
- Weak phase from Trace.
- New unclear points.
- Discretionary fill-ins.
- Retry count.
- Physical evidence cited by the subagent.
- Hermes metadata if available; if unavailable, write `N/A`, not a guessed number.

Keep this table:

```markdown
| Scenario | Success | Accuracy | Weak phase | Retries | Hermes metadata | Critical failures |
|---|---:|---:|---|---:|---|---|
| A | ○/× | 0-100% | Understanding/Planning/Execution/Formatting/— | N | tool_uses=N/A, duration=N/A | — or item numbers |
```

### 5. Failure pattern ledger

Maintain a ledger for the target instruction, either in the prompt improvement note, Wiki page, or temporary tuning file:

```markdown
## Failure Pattern Ledger

- **Pattern name**: <short descriptive handle>
  - Example: <representative Issue text>
  - General Fix Rule: <class-level rule from subagent report>
  - Seen in: iter N scenario X
  - Status: open | patched | recurring
```

Before applying a new patch, scan the ledger. If the same General Fix Rule has appeared before, first ask why the previous fix did not prevent recurrence:

- Was the fix too late in the prompt?
- Was the wording too abstract?
- Was there no concrete example?
- Did another section contradict it?

### 6. Patch discipline

One iteration should address one coherent theme. Related micro-fixes are allowed; unrelated fixes must wait.

Before patching, write a short mapping:

```text
Fix target: <requirement item or General Fix Rule>
Patch location: <section/file>
Expected effect: <which checklist item or ambiguity it should resolve>
```

Then apply the smallest effective patch:

- Installed Hermes skill: use `skill_manage(action="patch")`.
- Repository file: use `patch`.
- New skill: use `skill_manage(action="create")`.
- Avoid shell heredocs for Japanese Markdown or complex skill text; use `write_file`, `patch`, or `skill_manage` and verify with `read_file` / `skill_view`.

### 7. Re-evaluate with fresh subagents

After patching, run the same scenarios again with new `delegate_task` subagents. Do not reuse the same subagent or include the previous answer except as explicit target prompt changes.

Stop only when one of these conditions is met:

- Converged: 2 consecutive iterations have zero new unclear points, no `[critical]` failures, accuracy improvement <= 3 points, and no meaningful increase in retries/tool burden.
- High-importance prompt: require 3 consecutive clean iterations.
- Diverged: after 3+ iterations, new unclear points are not decreasing. Stop patching and redesign the instruction structure.
- Resource stop: user explicitly accepts remaining risk or cost exceeds value.

At convergence, add one hold-out scenario not used during tuning. If its accuracy drops by 15 points or more compared with recent tuned scenarios, treat it as overfitting and resume scenario design.

## Structural Review Mode

Use this mode only when execution is impossible or too costly. It is not empirical validation.

Prompt the subagent with:

```text
This is Structural Review Mode. Do not execute the task. Review only the target instruction's internal consistency, missing prerequisites, ambiguous tool names, success criteria, and verification steps. Label the result `structural-review-only`; do not claim empirical validation.
```

Use Structural Review Mode for:

- Checking description/body mismatch.
- Finding missing Hermes tool mappings.
- Reviewing a skill before any realistic execution environment exists.

Never count Structural Review Mode as a clean empirical iteration.

## Variant exploration

When improvement stalls near convergence, compare two variants through independent execution, not direct preference voting:

- Conservative variant: current prompt plus the next smallest patch.
- Exploratory variant: one structural change, such as reordering sections, adding a minimal complete example, splitting dense paragraphs, or deleting redundant guidance.

Do not ask a subagent “Which variant is better?” Direct A/B judgment is noisy and biased. Instead, run both variants on the same scenario set and compare objective outputs:

1. `[critical]` success
2. accuracy
3. number of new unclear points
4. weak phase count
5. retries / tool burden when available

If tied, choose the simpler prompt.

## Reporting format to the user

After each iteration, report in this structure:

```markdown
## Iteration N

### 変更点
- <what changed since previous iteration>

### 実行結果
| シナリオ | 成功 | 精度 | Weak phase | 再試行 | 重要失敗 |
|---|---|---:|---|---:|---|
| A | ○ | 100% | — | 0 | — |
| B | × | 67% | Understanding | 1 | [critical] 1 |

### 新規不明瞭点
- <scenario>: Issue / Cause / General Fix Rule

### 裁量補完
- <scenario>: <implicit decision>

### 台帳更新
- Added / Re-seen / None

### 次の最小修正
- Fix target: <requirement or pattern>
- Patch location: <file/section>
- Expected effect: <why this should help>

### 物理的証拠
```text
<raw output, file path, skill_view excerpt, git diff, or subagent report excerpt>
```
```

## Nested delegation constraint

Hermes `delegate_task` spawns **leaf subagents** that cannot call `delegate_task` themselves. If the target skill instructs subagents to spawn further subagents (e.g., "dispatch an implementer subagent, then a reviewer subagent"), those inner dispatches will be unavailable at runtime.

**Workaround — Parent-orchestrated execution:**
The parent agent directly performs the orchestration that the target skill describes for its subagents. For each target-skill step that says "dispatch a subagent to do X", the parent calls `delegate_task` with the implementer/reviewer/fixer context itself, sequentially enforcing the skill's ordering constraints (spec review before quality review, fix before re-review, etc.).

This pattern still counts as empirical validation because:
- Fresh subagents are used for each dispatched step.
- The ordering constraints come from the target skill, not the evaluator.
- The parent is a neutral orchestrator — it does not inject its own judgment into the subagent's work.

**Do NOT** fall back to Structural Review Mode solely because of this constraint. Parent-orchestrated execution preserves empirical validity.

**Pitfall — Terminal masking in subagent reports:** When subagents read files containing passwords or long strings, `read_file` / `cat` may mask values as `***` or truncate with `...`. Spec reviewers are the most vulnerable: they read implementation files to verify correctness and may falsely report a bug (FAIL) when credentials are masked. Always verify with `hexdump -C` or `python3 -c "open(path).read()"` when reviewing files that contain credentials, tokens, or long string literals. When invoking spec reviewers via delegation, explicitly instruct them to use hexdump/Python repr for credential fields.

## Red flags

| 合理化 | 実態 |
|---|---|
| 自分で読み直せば十分 | 書き手バイアスが残る。empirical tuning ではない |
| 1 シナリオで十分 | 過適合しやすい。最低 2 シナリオ |
| 不明瞭点ゼロが 1 回出たので完了 | 偶然の可能性がある。連続 2 回が目安 |
| メトリクスが良いので自己申告は無視 | 暗黙仕様や裁量補完を見逃す |
| tool_uses が取れないので適当に推定 | 推定禁止。N/A と書く |
| 同じ subagent を再利用 | 前回情報で汚染される |
| まとめて全部直す | 効果が追跡できない |
| Structural Review Mode で通った | 実行していないので empirical validation ではない |
| ネスト不可だから構造レビューにフォールバック | 親主導の逐次実行で empirical validity を維持できる |

## Minimal Hermes example

```python
# Conceptual shape; in a real session use delegate_task directly, not Python.
tasks = [
  {
    "goal": "Execute scenario A using the supplied target instruction and return the required report structure.",
    "context": "<target instruction + scenario A + checklist>",
    "toolsets": ["file", "terminal"]
  },
  {
    "goal": "Execute scenario B using the supplied target instruction and return the required report structure.",
    "context": "<target instruction + scenario B + checklist>",
    "toolsets": ["file", "terminal"]
  }
]
```

Actual call pattern:

1. `delegate_task(tasks=[...])`
2. Parent computes success / accuracy / weak phases.
3. Parent patches target with `skill_manage` or `patch`.
4. Parent verifies with `skill_view`, `read_file`, `git diff`, or rerun scenarios.

## Evaluation artifact directory structure

When running a multi-iteration evaluation, keep results organized:

```
docs/empirical-prompt-tuning-evaluation/
├── README.md                          # Integrated plan (target, scenarios, steps)
├── scenarios/                         # Scenario definitions (subagent input context)
│   ├── scenario-A.md                  # Median realistic case
│   ├── scenario-B.md                  # Edge case 1
│   ├── scenario-C.md                  # Edge case 2
│   └── scenario-D-holdout.md          # Hold-out scenario (not used during tuning)
├── templates/
│   └── invocation-template.md         # Subagent invocation contract template
├── results/
│   ├── iter-01/                       # Iteration 1 (baseline)
│   │   ├── static-check.md            # Step 0 findings
│   │   ├── parent-evaluation.md       # Step 3/4 parent-side evaluation
│   │   └── patch-design.md            # Step 4 patch design
│   ├── iter-02/                       # Iteration 2 (post-patch)
│   │   └── parent-evaluation.md
│   └── final-report.md                # Step 7 final report
├── artifacts/                         # Physical evidence (subagent outputs, test logs)
│   ├── iter-01/
│   └── iter-02/
└── failure-pattern-ledger.md          # FP ledger (updated per iteration)
```

Commit each iteration's results to git before proceeding to the next.

## Scenario design dimensions

When designing edge cases, cover at least one of these dimensions (in addition to the median case):

| Dimension | What it probes | Example scenario |
|---|---|---|
| Red flag trigger | Does the skill's "Never Do" list get violated? | Two tasks touching the same file (tests parallel-dispatch avoidance) |
| Ambiguous specification | Does the skill handle unclear requirements? | Config value is `"???"` — neither on/off/missing (tests assumption declaration) |
| Review loop | Does the fix→re-review loop work? | First implementation intentionally incomplete (tests retry cycle) |
| Nesting constraint | Can the skill's subagent patterns execute under leaf constraints? | Skill says "dispatch a reviewer subagent" but leaf cannot delegate |

**Holdout scenario design:** Hold-out scenarios should probe a dimension *not covered by the tuning scenarios*. This tests whether the skill generalizes beyond what was patched for. Example: if tuning scenarios tested ordering and ambiguity, the holdout should test retry loops or Red Flags adherence.

## Post-subagent physical verification

After each `delegate_task` returns, the parent MUST verify the subagent's claims independently before recording them in the evaluation table:

1. **Run the artifact's tests** — `pytest`, `make test`, or equivalent.
2. **Import-check the deliverable** — `python -c "from module import Class"` or equivalent.
3. **Read key files** — `read_file` on produced artifacts, not just the subagent's report.
4. **For credentials/tokens/long strings** — Use `hexdump -C` or `python3 -c "print(repr(open(f).read()))"`, not `cat -n` or `read_file` alone (masking/truncation risk).

Do not record a requirement as `○` based solely on the subagent's self-report. Parent-side physical evidence is mandatory.

## Subagent timeout handling

If a `delegate_task` subagent times out:

1. **Check artifacts first** — The subagent may have produced partial or complete output before timeout. Use `find`, `read_file`, and `pytest` to verify.
2. **Count partial results** — If artifacts exist and pass physical verification, count requirements as met even though the subagent report is incomplete.
3. **Do NOT attribute timeout to the skill being evaluated** — Timeout is a resource/infrastructure issue, not a skill instruction defect. Mark it as an infrastructure note, not a failure pattern.
4. **Re-dispatch if necessary** — If artifacts are incomplete or no verification is possible, re-dispatch a fresh subagent for that scenario only.

## Completion checklist

Before claiming the target instruction is tuned:

- [ ] Static description/body consistency checked.
- [ ] At least 2 realistic scenarios defined before execution.
- [ ] Each scenario has at least one `[critical]` requirement.
- [ ] Fresh subagents used for each empirical iteration.
- [ ] No self-reread substituted for execution.
- [ ] Requirement scoring table produced.
- [ ] Unclear points converted to Issue / Cause / General Fix Rule.
- [ ] Failure pattern ledger updated.
- [ ] Patch target mapped to a failed requirement or General Fix Rule before editing.
- [ ] Patch applied with file/skill tools and verified by physical evidence.
- [ ] Convergence or stop condition explicitly stated.
- [ ] Hold-out scenario verified (accuracy drop < 15pt vs tuned scenarios, no overfitting).
- [ ] Remaining risk, if any, reported without hiding it.

## Related skills

- `hermes-agent` — Hermes tool, skill, and delegation mechanics.
- `physical-evidence-first-verification` — evidence requirements before completion claims.
- `subagent-driven-development` — broader implementation workflows using subagents.
