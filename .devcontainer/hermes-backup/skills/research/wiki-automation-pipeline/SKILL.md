---
name: wiki-automation-pipeline
description: >
  Unattended daily research, summary generation, and browser-based ingestion
  pipeline for an LLM Wiki. Covers cron job patterns, SPA extraction,
  HN/Reddit sentiment scraping, playbooks for parallel subagent research,
  summary formatting, and git commit hygiene.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags:
      - wiki
      - research
      - cron
      - daily-update
      - browser
      - scraping
      - sentiment
      - automation
    related_skills:
      - hermes-infrastructure-operations
      - physical-evidence-and-verification
      - llm-wiki
---

# Wiki Automation Pipeline

> **Cron-driven, unattended research updates for a git-tracked LLM Wiki.**

This umbrella replaces the fragmented daily-research / daily-summary / browser-tactics trio with a single pipeline skill. It covers orient-phase reading, parallel subagent delegation, synthesis rules, browser extraction, summary formatting, and git commit hygiene.

## When to Use
- A scheduled cron job needs to update one or more wiki entity pages.
- You need to ingest web sources (docs, blogs, forums) into the wiki.
- You are summarizing a day’s wiki changes for index.md navigation.
- `curl` returns empty HTML because the target is a JS-rendered SPA.
- Browser tooling fails with shared-library errors or search-engine bot detection.

---

## Part I — Daily Research Update

### 1. Orient (Every Session)

Before touching anything, read the wiki backbone:
```bash
read_file "$WIKI/SCHEMA.md"
read_file "$WIKI/index.md"
read_file "$WIKI/log.md"
read_file "$WIKI/entities/<target-page>.md"
```
This prevents duplicates and structural inconsistencies.

### 2. Parallel Delegation

Dispatch two subagents via `delegate_task`:

**Subagent A: Official Sources**
- GitHub repo: releases, commits, issues, PRs, discussions
- Official blog posts and documentation updates
- Toolsets: `browser`
- Context: what is already known (last version, star count, open issues)

**Subagent B: Community & Comparisons**
- HN, Reddit, dev.to, Zenn, Qiita, Medium, technical blogs
- Search queries: `"<name> review"`, `"<name> pitfalls"`, `"<name> vs"`
- Sentiment, pain points, best practices, competitive alternatives
- Toolsets: `browser`
- Context: known issues, existing comparison data

**CRITICAL**: Always search non-English communities (JP: Zenn/Qiita, CN: Juejin/CSDN). For AWS/AI tools, Japanese community activity often exceeds English by 10–50×. This asymmetry is a meaningful adoption signal.

Each subagent receives:
- What is already in the wiki (so they don’t re-discover it).
- The cutoff date (only find things since last update).
- The domain/tag taxonomy (stay in scope).

### 3. Synthesis Rules

Merge reports into the target wiki page:
- **Separate canonical specs from community insights** — structured sections:
  - `Specifications & Features` (what it claims)
  - `Community Insights & Pitfalls` (what it actually does)
  - `Core Debates` (philosophical disagreements with comparative tables)
- **Only add net-new information** — do not duplicate existing content.
- **Mark resolved issues** — note PR merges and fix releases.
- **Update counts** — versions, stars, issues, model counts.
- **Preserve section structure** — do not reorganize between updates.
- **Quantify everything** — issue numbers, comment counts, dates, URLs.
- **Named sources only** — attribute to specific author and platform (e.g., "kiakiraki (Zenn, Mar 2026)").

### 4. Update Navigation
- Refresh `index.md` one-line summary if content changed significantly.
- Append to `log.md`:
  ```markdown
  ## [YYYY-MM-DD] update | Page Name — Daily Research Update
  - Summary of what changed
  - Key new sections, issues resolved, sources
  ```

### 5. Git Commit & Push
```bash
cd "$WIKI"
git add -A
git commit -m "update: <page> daily research <date> — <brief summary>"
git push
```
Verify: `git log --oneline -1`

### 6. Silent Mode
If all subagents find genuinely nothing new, respond with exactly `[SILENT]` (suppresses delivery in cron contexts). Do not write a no-op update.

---

## Part II — Daily Summary Generator

### 1. Compute Diffs
Find `BEFORE` (parent of oldest commit in 24-hour window), then:

| Metric | Command |
|--------|---------|
| Aggregate +/- lines | `git diff --shortstat $BEFORE HEAD` |
| Per-file stats | `git diff --stat $BEFORE HEAD` |
| Per-file line counts | `git show $BEFORE:<entity>.md \| wc -l` vs `git show HEAD:<entity>.md \| wc -l` |
| New wikilinks | regex `[[...]]` on added diff lines |
| CVE references | regex `CVE-\d{4}-\d+` on added diff lines |
| Community issues | regex `#\d+` on added diff lines |

