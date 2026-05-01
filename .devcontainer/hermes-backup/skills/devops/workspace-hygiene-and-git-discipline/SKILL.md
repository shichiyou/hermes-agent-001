---
name: workspace-hygiene-and-git-discipline
description: >
  Keep parent repositories clean, manage submodules safely, and isolate experimental
  work without polluting the main codebase. Covers artifact routing, pre-commit
  validation, detached-HEAD recovery, submodule pointer sync, and experience-repo
  setup for CI/tool evaluation.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags:
      - git
      - hygiene
      - workspace
      - submodule
      - repository
      - experience
      - ci
      - pollution-prevention
    related_skills:
      - physical-evidence-and-verification
      - hermes-infrastructure-operations
      - experience-repository-setup
---

# Workspace Hygiene & Git Discipline

> **“A clean parent repo is not an accident—it is a protocol.”**

This umbrella covers two complementary disciplines:
1. **Workspace Hygiene** — routing agent-generated artifacts *outside* the parent repo and preventing accidental commits of reports, clones, and scratch files.
2. **Git Discipline** — safe submodule alignment, detached-HEAD recovery, and pointer synchronization so that "completed" work is actually visible to anyone cloning the parent repo.

---

## Part I — Artifact Routing & Output Hygiene

### Routing Rules

| Artifact Type | Destination | Rationale |
|---|---|---|
| Research reports | `~/workspace/reports/` | Persistent, outside git tracking |
| Security/audit reports | `~/workspace/audits/` | Persistent, outside git tracking |
| Cloned external repos | `~/workspace/repos/` | Avoids accidental submodule pollution |
| Temporary / scratch files | `~/workspace/tmp/` | Disposable by design |
| Wiki content (persistent) | `~/wiki/` (submodule) | Git-tracked, but in its own repo |
| App code / project config | Parent repo root | Intentional changes ONLY |

### Pre-Commit Checklist (Run Before Every `git add` in Parent Repo)
1. **Path check**: Is the file inside `/workspaces/hermes-agent-001/` (or equivalent)?
2. **Intent check**: Is this an intentional code/config/doc change, or an agent artifact?
3. **Redirect**: If artifact → write to `~/workspace/` instead, do NOT stage it.
4. **Naming guard**: Never commit files matching `*-research-report.md`, `*-audit-report.md`, `*-security-audit-report.md`.

### What Belongs vs. Never Belongs in Parent Repo

**OK to commit**:
- Source code, application files
- Project docs (README, CHANGELOG, CONTRIBUTING)
- Configuration and tooling files
- Wiki submodule pointer (the hash, not the content)

**NEVER commit**:
- Agent-generated research/audit reports
- Cloned external repositories
- Scratch/comparison/temporary files
- `node_modules`, `.venv`, build artifacts

### Cleanup Procedure (When Mistakes Happen)
```bash
mv /workspaces/hermes-agent-001/*-report.md ~/workspace/reports/
cd /workspaces/hermes-agent-001
git rm --cached <file>
git commit -m "cleanup: move agent artifact to ~/workspace/"
```

### Devcontainer Persistence Note
`~/workspace/` lives in `/home/vscode/workspace/`. It survives container restarts but is destroyed by `docker compose down -v`. For cross-teardown persistence, use the wiki submodule or push to an external remote.

---

## Part II — Submodule Integrity & Alignment

### Physical State Audit (The "No-Assume" Phase)
Before any commit or merge, run all three perspectives:
```bash
# Parent perspective
git status                     # submodule marked modified?
# Submodule perspective
cd <submodule> && git status   # on a branch or detached HEAD?
# Remote perspective
cd <submodule> && git fetch origin && git log --oneline --graph --all
```

### Clean Alignment Procedure
If the submodule is in `detached HEAD` or diverged from remote:
1. **Backup local work**: note the commit hash (`git rev-parse HEAD`).
2. **Hard reset to remote**: `git checkout main && git reset --hard origin/main`
3. **Surgical re-application**: `git cherry-pick <local-commit-hash>`
4. **Resolve conflicts**: use `read_file`, resolve, `git cherry-pick --continue`
5. **Branch validation**: `git branch` must show `* main`

### Parent-Submodule Synchronization
Once the submodule is clean:
```bash
cd <parent-repo>
git add <submodule-dir>
git commit -m "chore: update <submodule> reference to latest main"
```

### Converting a Tracked Directory into a Submodule
When replacing a normal directory with a submodule at the same path:
1. Preserve the directory content outside the parent repo (`~/workspace/repos/...`).
2. Initialize and push the independent repo; verify `HEAD == origin/main`.
3. In the parent repo: `git rm -r <path>`.
4. Inspect leftovers:
   ```bash
   find <path> -maxdepth 4 -type f | sort | sed -n '1,200p'
   git ls-files --others --exclude-standard <path> | sort
   git status --ignored --short <path> | sed -n '1,160p'
   ```
