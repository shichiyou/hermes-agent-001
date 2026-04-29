# AI-DLC × CoDD × Graphify Lab Setup

This is the condensed companion to the main `aidlc-v-model-operations` skill. Use it when you need to **build** the lab environment before operating it.

## Core Principle

Do **not** fork or submodule `awslabs/aidlc-workflows` as the lab itself. Install official packages into a separate target project.

| Repository | Correct role |
|---|---|
| `awslabs/aidlc-workflows` | Rule distribution source. Download release ZIP, install rules into AI assistant files (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`). |
| `yohey-w/codd-dev` | PyPI package `codd-dev`. Use `codd init`, `validate`, `scan`, `measure`. |
| `safishamsi/graphify` | PyPI package `graphifyy`. Use `graphify update`, `query`, `benchmark`. |

## Required Directory Shape

```text
experiences/aidlc-codd-graphify-lab/
├── README.md
├── AGENTS.md
├── CLAUDE.md
├── .github/copilot-instructions.md
├── .aidlc-rule-details/
├── codd/codd.yaml
├── docs/requirements/requirements.md
├── sample-app/
├── sample-app/graphify-out/
│   ├── graph.json
│   ├── GRAPH_REPORT.md
│   └── graph.html
└── logs/
```

## Preflight / Remnant Cleanup

If an old invalid lab exists as a submodule, remove it before creating the new one:

```bash
git submodule deinit -f experiences/aidlc-codd-demo
git rm -f experiences/aidlc-codd-demo
rm -rf .git/modules/experiences/aidlc-codd-demo
git commit -m "chore: remove invalid aidlc codd demo submodule"
git push origin main
```

Verify fully gone:
```bash
git submodule status --recursive 2>/dev/null || true
git config --get-regexp 'submodule\.experiences/aidlc-codd-demo\..*' || true
git ls-tree -r --name-only HEAD | grep '^experiences/aidlc-codd-demo' || echo 'REMOVED'
```

## Installation Steps

### 1. AI-DLC Rules (Official Release ZIP)

1. Download latest `ai-dlc-rules-v<release-number>.zip` from GitHub Releases to a temp directory.
2. Extract.
3. Copy to assistant-specific locations:
   - Codex → `AGENTS.md`
   - Claude Code → `CLAUDE.md`
   - GitHub Copilot → `.github/copilot-instructions.md`
   - Copy `aws-aidlc-rule-details/` → `.aidlc-rule-details/`

Security: do not run or commit hook-generating setup commands (`.claude/settings.json`, `.codex/hooks.json`, `.git/hooks/*`) without explicit review.

### 2. CoDD (`codd-dev`)

```bash
pip install codd-dev
codd init --project-name "aidlc-codd-graphify-lab" --language "<language>"
# For existing sample app:
codd extract
codd require
codd plan --init
codd scan
```

**Pitfall**: `codd init` writes to `codd/codd.yaml`, not necessarily root. Patch it if scanning wrong dirs:
```yaml
scan:
  source_dirs:
    - "sample-app/src/"
  test_dirs:
    - "sample-app/tests/"
  doc_dirs:
    - "docs/"
```

**Required evidence**:
- `codd --version` exists
- `codd/codd.yaml` exists
- `codd scan` produces nodes/edges
- Markdown docs contain CoDD frontmatter (`codd.node_id`, `depends_on`)

### 3. Graphify (`graphifyy`)

```bash
pip install graphifyy && graphify install
graphify update sample-app
```

**Observed behavior**: output is written under the target directory (`sample-app/graphify-out/`), not necessarily `./graphify-out/`.

Optional queries:
```bash
graphify explain "TaskService"
graphify query "How does a task move from todo to done?"
graphify benchmark graphify-out/graph.json
```

**Required evidence**:
- `graphify-out/graph.json`
- `graphify-out/GRAPH_REPORT.md`

### 4. Three-Way Coherence Closure

After any code change, run the verification loop:

```bash
python -m pytest -v sample-app/tests
codd validate
codd scan
codd measure
graphify update sample-app
graphify query "coverage, missing links, and major risks" --graph graphify-out/graph.json
```

## Anti-Patterns / Failure Indicators

Do not claim completion if any of these is true:
- `codd` or `graphify` command is missing.
- `codd.yaml` or CoDD frontmatter is missing.
- `graphify-out/graph.json` is missing.
- The lab is just a fork of `aidlc-workflows` with a hand-written `demo-project/`.
- No raw tool outputs (`codd scan`, `graphify update`) are present.

## Submodule Preservation

After lab-side work:
```bash
cd experiences/aidlc-codd-graphify-lab
git add ...
git commit -m "..."
git push
git rev-parse HEAD && git rev-parse origin/main  # must match
cd ../..
git add experiences/aidlc-codd-graphify-lab
git commit -m "chore: update lab submodule pointer"
git push
git submodule status --recursive  # verify parent points at new commit
```

## Conversion from Remnant Directory to Submodule

If replacing an existing tracked directory with a submodule at the same path, follow the full protocol in `workspace-hygiene-and-git-discipline` (Part II — Converting a Tracked Directory into a Submodule) before installing AI-DLC packages.
