---
name: prompt-evaluation-and-tuning
description: >
  Evaluate and improve agent-facing prompts systematically. Covers empirical
  validation via blank-slate subagents, iterative patching with physical evidence,
  and promptfoo CI pipeline configuration for regression testing.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags:
      - prompt-engineering
      - prompt-evaluation
      - promptfoo
      - subagent-validation
      - ci-cd
      - regression-testing
    related_skills:
      - hermes-agent
      - physical-evidence-and-verification
      - subagent-driven-development
      - workspace-hygiene-and-git-discipline
---

# Prompt Evaluation & Tuning

> **“The author of a prompt cannot reliably judge its clarity.”**

This umbrella unifies two complementary approaches to prompt quality:
1. **Empirical Subagent Validation** — run the prompt against blank-slate subagents on realistic tasks, measure requirement achievement, and iterate.
2. **Declarative CI Regression** — set up a `promptfoo` pipeline that evaluates prompt behavior automatically against a matrix of tests.

Use this skill whenever you create, revise, or debug a reusable agent instruction (`SKILL.md`, task prompt, `AGENTS.md` section, Wiki procedure, or code-generation directive).

---

## Part I — Empirical Subagent Validation

### Core Principle
A prompt author already knows the intended meaning and will silently fill gaps. Fresh `delegate_task` subagents are the only reliable judges. Replace self-rereading with structured execution.

### When to Use
- New or substantially revised `SKILL.md`
- Task prompt used with `delegate_task`
- `AGENTS.md` / `CLAUDE.md` section
- Agent repeatedly behaves unexpectedly and the root cause is ambiguous instruction

### Workflow

#### 0. Static Consistency Check
Before running subagents, inspect:
- Frontmatter `description` matches body intent.
- Body contains an actual procedure, not just intent.
- Required tools are named in Hermes terms.
- Environment constraints are explicit.
- Success criteria and verification steps exist.

#### 1. Scenario Design
Define 2–3 scenarios before execution:
- One median realistic case.
- One or two edge cases exposing ambiguity.
- 3–7 requirements per scenario; at least one tagged `[critical]`.

**Scoring**:
- `○` = satisfied (1.0)
- `部分的` = partially (0.5)
- `×` = not satisfied (0)
- **Binary success**: all `[critical]` items must be `○`.
- Accuracy = total score / total requirements.

#### 2. Dispatch Blank-Slate Executors
Use `delegate_task` in batch mode, one task per scenario.

**Subagent constraints**:
- Pass full target prompt + scenario + checklist.
- Tell the subagent it is a blank-slate executor.
- Do not reuse prior subagent results as hidden context.
- Use narrow toolsets.

**Invocation contract skeleton**:
```
You are a blank-slate executor evaluating an agent-facing instruction.
Target instruction:
<paste full instruction>

Scenario: ...
Requirements checklist:
1. [critical] ...
...

Task:
1. Follow the instruction to execute the scenario and produce the deliverable.
2. Do not repair the instruction yourself.
3. Return:
   - 成果物
   - 要件達成 (○/部分的/× per item)
   - Trace (Understanding/Planning/Execution/Formatting)
   - 不明瞭点 (Issue / Cause / General Fix Rule)
   - 物理的証拠
```

#### 3. Parent-Side Evaluation
Extract per scenario:
- Success/failure on `[critical]` items.
- Accuracy.
- Weak phase from Trace.
- New unclear points.
- Discretionary fill-ins (where subagent decided something not specified).
- Retry count.
- Physical evidence (commands/files/tool outputs).

Maintain a running table:
| Scenario | Success | Accuracy | Weak phase | Retries | Critical failures |

#### 4. Failure Pattern Ledger
Keep a ledger:
```markdown
## Failure Pattern Ledger
- **Pattern name**: ...
  - Example: ...
  - General Fix Rule: ...
  - Seen in: iter N scenario X
  - Status: open | patched | recurring
```
Before applying a patch, ask why a previous fix recurred (too late in prompt? too abstract? no example? contradictory section?).

#### 5. Patch Discipline
One iteration = one coherent theme. Before patching, write:
```text
Fix target: <requirement or pattern>
Patch location: <section/file>
Expected effect: <which checklist/ambiguity it resolves>
```
Then apply the smallest effective patch.

#### 6. Re-evaluate with Fresh Subagents
After patching, rerun the same scenarios with **new** `delegate_task` subagents. Do not reuse the same subagent.

**Stop conditions**:
- **Converged**: 2 consecutive iterations with zero new unclear points, no `[critical]` failures, accuracy improvement ≤ 3 points.
- **High-importance prompt**: 3 consecutive clean iterations.
- **Diverged**: after 3+ iterations, unclear points are not decreasing.
- **Resource stop**: user explicitly accepts remaining risk.

