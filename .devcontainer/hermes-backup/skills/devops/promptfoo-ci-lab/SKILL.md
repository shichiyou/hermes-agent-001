---
name: promptfoo-ci-lab
description: "Set up and troubleshoot a promptfoo evaluation pipeline for LLM prompts. Covers local execution, Ollama provider configuration, YAML config structure, template variable injection, the prompt×test Cartesian product pitfall, and result inspection. Use when bootstrapping or debugging a promptfoo CI/CD lab."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [promptfoo, llm-eval, ci-cd, ollama, yaml, prompt-testing]
    category: devops
    related_skills: [empirical-prompt-tuning, experience-repository-setup, workspace-hygiene]
---

# promptfoo CI/CD Evaluation Lab

## Overview

[promptfoo](https://promptfoo.dev) is a CLI tool for declarative LLM prompt evaluation. It connects to multiple providers (OpenAI, Anthropic, Ollama, etc.) and runs a matrix of prompts against tests with assertions.

This skill covers the full workflow from an empty submodule to a working local evaluation — including the common pitfalls that cause silent failures or misleading pass/fail rates.

## When to Use

- Bootstrapping a `promptfoo` evaluation environment inside a Git submodule or isolated directory.
- Switching from an API-key provider (OpenAI) to a local/Cloud provider (Ollama) when keys are unavailable or rate limits are a concern.
- Debugging why `promptfoo eval` returns 0% or 100% failure when the prompts "look correct."
- Adding new prompts and tests to an existing promptfoo lab and verifying the matrix does not explode into meaningless combinations.
- Inspecting the physical `output.json` to understand which test/prompt pair failed and why.

## Prerequisites

```bash
# Inside your promptfoo lab directory
cd experiences/promptfoo-ci-lab  # or your equivalent path
npm install        # installs promptfoo CLI into node_modules
```

## Provider Setup

### OpenAI (default, requires API key)

```yaml
providers:
  - openai:gpt-4o-mini
  - openai:gpt-4o
```

Requires `OPENAI_API_KEY` environment variable. If missing, promptfoo exits with:
```text
Missing OPENAI_API_KEY (openai:gpt-4o-mini)
```

### Ollama (local or Cloud)

```yaml
providers:
  - ollama:gemma4:31b-cloud
```

Ollama must be running (`ollama list` to verify available models).

**Timeout pitfall:** Local models (e.g. `gemma4:e2b`) can exceed the default promptfoo timeout. In a lab session, a 7.2 GB local model timed out after **300 seconds** while the Cloud variant completed in ~38 seconds.

Mitigation:
```yaml
options:
  maxConcurrency: 1
  timeout: 60000   # milliseconds; increase if needed
```

## Prompts and Template Variables

### The Root Cause of Ignored `vars`

If your test defines `vars.task` but the prompt file lacks a `{{task}}` placeholder, promptfoo will **still run** — but the variable is silently discarded. The model receives the raw prompt text without the injected data, producing generic template responses.

**Correct:** prompt file contains the placeholder.
```text
あなたはAI-DLCの要件分析者です。

【タスク】
{{task}}

【出力観点】
1. ...
```

**Incorrect:** prompt file describes the placeholder but omits the actual `{{task}}` syntax.

### External Prompt Files (`file://`) Do NOT Substitute Variables

A critical variant of the missing-placeholder pitfall: when a prompt is loaded via `file://../prompts/foo.txt`, promptfoo may **fail to substitute** `{{var}}` placeholders even if the file contains them correctly. The placeholder text reaches the model verbatim as `{{task}}`. Verified with promptfoo v0.121.9.

**Workaround:** Inline the prompt directly inside the YAML config:
```yaml
prompts:
  - |
    あなたはAI-DLCの要件分析者です。
    【タスク】
    {{task}}
    ...
```

Or pre-process the file into a temporary inline config before evaluation.

### Multiple Variables

If some prompts use `{{task}}` and others use `{{code}}`, every test should provide **both** variables (or use `defaultTest`).

```yaml
defaultTest:
  vars:
    task: ""
    code: ""
```

**Caution:** `defaultTest.vars` overrides per-test vars in some promptfoo versions. If a test declares `vars.task: "actual value"` but `defaultTest.vars.task: ""` is set, the empty string wins. Omit `defaultTest.vars` entirely when each test defines its own variables.

## The Cartesian Product Pitfall

promptfoo evaluates **every prompt × every test** as a Cartesian product.

Given:
- 3 prompts (requirements-analysis, quality-gate, impl-plan)
- 6 tests (mixed `task`-only and `code`-only)

You get 18 assertion runs. Many will be nonsense combinations (e.g. quality-gate prompt fed a `task` var with no `code`), producing false failures.

**Solutions:**

1. **Preferred:** Split into separate config files per prompt role:
   - `tests/requirements-analysis.yaml` — tests only for `{{task}}`
   - `tests/quality-gate.yaml` — tests only for `{{code}}`
   - `tests/impl-plan.yaml` — tests only for `{{task}}`
   
   Run selectively: `npx promptfoo eval -c tests/quality-gate.yaml`

2. **Single-file workaround:** Keep all prompts in one file but use `defaultTest.vars` to ensure every test has every variable, and design each prompt to gracefully handle empty inputs. This is less reliable.

## YAML Structural Pitfall: Triple Quotes

Using `"""` for multi-line strings inside a YAML mapping causes indentation errors in promptfoo's YAML parser:

```yaml
# BROKEN
    code: """
def divide(a, b):
    return a / b
"""
```

Use YAML literal block (`|`):
```yaml
# CORRECT
    code: |
      def divide(a, b):
          return a / b
```

## Running Evaluation

```bash
# Standard eval
npm run eval

# With explicit output file for inspection
npx promptfoo eval -c tests/promptfooconfig.yaml --output output.json --no-progress-bar

# View in browser
npx promptfoo view
```

## Inspecting Results

After evaluation, `output.json` contains all runs. Parse it with Python to understand which (prompt, test) pair passed:

```bash
python3 -c "
import json, sys
data = json.load(open('output.json'))
for r in data['results']['results']:
    label = r['prompt']['label'][:30]
    status = 'PASS' if r['success'] else 'FAIL'
    vars_used = r.get('vars', {})
    print(f'{status} | {label} | {vars_used}')
"
```

**Critical rule:** Do not trust the terminal table summary alone. Always cross-check `output.json` to confirm which specific test+prompt combinations contributed to the pass/fail counts.

## Common Pitfalls

1. **Prompt file missing `{{var}}` placeholder** — vars are passed but never injected. The model outputs a generic template response, and assertions against expected content fail.

2. **`file://` external prompt files not substituting `{{var}}`** — Even when the file contains `{{task}}`, promptfoo may pass the literal string to the model. Inline prompts in the YAML config are the reliable workaround.

3. **`defaultTest.vars` overriding per-test vars** — If `defaultTest.vars.task: ""` is set, a test's `vars.task: "real value"` may be overwritten by the empty string. Remove `defaultTest.vars` entirely when tests define their own variables.

4. **Ollama local model timeout** — Large local models can exceed 300s. Use Cloud endpoints or increase `options.timeout`.

5. **Cartesian product explosion** — Multiple prompts + multiple tests = all combinations. Without careful variable scoping, most combinations are invalid and inflate failure rates.

6. **YAML triple-quote indentation crash** — `"""` inside nested YAML maps breaks js-yaml parsing. Always use `|` literal blocks for multi-line code strings.

7. **Assuming `output.json` is old** — promptfoo caches and appends. Remove old `output.json` before a fresh run if you need clean physical evidence.

## Verification Checklist

- [ ] `npm install` completed and `node_modules/.bin/promptfoo` exists
- [ ] `providers` section points to an available model (verified with `ollama list` or API key set)
- [ ] Each prompt file contains the exact `{{var}}` placeholder matching the test `vars` keys
- [ ] **If using `file://` external prompts:** Run a manual test (`npx promptfoo eval -c ...`) and inspect `output.json` to ensure `{{var}}` was substituted, not passed literally. If literal, inline the prompt in the YAML config.
- [ ] **If using `defaultTest.vars`:** Verify that per-test `vars` are NOT silently overridden by empty `defaultTest` values. Remove `defaultTest.vars` entirely if tests define their own.
- [ ] Multi-line code blocks in YAML use `|` not `"""`
- [ ] `options.maxConcurrency` and `options.timeout` are set for Ollama runs
- [ ] Evaluation outputs `output.json` which is physically inspected to verify pass/fail mapping
- [ ] If multiple prompts serve different roles, consider splitting into separate config files to avoid Cartesian product noise
