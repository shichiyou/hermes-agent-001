# Project Initialization Agent Prompt

You are initializing a new project derived from the `ai-devcontainer-baseline` template.
Your job is to replace all template-owned identifiers with the user's values, create a
GitHub repository, and produce the initial commit.

This prompt must be executed on the **host**, not inside the Dev Container.
The Dev Container must not be started yet.

The authoritative human-readable guide for this same process is
[docs/project-init.md](../../docs/project-init.md). Follow the execution rules below
rather than paraphrasing that guide.

## Operating principles

- Think in English. Report back in the language the user is using.
- If any required parameter is missing, unclear, or ambiguous, ask the user before doing
  anything that changes state. Do not guess author names, GitHub usernames, or package names.
- Treat any cancel, error, timeout, empty output, or ambiguous output as unfinished. Re-check
  state before continuing.
- Prefer the narrowest verification (e.g. `grep -n` on a single file) before running broad
  commands.
- Do not start the Dev Container. Do not run `npm ci`, `uv sync`, or any container-only
  commands. Those are the user's responsibility after this prompt completes.

## Required parameters

Collect these from the user before making any changes.

| Parameter | Required | Default | Description |
|---|:---:|---|---|
| `PROJECT_NAME` | yes | — | npm and Python package name. Lowercase, hyphen-separated. |
| `GITHUB_USERNAME` | yes | — | GitHub user or organization handle (no leading `@`). |
| `REPO_NAME` | yes | — | Name of the repository on GitHub. Often the same as the folder name. |
| `AUTHOR_NAME` | yes | — | Human-readable author name for `LICENSE`, `package.json`, `pyproject.toml`. |
| `CONTAINER_NAME` | yes | — | Display name for the Dev Container. Shown in VS Code. |
| `PROJECT_DESCRIPTION` | yes | — | One-sentence description for `pyproject.toml`. |
| `LOCALE` | no | `en_US.UTF-8` | Value for `LANG`, `LANGUAGE`, `LC_ALL`. |
| `TIMEZONE` | no | `Etc/UTC` | Value for `TZ`. |
| `REPO_VISIBILITY` | no | `private` | `private` or `public`. Used with `gh repo create`. |
| `COPYRIGHT_YEAR` | no | current year | Year written into `LICENSE`. |

After collecting the parameters, restate them back to the user and wait for confirmation.

## Pre-flight checks

1. Confirm the current working directory is the freshly-copied project folder and is not
   the original `ai-devcontainer-baseline` clone. The folder name should match the intended
   Dev Container Home volume name.
2. Confirm the folder is a fresh Git repository with no commits yet. If `git log` shows any
   history, stop and ask the user how to proceed.
3. Confirm `gh auth status` reports an authenticated session for `GITHUB_USERNAME`'s scope.
4. Confirm the Dev Container is not currently running.
5. Run `grep -rn "tanaka-yasunobu\|Tanaka Yasunobu\|\"monorepo\"\|name = \"monorepo\"\|Ubuntu Dev Container" --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.git .`
   and record the list of files to edit.

## Edits to perform

Apply edits one file at a time, then verify each file with `grep` before moving on.
Preserve surrounding formatting and whitespace.

### 1. `CODEOWNERS`

Replace every occurrence of `@tanaka-yasunobu` with `@${GITHUB_USERNAME}`.

Verify:

```bash
grep -n "tanaka-yasunobu" CODEOWNERS
```

Expected: no matches.

### 2. `package.json`

- `"name": "monorepo"` → `"name": "${PROJECT_NAME}"`
- `"author": "Tanaka Yasunobu"` → `"author": "${AUTHOR_NAME}"`

Verify:

```bash
grep -nE '"name"|"author"' package.json | head -n 5
```

### 3. `pyproject.toml`

- `name = "monorepo"` → `name = "${PROJECT_NAME}"`
- `description = "Python/TypeScript monorepo workspace"` → `description = "${PROJECT_DESCRIPTION}"`
- `authors = [{ name = "Tanaka Yasunobu" }]` → `authors = [{ name = "${AUTHOR_NAME}" }]`

Verify:

```bash
grep -nE '^name|^description|^authors' pyproject.toml
```

### 4. `LICENSE`

Replace `Copyright (c) 2026 Tanaka Yasunobu` with
`Copyright (c) ${COPYRIGHT_YEAR} ${AUTHOR_NAME}`.

Verify:

```bash
grep -n "Copyright" LICENSE
```

### 5. `README.md`

Replace the template's title, description, and any author references with the user's project
text. Preserve the structural sections (`## What This Repository Is`, etc.) unless the user
explicitly asks to restructure them.

If the user does not provide new body text, replace only the title and the paragraph
immediately below it, and flag the remaining template text for the user to revise later.

### 6. `docs/README.ja.md`

Apply the same changes as `README.md`, in Japanese, to keep the bilingual pair consistent.

### 7. `.devcontainer/devcontainer.json`

Replace `"name": "Ubuntu Dev Container"` with `"name": "${CONTAINER_NAME}"`.

If the user supplied non-default `LOCALE` or `TIMEZONE`, also update the matching
`containerEnv` entries (`LANG`, `LANGUAGE`, `LC_ALL`, `TZ`) and the corresponding
`ENV` lines in `.devcontainer/Dockerfile`.

Verify:

```bash
grep -nE '"name"|"LANG"|"TZ"' .devcontainer/devcontainer.json
```

## Post-edit verification

Run the broad sweep again. It must produce **zero** matches in source files:

```bash
grep -rn "tanaka-yasunobu\|Tanaka Yasunobu\|\"monorepo\"\|name = \"monorepo\"\|Ubuntu Dev Container" \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.git .
```

If any match remains, resolve it before proceeding.

## GitHub repository and initial commit

1. Create the remote repository:

   ```bash
   gh repo create ${GITHUB_USERNAME}/${REPO_NAME} --${REPO_VISIBILITY} --source=. --remote=origin
   ```

2. Stage and commit:

   ```bash
   git add -A
   git commit -m "chore: initialize from ai-devcontainer-baseline"
   ```

3. Push:

   ```bash
   git push -u origin main
   ```

4. Observed verification (mandatory):

   ```bash
   git log --oneline -1
   git status
   git ls-remote --heads origin main
   ```

   - `git log --oneline -1` must show the new initial commit.
   - `git status` must report a clean tree with `origin/main` tracking set.
   - `git ls-remote` must return the same SHA as the local `main`.

   If any of these three checks fails, stop and report the mismatch. Do not describe the
   initialization as complete.

## Final report

Report to the user:

- Which files were modified (with a short diff summary per file).
- Which parameters you used, including any defaults that were applied.
- The GitHub repository URL.
- The initial commit SHA from `git log --oneline -1`.
- Remaining tasks for the user: open the Dev Container with **Dev Containers: Reopen in
  Container**, then run `npm ci`, `uv sync --dev`, `npm run lint`, `npm run test:shells`,
  and `npm run test` to confirm the baseline.
- A pointer to [docs/customization.md](../../docs/customization.md) for optional follow-up
  adjustments (locale, timezone, AI tooling, update strategy).

If any step above could not be completed, report the unresolved state explicitly instead
of claiming completion.
