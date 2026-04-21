# OSS Bilingual Readiness — Implementation Plan

## Overview

Execute the [OSS / Bilingual Readiness Design](./2026-04-04-oss-bilingual-readiness-design.md) in one PR.
All tasks are independent and can be executed in parallel. Verification steps are grouped at the end.

---

## Phase 1: Code Comments — English Unification

### Task 1.1: Translate `lib.sh` comments to English
**File**: `.devcontainer/scripts/lib/lib.sh`
**Action**: Replace all Japanese comments with English equivalents. Keep function names and variables unchanged.
**Verification**: `shellcheck .devcontainer/scripts/lib/lib.sh`

### Task 1.2: Translate `update-tools.sh` comments to English
**File**: `.devcontainer/scripts/update-tools.sh`
**Action**: Replace all Japanese comments with English equivalents.
**Verification**: `shellcheck .devcontainer/scripts/update-tools.sh`

### Task 1.3: Translate `on-create.sh` comments to English
**File**: `.devcontainer/on-create.sh`
**Action**: Replace all Japanese comments with English equivalents.
**Verification**: `shellcheck .devcontainer/on-create.sh`

### Task 1.4: Translate `post-create.sh` comments to English
**File**: `.devcontainer/post-create.sh`
**Action**: Replace all Japanese comments with English equivalents.
**Verification**: `shellcheck .devcontainer/post-create.sh`

### Task 1.5: Translate `post-start.sh` comments to English
**File**: `.devcontainer/post-start.sh`
**Action**: Replace all Japanese comments with English equivalents.
**Verification**: `shellcheck .devcontainer/post-start.sh`

---

## Phase 2: SPDX License Headers

### Task 2.1: Add SPDX header to all library files
**Files**:
- `.devcontainer/scripts/lib/lib.sh`
- `.devcontainer/scripts/lib/logging.sh`
- `.devcontainer/scripts/lib/retry.sh`
- `.devcontainer/scripts/lib/version.sh`
- `.devcontainer/scripts/lib/workspace.sh`

**Action**: Add `# SPDX-License-Identifier: MIT` as the first line of each file. Preserve existing content.
**Verification**: `grep -L "SPDX-License-Identifier" .devcontainer/scripts/lib/*.sh` returns nothing

---

## Phase 3: Japanese Documentation Enhancement

### Task 3.1: Enhance `docs/README.ja.md`
**File**: `docs/README.ja.md`
**Action**: Expand content to match the depth of `README.md`. Ensure all sections present: Overview, Features, Quick Start, Project Layout, Customization, Updating Tools, Shared Libraries, Validation and CI, Worktree Workflow, Troubleshooting, Contributing, License.
**Verification**: `wc -l docs/README.ja.md` shows comparable line count to `README.md`

### Task 3.2: Create `docs/CONTRIBUTING.ja.md`
**File**: `docs/CONTRIBUTING.ja.md`
**Action**: Create Japanese translation of `CONTRIBUTING.md`. Use existing English content as base.
**Verification**: File exists at `docs/CONTRIBUTING.ja.md`

### Task 3.3: Create `docs/CODE_OF_CONDUCT.ja.md`
**File**: `docs/CODE_OF_CONDUCT.ja.md`
**Action**: Create Japanese translation of `CODE_OF_CONDUCT.md`. Use existing English content as base.
**Verification**: File exists at `docs/CODE_OF_CONDUCT.ja.md`

### Task 3.4: Create `docs/SECURITY.ja.md`
**File**: `docs/SECURITY.ja.md`
**Action**: Create Japanese translation of `SECURITY.md`. Use existing English content as base.
**Verification**: File exists at `docs/SECURITY.ja.md`

### Task 3.5: Create `docs/SUPPORT.ja.md`
**File**: `docs/SUPPORT.ja.md`
**Action**: Create Japanese translation of `SUPPORT.md`. Use existing English content as base.
**Verification**: File exists at `docs/SUPPORT.ja.md`

---

## Phase 4: GitHub Configuration