### 2. Format Summary
```markdown
---
title: Daily Update Summary YYYY-MM-DD
type: query
tags: [summary, daily-update]
---

# 📋 LLM Wiki 日次更新サマリ — YYYY-MM-DD

N ページ更新

🔄 更新ページ

🟢 [page-name]
  X行→Y行（+Δ行）
  [2–3 line summary]

📊 統計
  合計追加: +N / 削除: −M
  コミット数: N件
  コミュニティIssue参照: N件
```

### 3. Save & Update Navigation
- Write to `summaries/YYYY-MM-DD.md`
- Append entry to `index.md` under `## Daily Summaries`
- Update `Last updated` date and page count

### 4. Commit & Push
```bash
cd "$WIKI"
git add -A
git commit -m "summary: daily update YYYY-MM-DD"
git push
```

If no updates: write body "昨日の更新はありませんでした".

---

## Part III — Browser Tactics for Wiki Ingestion

### JS-Rendered SPA Extraction
Many docs sites are client-rendered. `curl` returns empty shells.

**Pattern**: `browser_navigate(url)` then `browser_console(expression="...")`

| Site | Selector |
|---|---|
| Anthropic docs | `document.querySelector('main article').innerText` |
| Generic blogs | `document.querySelector('article').innerText` |
| Fallback | `document.querySelector('main').innerText` |
| Last resort | `document.body.innerText` |

Always check extracted text length (<500 chars → try another selector).

### Community Sentiment from Hacker News
```javascript
// After browser_navigate to HN thread
const comments = [...document.querySelectorAll('.commtext')]
  .map(el => el.innerText.trim())
  .filter(t => t.length > 20);
JSON.stringify(comments);
```
For large threads, scroll repeatedly (`browser_scroll(direction="down")`) and deduplicate.

**Analysis cues**:
- Rank complaints by frequency (cost, API changes, pricing).
- Note official rep replies (look for company name in username).
- Capture crystallizing quotes.

### Reddit Limitations
Reddit actively blocks headless browsers. Use search-engine cached results or skip Reddit and rely on HN instead.

### delegate_task for Web Research Is Unreliable
Subagents with `web` toolset often return empty/no-op results. Do web research directly:
- `browser_navigate` + `browser_console` for content extraction
- Save subagents for CPU-bound work (data processing, code generation)

### Browser Environment Repair (Playwright/Chromium)
**Symptom**: `libglib-2.0.so.0: not found` → browser fails silently.  
**Fix**:
```bash
npx playwright install-deps chromium
```
**Verification**:
```bash
ldd ~/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell | grep "not found"
```
Should return empty.

### Search Engine Bot-Detection Fallback
If search engines serve CAPTCHAs or rate-limit pages:
1. **Stop** using generic web search immediately.
2. **Navigate directly** to the known authoritative URL.
3. **curl fallback** with realistic User-Agent if `browser_console` returns empty:
   ```bash
   curl -sL -A 'Mozilla/5.0 ...' "https://example.com/page" | sed 's/<[^]>*>//g' | tr -s '\n' | head -n 500
   ```
4. **Never fabricate** — report source failure rather than hallucinating content.

**Key lesson (2026-04-22 incident)**: DuckDuckGo returned CAPTCHA, Google returned rate-limit. The correct fix was to ignore search engines entirely, navigate directly, and use `curl` fallback when JS extraction failed.

---

## Pitfalls

- **Never skip orientation** — reading `SCHEMA.md` + `index.md` + `log.md` prevents duplicates.
- **Never modify `raw/` source files** — corrections go in wiki pages.
- **Count wikilinks only from added lines** — filter diff lines starting with `+`.
- **Deduplicate HN comments** across pagination.
- **Self-links and anchor links** (e.g., `[[page#section]]`) do not count as cross-references.
- **Update `index.md` totals** when adding new summary pages.
- **Verify git push** — an unpushed commit is a lost commit.
- **Subagent research may hit bot detection** — verify browser health with `ldd` before trusting results.
- **Empty response from `browser_console`** usually means missing shared library or wrong selector.

---

## Related Skills
- `hermes-infrastructure-operations` — cron diagnosis and model hallucination recovery.
- `physical-evidence-and-verification` — cross-check git status and file contents after every automated step.
- `llm-wiki` — canonical schema and page taxonomy for the wiki.