5. If leftovers are only disposable artifacts (`.venv`, `__pycache__`, tool caches), remove: `rm -rf <path>`.
6. Add submodule: `git submodule add <url> <path>`.
7. Verify parent index shows mode `160000` for the path and `.gitmodules` URL matches submodule `origin`.
8. Commit, push, and verify with a clean `git clone` + `git submodule update --init --recursive`. (Detached HEAD on checkout is normal; just ensure the commit equals `origin/main` for active dev.)

### Mandatory Post-Completion Parent Check
After finishing work inside a submodule and reporting completion:
```bash
cd <parent-repo>
git status --short
```
- **Expected**: Empty output (clean).
- **If dirty** (`M <submodule-path>`): stage pointer → commit → push → verify `git rev-parse HEAD` == `git ls-remote origin main`.

**Why this matters**: Commits inside the submodule are invisible to parent-repo clones until the pointer is committed. Skipping this step creates a "Ghost Completion."

### Verification Criteria
- `cd <submodule> && git branch` → shows `* main`
- `cd <submodule> && git log` → linear path from `origin/main` to latest local commit
- Parent `git status` → `working tree clean`

---

## Part III — Experience Repository Setup (Isolated Tool/Methodology Evaluation)

### Pattern A: Methodology-First (Import Rules)
For testing a methodology where an external rule set is canonical:
1. Create `experiences/` directory at project root.
2. `git submodule add <URL> experiences/<demo-name>`
3. Build AUT under `experiences/<demo-name>/demo-project/`
4. Write `DEMO_MANIFEST.md` mapping rules, target code, and coherence state.

### Pattern B: Standalone Tool Evaluation (Tool-First)
For evaluating a tool (e.g., `promptfoo`, testing framework) with full CI/CD without polluting the parent workspace:
1. **Init standalone repo** in `~/workspace/repos/<tool>-ci-lab`:
   ```bash
   mkdir -p ~/workspace/repos/<tool>-ci-lab && cd $_
   git init --initial-branch=main
   npm init -y
   npm install --save-dev <tool>
   ```
2. **Create**: `.gitignore` (exclude `node_modules`, outputs), `prompts/`, `tests/config.yaml`, `.github/workflows/<tool>-eval.yml`
3. **Push**: `gh repo create ... --push`
4. **Link as submodule** from parent repo:
   ```bash
   cd /workspaces/<parent-repo>
   git submodule add https://github.com/<owner>/<tool>-ci-lab.git experiences/<tool>-ci-lab
   git commit -m "chore: add <tool>-ci-lab submodule"
   ```
5. **VS Code workspace**: add to `.code-workspace`:
   ```json
   { "name": "実験: \u003ctool\u003e-ci-lab", "path": "experiences/<tool>-ci-lab" }
   ```

### CI/CD Workflow Template (Inside Submodule Repo)
```yaml
name: Tool Evaluation
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
  schedule: [ cron: '0 9 * * 1' ]
jobs:
  eval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npx <tool> eval --config tests/config.yaml
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: <tool>-results, path: <tool>-output/ }
```

### Pattern C: Extracting a Clean Template Repo from an Experimental Lab

Use this when an experimental submodule has matured into a reusable template.

1. **Audit first**: confirm parent and source lab are clean and inspect current submodules/workspace.
   ```bash
   git -C /workspaces/hermes-agent-001 status --short --branch
   git -C /workspaces/hermes-agent-001 config -f .gitmodules --get-regexp '^submodule\..*\.(path|url)$'
   python -m json.tool /workspaces/hermes-agent-001/hermes-agent-001.code-workspace >/dev/null
   gh auth status
   ```
2. **Create the template working tree outside the parent repo** (e.g. `/home/vscode/workspace/repos/<template-name>`). Avoid destructive setup commands such as `rm -rf`; if cleanup is required, inspect the path first and get confirmation for deletion.
3. **Copy only reusable assets** from the lab:
   - Include: agent instructions, `.aidlc-rule-details/`, process docs, CoDD config, CI/pre-commit gates, verification scripts, profile samples, manifest.
   - Exclude: `logs/`, `aidlc-docs/evidence/*.log`, `experiments/`, `codd/scan/`, Graphify caches/output, `.venv/`, `__pycache__/`, `.pytest_cache/`.
4. **Add template-specific controls**:
   - `template-manifest.yaml` with upstream versions/hashes and profile list.
   - `scripts/instantiate_template.py` that refuses to overwrite existing files.
   - `scripts/verify_template.py` that checks required paths and runs a minimal sample test.
   - A CI workflow for template integrity.
5. **Smoke-test the template before publishing**:
   ```bash
   python scripts/verify_template.py --check-repository
   TMP=/home/vscode/workspace/tmp/<template>-smoke-$(date +%Y%m%d%H%M%S)
   mkdir -p "$TMP"
   python scripts/instantiate_template.py --target "$TMP" --project-name smoke-project --profiles core,python
   find "$TMP" \( -name __pycache__ -o -name .pytest_cache \) -type d
   (cd "$TMP/sample-app" && python -m pytest -q)
   ```
   If smoke test finds generated caches copied into the target, patch the instantiator to exclude them before committing.