At convergence, run a **hold-out scenario** not used during tuning. If accuracy drops ≥ 15 points, treat as overfitting and resume.

#### 7. Cross-Model Reproducibility
After tuning converges on one model, verify with a secondary model via `delegate_task(..., model={"provider": ...})`. If transfer fails, the prompt is model-dependent, not instruction-clarity.

Compare:
| Metric | Primary | Secondary | Delta |
|---|---|---|---|
| Scenario accuracy | X% | Y% | ±Z% |
| [critical] failures | N | M | ±P |

**Caveats**: single execution is not statistically significant; model size confounds architecture.

---

## Part II — promptfoo CI Pipeline

### Overview
[promptfoo](https://promptfoo.dev) is a CLI tool for declarative LLM prompt evaluation. It connects to multiple providers and runs a matrix of prompts × tests with assertions.

### When to Use
- Bootstrapping a regression-testing environment for prompts.
- Switching between API-key providers and local models.
- Debugging why `promptfoo eval` returns 0% or 100% failure when prompts "look correct."

### Provider Setup

**OpenAI** (requires `OPENAI_API_KEY`):
```yaml
providers:
  - openai:gpt-4o-mini
```

**Ollama** (local or cloud):
```yaml
providers:
  - ollama:gemma4:31b-cloud
```
**Pitfall**: Local models can exceed the default 300 s timeout. Increase:
```yaml
options:
  maxConcurrency: 1
  timeout: 60000
```

### Prompts and Template Variables

**Placeholder discipline**: The prompt file must contain the exact `{{var}}` placeholder matching the test `vars` key.
```text
あなたは要件分析者です。

【タスク】
{{task}}
```

**`file://` pitfall**: `file://` references are read raw by promptfoo and **do NOT** pass through nunjucks template rendering. The placeholder reaches the model literally.  
**Workaround A**: Inline the prompt directly inside the YAML config.  
**Workaround B**: Use a pre-processing script (`scripts/prepare-eval.js`) that resolves `file://` refs into inline strings before evaluation, and run it via npm scripts.

**`defaultTest.vars` override pitfall**: `defaultTest.vars` can silently overwrite per-test vars. Remove `defaultTest.vars` entirely when tests define their own.

### The Cartesian Product Pitfall
promptfoo evaluates **every prompt × every test**.

**Fix**: Split prompts by role into separate config files:
```
tests/requirements-analysis.yaml   # {{task}} vars only
tests/quality-gate.yaml            # {{code}} vars only
tests/impl-plan.yaml               # {{task}} vars only
```
Run each independently via npm scripts that chain `prepare-eval.js` first.

### YAML Literal Block for Code Strings
**Broken** — `"""` inside YAML maps causes indentation errors.
```yaml
code: """
def divide(a, b):
    return a / b
"""
```
**Correct** — use `|`:
```yaml
code: |
  def divide(a, b):
      return a / b
```

### CI Integration
```yaml
name: Promptfoo Evaluation
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
jobs:
  eval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm run eval:phase1
        continue-on-error: true
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: promptfoo-results, path: promptfoo-output/ }
```
Run via npm scripts (`npm run eval:phase1`) so `prepare-eval.js` executes first.

### Verification Checklist
- [ ] Prompt files contain exact `{{var}}` placeholders matching test vars.
- [ ] `file://` external prompts verified in `output.json` (not literal).
- [ ] `defaultTest.vars` removed if tests define their own.
- [ ] Multi-line strings use `|` not `"""`.
- [ ] `options.timeout` set for Ollama runs.
- [ ] `output.json` physically inspected for pass/fail mapping.
- [ ] Individual config files used to prevent Cartesian product noise.
- [ ] Old `output.json` removed before fresh runs.

---

## Pitfalls (Shared)
- **Self-rereading is insufficient** — author bias always hides gaps.
- **One scenario risks overfitting** — minimum 2, ideally 3.
- **Zero unclear points after 1 iteration is not convergence** — require 2–3 consecutive clean runs.
- **Never fabricate evidence** — if a result can't be shown by raw output, file diff, or subagent report, don't claim it worked.
- **`file://` prompts may silently fail substitution** — always verify with actual `output.json`.

---

## Related Skills
- `hermes-agent` — Hermes tool, skill, and delegation mechanics.
- `physical-evidence-and-verification` — truth-through-tools discipline.
- `subagent-driven-development` — broader subagent workflows.
- `workspace-hygiene-and-git-discipline` — keeping evaluation artifacts out of the parent repo.
