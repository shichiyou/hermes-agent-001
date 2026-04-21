---
name: wiki-research-browser
description: "Browser-based research tactics for wiki ingestion — JS-rendered pages, community sentiment extraction, and forum scraping patterns."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [wiki, research, browser, scraping, community-sentiment]
    category: research
    related_skills: [llm-wiki]
---

# Wiki Research Browser Tactics

Practical techniques for extracting content from modern web sources during wiki
ingestion. These patterns were developed through real trial-and-error during
daily wiki research updates.

## When This Skill Activates

Use this skill when:
- Ingesting web sources into a wiki (or any knowledge base)
- The source URL is a JS-rendered SPA (docs sites, blog platforms)
- You need community sentiment from forums (HN, Reddit, etc.)
- curl/wget returns empty or minimal HTML shells
- delegate_task subagents fail to return web research results

## JS-Rendered Page Extraction

Many modern docs sites (docs.anthropic.com, docs.openai.com, etc.) are
client-rendered SPAs. curl returns an empty HTML shell with no content.

**Reliable pattern: browser_navigate + browser_console**

```
1. browser_navigate(url)
2. browser_console(expression="document.querySelector('main article').innerText")
```

The `querySelector` selector varies by site:
- Anthropic docs: `document.querySelector('main article').innerText`
- Generic blogs: `document.querySelector('article').innerText`
- Fallback: `document.querySelector('main').innerText`
- Last resort: `document.body.innerText`

**Tip:** Always check the length of the returned text. If it's suspiciously short
(<500 chars for a docs page), try a different selector.

## Community Sentiment from Hacker News

HN threads are gold mines for community feedback on tech products/launches.

**Bulk comment extraction:**
```javascript
// In browser_console after navigating to HN thread
const comments = [...document.querySelectorAll('.commtext')].map(el => el.innerText.trim()).filter(t => t.length > 20);
JSON.stringify(comments);
```

For large threads (500+ comments), HN paginates. You may need to:
1. Scroll down repeatedly with `browser_scroll(direction="down")`
2. Re-extract comments (deduplicate by content)
3. Or navigate to the "next" page link

**Analysis tips:**
- Sort by frequency of complaint topics (token cost, API changes, pricing)
- Note when official reps reply (look for "anthropic" or company name in usernames)
- Capture specific quotes that crystallize common sentiment

## Reddit Limitations

Reddit actively blocks headless/automated browsers:
- Returns "blocked by network security" or rate-limit pages
- old.reddit.com also returns minimal HTML
- Search engines may index Reddit content — use those instead

**Workaround:** Search for `site:reddit.com <topic>` via web search, then try
opening specific post URLs. Or skip Reddit entirely and use HN, which is
 scraper-friendly.

## delegate_task for Web Research Is Unreliable

Subagents with the `web` toolset often return empty/no-op results for web
research tasks. This was confirmed across multiple attempts during wiki updates.

**Recommendation:** Do web research directly:
- `browser_navigate` + `browser_console` for content extraction
- `browser_snapshot` for quick page overview
- Save subagents for CPU-bound work (data processing, code generation)

## Common Source Patterns

| Source Type | Tool | Selector / Method |
|-------------|------|-------------------|
| JS-rendered docs | browser_console | `document.querySelector('main article').innerText` |
| Static blog post | curl or browser | `curl -sL <url> \| html2text` |
| HN thread | browser_console | `document.querySelectorAll('.commtext')` |
| PDF | browser_navigate | Download URL, extract via docs |
| GitHub README | curl | Raw URL: `raw.githubusercontent.com` |
| Twitter/X | browser | Navigate to user/status URL |

## Pitfalls

- **Don't rely on curl for SPAs** — always try browser if curl returns <500 chars
- **Don't use delegate_task for web research** — it's unreliable; do it directly
- **Don't extract from Reddit headless** — use search engine cached results or HN instead
- **Do check extracted text length** — short output usually means wrong selector
- **Do deduplicate HN comments** — paginated extraction can produce duplicates
- **Do capture official responses** — company rep replies in community threads are high-signal