6. **Initialize, commit, create GitHub repo, and verify remote sync**:
   ```bash
   git init --initial-branch=main
   git add .
   git commit -m "Initial template extraction from <lab>"
   gh repo create <owner>/<template-name> --private --description "..." --source . --remote origin --push
   git rev-parse HEAD
   git rev-parse origin/main
   ```
7. **Add as parent submodule and update workspace if that is the project convention**:
   ```bash
   cd /workspaces/hermes-agent-001
   git submodule add https://github.com/<owner>/<template-name>.git experiences/<template-name>
   python -m json.tool hermes-agent-001.code-workspace >/dev/null
   git add .gitmodules experiences/<template-name> hermes-agent-001.code-workspace
   git commit -m "chore: add <template-name> repo"
   git push origin main
   git rev-parse HEAD
   git rev-parse origin/main
   git submodule status --recursive | grep <template-name>
   ```

**Pitfall**: Running `py_compile` or `pytest` inside the template repository creates `__pycache__` / `.pytest_cache`; delete them and ensure `.gitignore` plus the instantiator exclude generated directories before `git add`.

### VS Code Multi-Root Workspace Pitfall — Overlapping Folders & Extension Breakage

**Default rule**: Avoid registering project-root subdirectories (submodules, `wiki/`, etc.) or unrelated paths (`/home/vscode`) as separate workspace folders in `.code-workspace`; a single project-root folder is usually safer.

**Project-specific exception**: Some users intentionally maintain a multi-root workspace for submodules and expect new submodule repos to be added as separate folders. In that case, do not silently "simplify" the workspace. Match the existing workspace pattern and add per-folder extension disables for submodules that lack their own toolchain, e.g.:
```json
{
  "name": "テンプレート: aidlc-codd-graphify-template",
  "path": "experiences/aidlc-codd-graphify-template"
}
```
```json
"[experiences/aidlc-codd-graphify-template]": {
  "biome.enabled": false
}
```
Always validate with `python -m json.tool <workspace>.code-workspace` and read back the inserted folder/settings before claiming completion.

**Why this matters**: VS Code extensions that spawn per-folder instances (Biome, ESLint, Pylance, etc.) create N independent LSP sessions for N workspace folders. When folders overlap (a subdirectory is also a separate folder), the extension:
1. Starts duplicate sessions processing the same files — spams logs with "Overlapping workspace roots" warnings.
2. Fails to resolve binaries for folders that lack their own `node_modules/` or config — the LSP `initializeResult` returns `undefined` for version, and the status bar shows e.g. `$(biome-logo) undefined`.
3. Repeatedly logs "found configuration file outside of the current working directory" for every file event in the subdirectory.

**Diagnostic path** (used to trace Biome "undefined" status bar):
```
# Extension logs reveal the problem
~/.vscode-server/data/logs/<session>/exthost1/biomejs.biome/Biome.log
# Key lines:
#   "Running in multi-root workspace mode"
#   "Found N workspace folder(s)"
#   "Overlapping workspace roots: ..."
#   In per-folder LSP logs: "configuration file found outside cwd"
```

**Fix when multi-root is not intentionally required**: Reduce `.code-workspace` to a single folder (the project root). Explorer's tree view naturally shows subdirectories; separate workspace folders are only needed when folders are truly separate filesystem roots.

### `.gitignore` Template (Tool Repos)
```
node_modules/
<tool>-output/
.env
*.log
dist/
coverage/
```

---

## Pitfalls

- **Root pollution**: `git add` in the parent repo without checking artifact routing.
- **Path confusion**: ambiguous relative paths in manifests or workspace files.
- **Submodule detachment**: committing in detached HEAD creates a ghost commit.
- **Nested `node_modules`**: `npm install` inside a submodule creates untracked directories; always verify `git ls-files | grep node_modules` == 0.
- **The Status Illusion**: `git add .` in the parent repo only saves the submodule **pointer hash**, not its contents.
- **The Formal Plan Trap**: presenting a plan as a substitute for physical exploration. Always run the Audit phase first.
- **Ghost Completion**: submodule commits are done but parent pointer is stale → invisible to clones.
- **Placeholder `.env` values**: Hermes treats any non-empty value as "already configured." Use commented-out lines (`# KEY=`) instead of `YOUR_KEY_HERE`.

---

## Quick Verification Commands

```bash
# Check for agent artifacts in repo root
ls /workspaces/hermes-agent-001/*-report.md 2>/dev/null || echo "OK"

# Validate workspace JSON syntax
python3 -m json.tool <repo>.code-workspace > /dev/null && echo "Valid"

# Submodule health check
git -C <parent> submodule status | grep <submodule>
git -C <submodule> branch   # must show * main, not detached
git -C <submodule> ls-files | grep node_modules | wc -l   # must be 0
```

---

## Reference Files
- `references/biome-undefined-statusbar-debug.md` — Full root-cause analysis for Biome "undefined" status bar in multi-root workspaces (extension LSP version resolution, diagnostic commands, fix).

## Related Skills
- `physical-evidence-and-verification` — truth-through-tools discipline.
- `hermes-infrastructure-operations` — running Hermes services and cron jobs safely.
- `promptfoo-ci-lab` — concrete tool-evaluation example inside an experience repo.
