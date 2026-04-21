# OSS / Bilingual Readiness Design

## 1. Overview and Scope

**Goal**: Prepare this repository for OSS release with English-as-primary, Japanese-as-secondary bilingual documentation. All code comments in English. Growth-ready infrastructure from day one.

**Guiding Principles**:
- English for all code comments, issue/PR titles, and primary documentation
- Japanese for supplementary documentation (`docs/README.ja.md`, any Japanese-specific guides)
- No language-specific content in code (variable names, function names remain as-is)
- Growth infrastructure (CODEOWNERS, Changelog, labels) ready from initial release

**Out of Scope**:
- Machine translation — human-reviewed content only
- Localization tooling (no i18n frameworks)
- Non-English git commit messages (existing history unchanged)

---

## 2. Code Comments English Unification

### Target Files

| File | Current State | Action |
|------|--------------|--------|
| `.devcontainer/scripts/lib/lib.sh` | Mixed (Japanese comments) | Translate to English |
| `.devcontainer/scripts/lib/logging.sh` | English comments already | No change |
| `.devcontainer/scripts/lib/retry.sh` | English comments already | No change |
| `.devcontainer/scripts/lib/version.sh` | English comments already | No change |
| `.devcontainer/scripts/lib/workspace.sh` | English comments already | No change |
| `.devcontainer/scripts/update-tools.sh` | Mixed | Translate Japanese comments |
| `.devcontainer/on-create.sh` | Mixed | Translate Japanese comments |
| `.devcontainer/post-create.sh` | Mixed | Translate Japanese comments |
| `.devcontainer/post-start.sh` | Mixed | Translate Japanese comments |

### Rules

- Comment language only — do not rename functions or variables
- Shebang lines unchanged
- Japanese in string literals (e.g., `log_info "処理を開始します"`) remain as-is — these are user-facing output, not developer comments

---

## 3. Documentation Structure

### Target Files

| File | Language | Action |
|------|----------|--------|
| `README.md` | English (primary) | Update to reflect OSS-ready state |
| `docs/README.ja.md` | Japanese | Enhance with fuller content (see below) |
| `CONTRIBUTING.md` | English | Keep as primary |
| `docs/CONTRIBUTING.ja.md` | Japanese | Create as supplementary |
| `CODE_OF_CONDUCT.md` | English | Keep as primary |
| `docs/CODE_OF_CONDUCT.ja.md` | Japanese | Create as supplementary |
| `SECURITY.md` | English | Keep as primary |
| `docs/SECURITY.ja.md` | Japanese | Create as supplementary |
| `SUPPORT.md` | English | Keep as primary |
| `docs/SUPPORT.ja.md` | Japanese | Create as supplementary |

### docs/README.ja.md Enhancement Goals

- Match the depth of README.md (currently README.md is more detailed)
- Keep `docs/README.ja.md` as the Japanese entry point with full overview
- Japanese-specific notes where content differs from English (e.g., Japanese Dev Container community resources)

---

## 4. GitHub Configuration

### Target Items

| Item | Action |
|------|--------|
| `.github/ISSUE_TEMPLATE/` | Create standard templates (Bug, Feature, Documentation) |
| `.github/pull_request_template.md` | Already exists — enhance with OSS context |
| `FUNDING.yml` | Create (funding links, sponsor button) |
| `CODEOWNERS` | Create (default code owners for review assignment) |
| `.github/labels.yml` | Create for multilingual label definitions |

### Label Strategy

- Use English labels only (GitHub standard practice)
- `area/` and `language/` prefixes for routing
- `good first issue` / `help wanted` for contributor onboarding
- No Japanese labels

---

## 5. Licensing and Legal

### LICENSE File

- Currently: MIT License with "Tanaka Yasunobu" as copyright holder
- Verify: Copyright year, full name, contact email for user inquiries
- Add: SPDX license identifier header to key files

### License Headers in Code

- Add MIT license header comment to all shared library files (`.devcontainer/scripts/lib/*.sh`)
- Example: `# SPDX-License-Identifier: MIT` at the top of each file

### Contributor Requirements

- No CLA for now — MIT license handles rights
- Consider: `DCO` if needed later — not required for initial OSS release

---

## 6. Growth Infrastructure

### CODEOWNERS

```
# Default owners for everything
*   @tanaka-yasunobu

# Dev Container specific
.devcontainer/    @tanaka-yasunobu
```

### Changelog

- Add `CHANGELOG.md` with sections: Added, Changed, Deprecated, Removed, Fixed, Security
- Use [Keep a Changelog](https://keepachangelog.com/) format
- Initial entry: `## [1.0.0] - YYYY-MM-DD` — Initial OSS Release

### GitHub Actions Enhancements

- Already exists — verify it passes all checks
- Consider adding: stale PR/issue automation, labeler

---

## 7. Implementation Summary

### PR Title
`feat: prepare repository for OSS release (bilingual, growth-ready)`

### Files Changed

**Code comments (English unification)** — 5 files:
- `.devcontainer/scripts/lib/lib.sh`
- `.devcontainer/scripts/update-tools.sh`
- `.devcontainer/on-create.sh`
- `.devcontainer/post-create.sh`
- `.devcontainer/post-start.sh`

**Documentation (bilingual)** — 6 files:
- `README.md` (update)
- `docs/README.ja.md` (enhance)
- `docs/CONTRIBUTING.ja.md` (create)
- `docs/CODE_OF_CONDUCT.ja.md` (create)
- `docs/SECURITY.ja.md` (create)
- `docs/SUPPORT.ja.md` (create)

**GitHub configuration** — 5 files:
- `.github/ISSUE_TEMPLATE/bug.md` (create)
- `.github/ISSUE_TEMPLATE/feature.md` (create)
- `.github/ISSUE_TEMPLATE/docs.md` (create)
- `.github/pull_request_template.md` (enhance)
- `FUNDING.yml` (create)
- `CODEOWNERS` (create)
- `.github/labels.yml` (create)

**Licensing and legal** — 6 files:
- `LICENSE` (update copyright)
- `.devcontainer/scripts/lib/lib.sh` (add SPDX header)
- `.devcontainer/scripts/lib/logging.sh` (add SPDX header)
- `.devcontainer/scripts/lib/retry.sh` (add SPDX header)
- `.devcontainer/scripts/lib/version.sh` (add SPDX header)
- `.devcontainer/scripts/lib/workspace.sh` (add SPDX header)

**Growth infrastructure** — 1 file:
- `CHANGELOG.md` (create)

**Total**: ~20 files across all categories

---

## 8. Verification Criteria

- All shell scripts pass `shellcheck`
- All bats tests pass (`npm run test:shells`)
- No Japanese comments remain in `.sh` files (string literals除外)
- `README.md` and `docs/README.ja.md` both exist with substantial content
- All GitHub templates, FUNDING.yml, CODEOWNERS present
- `CHANGELOG.md` exists with initial release entry
