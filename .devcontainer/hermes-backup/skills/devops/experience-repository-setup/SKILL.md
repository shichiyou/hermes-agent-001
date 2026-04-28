---
name: experience-repository-setup
description: Set up an isolated "experience repository" using Git submodules to test methodologies (like AI-DLC x CoDD) without polluting the primary project root.
---

# Experience Repository Setup

## Trigger
When a user requests a "demo", "experience", or "verification" repository to test a specific architectural pattern, methodology, or toolset without altering the main codebase. Also triggers when the user wants to evaluate a tool (e.g., promptfoo, playwright) in a CI/CD pipeline context while keeping the parent repository clean.

## Workflow

There are two patterns depending on the user's goal:

### Pattern A: Import Rules (Methodology-First)
For testing a methodology where an external rule set (e.g., AI-DLC) is the canonical reference:

1.  **Isolate the Context**: Create a dedicated `experiences/` directory at the project root to act as a namespace for all experimental repositories.
2.  **Import Base Methodology**: Add the reference methodology as a Git submodule.
    - Command: `git submodule add <URL> experiences/<demo-name>`
3.  **Build the Application under Test (AUT)**: Create a `demo-project/` directory *inside* the submodule folder to keep the rules and the target code physically close but logically separated.
4.  **Create a Manifest**: Write a `DEMO_MANIFEST.md` mapping the relationship between rules, target project, and coherence state.

### Pattern B: Standalone Tool Evaluation (Tool-First)
For evaluating a tool (e.g., promptfoo, testing framework) with full CI/CD without polluting the parent workspace:

1.  **Initialize standalone repo in `~/workspace/repos/`** (workspace-hygiene):
    ```bash
    mkdir -p ~/workspace/repos/<tool>-ci-lab
    cd ~/workspace/repos/<tool>-ci-lab
    git init --initial-branch=main
    ```
2.  **Install and configure the tool** (devDependencies, config files, prompts, tests):
    ```bash
    npm init -y
    npm install --save-dev <tool>
    # Create: .gitignore (exclude node_modules, outputs), prompts/, tests/config.yaml, src/, .github/workflows/<tool>-eval.yml
    ```
3.  **Push to remote** (create GitHub repo first, then push):
    ```bash
    gh repo create <owner>/<tool>-ci-lab --public --source=. --push
    ```
4.  **Link as submodule** (from parent repo):
    ```bash
    cd /workspaces/<parent-repo>
    git submodule add https://github.com/<owner>/<tool>-ci-lab.git experiences/<tool>-ci-lab
    git commit -m "chore: add <tool>-ci-lab submodule"
    ```
5.  **Integrate into VS Code Workspace**:
    Add to `<repo>.code-workspace`:
    ```json
    { "name": "実験: <tool>-ci-lab", "path": "experiences/<tool>-ci-lab" }
    ```

## VS Code Workspace Integration
After adding any submodule under `experiences/`, update the workspace file:
```bash
# Verify JSON syntax after editing
python3 -m json.tool <repo>.code-workspace > /dev/null && echo "JSON valid"
```

## CI/CD Workflow Template (GitHub Actions)
Place under `.github/workflows/` inside the submodule repository (not the parent):
```yaml
name: Tool Evaluation
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
  schedule: [ cron: '0 9 * * 1' ]  # Weekly regression
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

## `.gitignore` Template (Tool Repos)
```
node_modules/
<tool>-output/
.env
*.log
dist/
coverage/
```

## Workspace-Hygiene Checklist
Before `git add` in the parent repo, verify:
- `node_modules` is NOT in `git ls-files`
- Tool outputs (e.g., `promptfoo-output/`) are NOT in `git ls-files`
- `.env`, `*.log` are NOT in `git ls-files`
- All artifacts land in `~/workspace/tmp/`, `~/workspace/reports/`, or the submodule's `.gitignore` paths

## Pitfalls
- **Root Pollution**: Avoid running `git add` on `experiences/` unless the intent is to commit the submodule reference. For standalone tool repos, NEVER run `git add node_modules` — verify with `git ls-files | grep node_modules`.
- **Path Confusion**: Always use absolute paths or clearly defined relative paths in manifests and workspace files.
- **Submodule Detachment**: For methodology imports, treat submodules as read-only for rules. For standalone tool repos, ensure `main` branch is checked out (`git branch` shows `* main`, not detached HEAD) before making changes.
- **Nested node_modules**: `npm install` inside a submodule will create `node_modules/` in the working tree. If accidentally staged in the parent, run `git rm --cached -r node_modules/` and add to `.gitignore`.

## Verification
- Pattern A: `ls -R experiences/<demo-name>` shows methodology rules + `demo-project/` + `DEMO_MANIFEST.md`.
- Pattern B: Run these checks:
  1. `git -C <parent> submodule status | grep <tool>-ci-lab` → shows commit hash
  2. `cat <parent>/.gitmodules | grep <tool>-ci-lab` → URL matches remote
  3. `git -C experiences/<tool>-ci-lab branch` → `* main` (not detached)
  4. `git -C experiences/<tool>-ci-lab ls-files | grep node_modules | wc -l` → `0`
  5. `ls <parent>/node_modules 2>/dev/null || echo "OK"` → parent root is clean
  6. `python3 -m json.tool <parent>/.code-workspace` → valid JSON
