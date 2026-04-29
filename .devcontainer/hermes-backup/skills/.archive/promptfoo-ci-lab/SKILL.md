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

**Root cause (source-verified):** `processFileReference` in promptfoo's bundled source reads the file with `fs.readFileSync(filePath, "utf8").trim()` and returns the raw string. It does **not** pass through the nunjucks template renderer that handles inline YAML prompts.

**Workaround A — Inline the prompt directly inside the YAML config (most reliable):**
```yaml
prompts:
  - |
    あなたはAI-DLCの要件分析者です。
    【タスク】
    {{task}}
    ...
```

**Workaround B — Pre-process with a custom script (keeps prompts in separate files):**

Create `scripts/prepare-eval.js` that reads the YAML config, resolves `file://` references into inline strings, and writes a `-resolved.yaml`:

```js
// scripts/prepare-eval.js — resolve file:// prompts into inline text
import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';

const configFile = process.argv[2];
const configDir = path.dirname(path.resolve(configFile));
const config = yaml.load(fs.readFileSync(configFile, 'utf8'));

function resolvePrompt(p) {
  if (typeof p !== 'string' || !p.startsWith('file://')) return p;
  const filePath = path.resolve(configDir, p.slice(7));
  const ext = path.extname(filePath);
  if (ext === '.txt' || ext === '.md') return fs.readFileSync(filePath, 'utf8').trim();
  if (ext === '.yaml' || ext === '.json' || ext === '.yml') return yaml.load(fs.readFileSync(filePath, 'utf8'));
  throw new Error(`Unsupported file type: ${filePath}`);
}

function resolveAll(node) { /* ... recursive walk replacing prompts ... */ }
const resolved = resolveAll(config);
const outFile = configFile.replace(/\.ya?ml$/, '-resolved.yaml');
fs.writeFileSync(outFile, yaml.dump(resolved, { lineWidth: -1 }));
console.log(`Resolved: ${configFile} → ${outFile}`);
```

Register it in `package.json` (recommended as the canonical execution path):
```json
"scripts": {
  "eval": "npm run eval:phase1 && npm run eval:phase2 && npm run eval:phase3",
  "eval:phase1": "node scripts/prepare-eval.js tests/requirements-analysis.yaml && promptfoo eval -c tests/requirements-analysis-resolved.yaml --no-progress-bar",
  "eval:phase2": "node scripts/prepare-eval.js tests/quality-gate.yaml && promptfoo eval -c tests/quality-gate-resolved.yaml --no-progress-bar",
  "eval:phase3": "node scripts/prepare-eval.js tests/impl-plan.yaml && promptfoo eval -c tests/impl-plan-resolved.yaml --no-progress-bar"
}
```

And add `*-resolved.yaml` (note the **hyphen**, not a dot) to `.gitignore`:
```
node_modules/
promptfoo-output/
.env
*.log
dist/
coverage/
*-resolved.yaml
```

And add `*-resolved.yaml` (note the hyphen, not a dot) to `.gitignore`.

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

## CI/CD Integration

Use `npm run eval:phase*` (never direct `promptfoo eval` calls) so `prepare-eval.js` runs first. The Ollama provider typically fails on standard GitHub-hosted runners due to missing model servers; treat CI runs as **structure checks** rather than model execution verification.

```yaml
name: Promptfoo Evaluation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 9 * * 1'

# --- 制約注記 ---
# 本ワークフローは file:// プロンプト展開（prepare-eval.js）を含む構造検証を行う。
# プロバイダーが ollama であるため、GitHub Actions 標準 runner 上ではモデル接続不可。
# 実際の評価実行はローカル環境（npm run eval:phase*）で実施すること。
# CI 上では「ワークフロー構造・npm scripts 連携」の検証として機能する。

jobs:
  eval-all:
    name: Eval All Phases (Structure Check)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run eval:phase1
        continue-on-error: true
      - run: npm run eval:phase2
        continue-on-error: true
      - run: npm run eval:phase3
        continue-on-error: true
      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: promptfoo-results-all
          path: promptfoo-output/

  eval-phase1:
    name: Eval Phase 1 - Requirements Analysis
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run eval:phase1
        continue-on-error: true
      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: promptfoo-results-phase1
          path: promptfoo-output/
```

**Critical rules for CI integration:**
- **Never call `promptfoo eval` directly** in CI steps — always use `npm run eval:phase*`
- **Always use `continue-on-error: true`** when the provider is Ollama (not runnable on standard runners)
- **Upload artifacts with `if: always()`** so output is preserved even on "failure"
- **Replace `npx promptfoo@latest eval -c tests/phase.yaml`** style calls with npm scripts that chain `prepare-eval.js` first

When evaluating prompts that serve different AI-DLC phases (requirements analysis, quality gate, implementation plan), **split them into separate config files** rather than combining all prompts in one file. This avoids the Cartesian product pitfall and keeps each phase's tests isolated.

Example layout:
```
tests/
  requirements-analysis.yaml   # {{task}} vars only
  quality-gate.yaml            # {{code}} vars only
  impl-plan.yaml               # {{task}} vars only
```

Run each independently:
```bash
npm run eval:phase1   # requirements-analysis.yaml via prepare-eval.js
npm run eval:phase2   # quality-gate.yaml
npm run eval:phase3   # impl-plan.yaml
```

With a `prepare-eval.js` script, each npm script resolves `file://` refs into `-resolved.yaml`, runs eval, and lets you inspect per-phase results cleanly.

## Common Pitfalls

1. **Prompt file missing `{{var}}` placeholder** — vars are passed but never injected. The model outputs a generic template response, and assertions against expected content fail.

2. **`file://` external prompt files not substituting `{{var}}`** — Even when the file contains `{{task}}`, promptfoo may pass the literal string to the model. This is confirmed source-level behavior in `processFileReference`. Use either inline YAML prompts or a pre-processing script (`prepare-eval.js`) to resolve `file://` refs before evaluation.

3. **`defaultTest.vars` overriding per-test vars** — If `defaultTest.vars.task: ""` is set, a test's `vars.task: "real value"` may be overwritten by the empty string. **Remove `defaultTest.vars` entirely** when tests define their own variables.

4. **Ollama local model timeout** — Large local models can exceed 300s. Use Cloud endpoints or increase `options.timeout`.

5. **Cartesian product explosion** — Multiple prompts + multiple tests = all combinations. Without careful variable scoping, most combinations are invalid and inflate failure rates.

6. **YAML triple-quote indentation crash** — `"""` inside nested YAML maps breaks js-yaml parsing. Always use `|` literal blocks for multi-line code strings.

7. **Assuming `output.json` is old** — promptfoo caches and appends. Remove old `output.json` before a fresh run if you need clean physical evidence.

8. **`javascript` assertion returning `{ pass: true }` throws `undefined` error** — In promptfoo v0.121.9, returning a GradingResult object (`{ pass: true }`) from a `javascript` assertion causes: `Custom function must return a boolean, number, or GradingResult object. Got type undefined: undefined`. This is a known library bug. **Workaround:** Use simple `contains` assertions instead, or return primitive `true`/`false` if using inline JavaScript assertions.

9. **resolved.yaml cache causing stale test definitions** — If you forget to delete `*-resolved.yaml` after editing the source `.yaml`, `prepare-eval.js` may skip regeneration or promptfoo may load the stale resolved file. Always remove `*-resolved.yaml` and `output.json` before a fresh evaluation cycle.

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