### Task 4.1: Create `.github/ISSUE_TEMPLATE/bug.md`
**File**: `.github/ISSUE_TEMPLATE/bug.md`
**Action**: Create standard bug report template with: Steps to Reproduce, Expected vs Actual, Environment (OS, Docker version, VS Code version), Screenshots (optional)
**Verification**: File exists

### Task 4.2: Create `.github/ISSUE_TEMPLATE/feature.md`
**File**: `.github/ISSUE_TEMPLATE/feature.md`
**Action**: Create standard feature request template with: Problem/Use Case, Proposed Solution, Alternatives Considered, Additional Context (optional)
**Verification**: File exists

### Task 4.3: Create `.github/ISSUE_TEMPLATE/docs.md`
**File**: `.github/ISSUE_TEMPLATE/docs.md`
**Action**: Create documentation improvement template with: Page/Section, Issue Type (Typo / Clarification / Missing Info / Outdated), Suggested Fix
**Verification**: File exists

### Task 4.4: Enhance `.github/pull_request_template.md`
**File**: `.github/pull_request_template.md`
**Action**: Add sections: Summary, Test plan, Verification steps, Related issue
**Verification**: File contains all sections

### Task 4.5: Create `FUNDING.yml`
**File**: `FUNDING.yml`
**Action**: Create GitHub Funding configuration. Placeholder for now (no funding links yet). Use `ko-fi` or `github` sponsor button format.
**Verification**: Valid YAML at `FUNDING.yml`

### Task 4.6: Create `CODEOWNERS`
**File**: `CODEOWNERS`
**Action**: Create CODEOWNERS file with `@tanaka-yasunobu` as default owner and for `.devcontainer/`
**Verification**: File exists and is valid

### Task 4.7: Create `.github/labels.yml`
**File**: `.github/labels.yml`
**Action**: Create GitHub Actions label definitions for: `area/` prefix labels, `language/` prefix labels, `good first issue`, `help wanted`, `bug`, `enhancement`, `documentation`
**Verification**: Valid YAML at `.github/labels.yml`

---

## Phase 5: Growth Infrastructure

### Task 5.1: Create `CHANGELOG.md`
**File**: `CHANGELOG.md`
**Action**: Create changelog with Keep a Changelog format. Initial entry: `## [1.0.0] - YYYY-MM-DD` with "Initial OSS release" under Added. Placeholder URL for changelog.
**Verification**: File exists with valid format

---

## Phase 6: LICENSE Update

### Task 6.1: Update `LICENSE` file
**File**: `LICENSE`
**Action**: Verify copyright holder is "Tanaka Yasunobu". Add SPDX identifier comment at top. No other changes needed.
**Verification**: `grep "Tanaka Yasunobu" LICENSE` returns the copyright line

---

## Phase 7: README.md Update

### Task 7.1: Update `README.md`
**File**: `README.md`
**Action**: Add a brief note at the top indicating this is an OSS-ready project. No major content changes — the README is already well-written. Add link to `docs/README.ja.md`.
**Verification**: `grep -c "OSS" README.md` returns 1 or more

---

## Verification (run after all tasks)

1. `shellcheck .devcontainer/scripts/lib/*.sh .devcontainer/scripts/update-tools.sh .devcontainer/on-create.sh .devcontainer/post-create.sh .devcontainer/post-start.sh` — all pass
2. `npm run test:shells` — all pass
3. `grep -r "日本語\|コメント\|処理\|取得\|設定\|確認\|実行" .devcontainer/scripts/ --include="*.sh" | grep -v "log_\|retry_\|normalize_\|versions_\|find_\|require_\|workspace_\|string"` — returns only string literal matches (user-facing output), no comment matches
4. `test -f FUNDING.yml && test -f CODEOWNERS && test -f CHANGELOG.md && test -f .github/labels.yml` — all true
5. `ls .github/ISSUE_TEMPLATE/` shows bug.md, feature.md, docs.md
6. `wc -l docs/README.ja.md | awk '{print $1}'` is >= 100 lines

---

## Completion

After all tasks pass verification, present the finishing-a-development-branch workflow to the user.
