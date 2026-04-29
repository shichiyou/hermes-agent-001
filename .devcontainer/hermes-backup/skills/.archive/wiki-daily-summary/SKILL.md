---
name: wiki-daily-summary
description: "Generate and commit a daily update summary for an LLM Wiki from git history and log entries."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [wiki, summary, cron, daily-update, git]
    category: research
    related_skills: [llm-wiki]
---

# Wiki Daily Summary Generator

Generate a daily summary of wiki changes from git history and the wiki's log.md,
save it to `summaries/YYYY-MM-DD.md`, update index.md, and push.

Designed to run as an unattended cron job — no user interaction needed.

## When This Skill Activates

- Scheduled cron job for daily wiki summary
- User asks to generate a daily/weekly update summary for their wiki
- User asks "what changed in the wiki recently?"

## Prerequisites

- A wiki managed by the `llm-wiki` skill (with git tracking)
- `WIKI_PATH` env var set (defaults to `~/wiki`)

## Procedure

### 1. Orient

```bash
WIKI="${WIKI_PATH:-$HOME/wiki}"
```

Read current state:
- `read_file "$WIKI/log.md"` — recent update entries
- `read_file "$WIKI/index.md"` — current page catalog
- `git log --oneline --since="24 hours ago"` — commits in window

### 2. Compute Diffs

Find the parent of the oldest commit in the 24h window:

```bash
# Get oldest commit in range
OLDEST=$(git log --format="%H" --since="24 hours ago" | tail -1)
BEFORE=$(git log --format="%H" "${OLDEST}~1" -1)
```

Then:

| Metric | Command |
|--------|---------|
| Aggregate +/- lines | `git diff --shortstat $BEFORE HEAD` |
| Per-file stats | `git diff --stat $BEFORE HEAD` |
| Per-file line count (before) | `git show $BEFORE:entities/X.md \| wc -l` |
| Per-file line count (after) | `git show HEAD:entities/X.md \| wc -l` |
| New wikilinks | regex `[[...]]` on added lines in diff |
| CVE references | regex `CVE-\d{4}-\d+` on added lines |
| Community issues | regex `#\d+` / `Issue #\d+` on added lines |

Use `execute_code` for batch processing — loop over entity files, parse diffs programmatically.

### 3. Format Summary

Use this template (Japanese, engineer-oriented):

```markdown
---
title: Daily Update Summary YYYY-MM-DD
created: YYYY-MM-DD
updated: YYYY-MM-DD
type: query
tags: [summary, daily-update]
sources: [log.md]
---

# 📋 LLM Wiki 日次更新サマリ — [YYYY-MM-DD]

[N]ページ更新

🔄 更新ページ

🟢 [page-name]
  [old lines]行→[new lines]行（+Δ行）
  [2-3 line summary of key additions]
  [Highlight CVEs or critical community findings ⚠️]

（更新がないページは省略）

📊 統計
  合計追加行数: +N / 削除: -M
  コミット数: N本
  クロスリファレンス更新: N件
  コミュニティIssue参照: N+件

⏱ 次回更新: [翌日] 09:00 UTC〜
```

If no updates: write "昨日の更新はありませんでした" as the summary body.

### 4. Save & Update Navigation

```bash
mkdir -p "$WIKI/summaries"
# Save to summaries/YYYY-MM-DD.md
```

Update `index.md`:
- Add `## Daily Summaries` section if missing
- Append entry: `- [[summaries/YYYY-MM-DD]] one-line summary`
- Update header: `Last updated` date and `Total pages` count

### 5. Commit & Push

```bash
git add -A
git commit -m "summary: daily update YYYY-MM-DD"
git push
```

**Verify:**
- `git log --oneline -1` shows the new commit
- `git push` output shows `main -> main` with the correct SHA range

## Pitfalls

- **Always find the correct BEFORE commit** — it's the parent of the oldest commit in the 24h window, not just HEAD~N. Commits may vary in count.
- **Don't modify `raw/` files** — sources are immutable per llm-wiki rules.
- **Count wikilinks only from added lines** — removed lines with `[[...]]` are deletions, not new cross-references. Filter diff lines starting with `+` (excluding `+++` headers).
- **Deduplicate issue CVE/issue references** across files — same CVE may appear in both the entity page and the raw source.
- **Self-links and anchor links** (e.g., `[[page#section]]`) should not count as cross-references.
- **Update Total pages count** in index.md header when adding the summaries section.
- **If git push fails**, don't silently continue — report the failure.