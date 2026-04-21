---
name: wiki-daily-research
description: "Automated daily research updates for LLM Wiki pages — parallel delegation, synthesis, and git persistence."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [wiki, research, cron, daily-update, automation]
    category: research
    related_skills: [llm-wiki]
---

# Wiki Daily Research Update

Automated daily research updates for existing wiki entity pages. Designed for
cron-driven execution with no user interaction.

## When This Skill Activates

Use when:
- Running a scheduled cron job to update a wiki page
- User asks for a "daily update" or "research update" on a wiki topic
- Automating periodic research for a specific entity in the wiki

## Prerequisites

- An existing wiki with `llm-wiki` skill structure (SCHEMA.md, index.md, log.md)
- Git configured for the wiki repository
- The target wiki page already exists

## Workflow

### 1. Orient (Every Session)

Read the wiki backbone before touching anything:
```
read_file SCHEMA.md
read_file index.md
read_file log.md (last 30 lines)
read_file entities/<target-page>.md
```

This prevents duplicates and ensures structural consistency.

### 2. Parallel Delegation (2 Subagents)

Use `delegate_task` with batch tasks for comprehensive coverage:

**Subagent A: Official Sources**
- Navigate to GitHub repo: releases, commits, issues, PRs, discussions pages
- Check: version, star/fork counts, new commits, new issues/PRs, new releases
- Check official blog posts and documentation updates
- Toolsets: `browser`
- Context: list what's already known (last version, last date, current star count)

**Subagent B: Community & Comparisons**
- Search HN, Reddit, dev.to, Zenn, Qiita, Medium, technical blogs
- Search queries: `"<name> review"`, `"<name> pitfalls"`, `"<name> vs"`, `"<name> issues"`
- Capture: sentiment, pain points, unofficial best practices, competitive alternatives
- Include "X vs" comparisons, benchmarks, pricing changes
- Toolsets: `browser`
- Context: list known issues, known bugs, existing comparison data

**CRITICAL: Always search non-English communities** (JP: Zenn/Qiita, CN: Juejin/CSDN).
Many projects (especially AWS/AI tools) have JP >> EN community activity. This asymmetry is
a meaningful adoption signal and frequently contains the deepest critical analysis.

Each subagent must receive:
- What's already in the wiki (so they don't re-discover it)
- The cutoff date (only find things since last update)
- The domain/tag taxonomy (stay in scope)

### 3. Synthesis

Merge subagent reports into the wiki page:

- **Separate official specs from community insights** — the canonical split is
  "Specifications & Features" (what it claims to do) vs "Community Insights & Pitfalls" (what it actually does)
- **Don't duplicate** existing content — only add net-new information
- **Mark resolved issues** — if a bug was fixed (PR merged), add resolution note
- **Update counts** — issue counts, version numbers, model counts
- **Preserve section structure** — don't reorganize between updates
- **Be specific** — issue numbers, PR numbers, comment counts, dates, URLs

### 4. Update Wiki Navigation

After updating the main page:

1. **index.md** — refresh the page's one-line summary if content changed significantly
2. **log.md** — append detailed entry:
   ```
   ## [YYYY-MM-DD] update | Page Name — Daily Research Update (Date)
   - Summary of what changed (bulleted)
   - Key new sections, new issues, resolved issues
   - Sources: list URLs and references
   ```

### 5. Git Commit and Push

```bash
cd $WIKI
git add -A
git commit -m "update: <page> daily research <date> - <brief summary>"
git push
```

Verify: `git log --oneline -1`

### 6. Silent When Nothing Changed

If all three subagents find genuinely nothing new since the last update,
respond with exactly `[SILENT]` — this suppresses delivery in cron contexts.
Do NOT write a no-op update to the wiki.

## Synthesis Rules

1. **Issue tracking**: Add new issues opened since last check. Mark resolved issues.
   Update total issue count.
2. **Controversy tracking**: When new HN/Reddit threads emerge, summarize
   sentiment split with rough percentages and key quotes.
3. **Model tracking**: New models added to library → add to model table.
   Track pull counts and release dates.
4. **Pricing changes**: Document exact tiers, limits, and what changed.
5. **Benchmark data**: Include specific numbers (tok/s, model, hardware).
   Prefer community-real benchmarks over marketing claims.
6. **Comparison updates**: When new competitors emerge, add them to comparison
   tables with relevant dimensions.

## Structured Section Pattern for Entity Pages

```
## Specifications & Features
### Platform Version History
### [Feature sections per domain]
### Hardware Support
### [Model/Product catalogs]

## Community Insights & Pitfalls
### Community Engagement Overview (table: platform, activity, sentiment)
### [Critical Analyses — name the source, quote key argument]
### [Core Debates — competing positions with comparative table]
### Pain Points (ranked: 🔴 High / 🟡 Medium / 🟢 Low)
### Unofficial Best Practices (numbered, community-sourced)
### Surprising Strengths / Weaknesses
### Comparison with Alternatives
```

**Key pattern: "Core Debates" section.** When the community has a fundamental
philosophical disagreement (e.g., "max human oversight" vs "min human intervention"),
document both sides with a comparative table. This is often the highest-value
content for engineers making adoption decisions.

## Pitfalls

- **Never skip orientation** — reading SCHEMA + index + log before updating prevents
  duplicates and structural inconsistencies
- **Never modify raw/ source files** — corrections go in wiki pages
- **Don't create pages for passing mentions** — follow Page Thresholds in SCHEMA.md
- **Don't rewrite existing structure** — add to it. Readers expect consistency.
- **Always git push** — an unpushed commit is a lost commit
- **Track issue status changes** — if a previously-open issue is now closed, note it
- **Avoid marketing language** — write for engineers making practical trade-off decisions
- **Subagents may hit bot detection** — Reddit, some search engines block automated access.
  If a subagent reports access issues, rely on GitHub/HN/Zenn instead.
- **Non-English communities can dominate** — for AWS/AI tools, JP (Zenn/Qiita) often has
  10-50× more content than EN platforms. If discovered, document this asymmetry: it signals
  where the project's actual adoption and critical analysis live.
- **Named sources > anonymous claims** — always attribute critical analyses to the specific
  author and platform (e.g., "kiakiraki (Zenn, Mar 2026)"), not "some blog post".
- **Quantify everything** — "131 Qiita articles" not "lots of articles"; "10-26 verification points"
  not "many checkpoints". Numbers enable future change detection.