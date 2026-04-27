---
name: external-agent-skill-research
description: Research and assess external agent-facing skills/prompts from GitHub or similar repositories by inspecting raw SKILL files, repository metadata, history, and applicability to Hermes without writing to the user's wiki unless explicitly requested.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [research, skills, prompts, github, agent-instructions, evidence]
    related_skills: [github-repo-management, hermes-agent, thinking-framework]
---

# External Agent Skill Research

## When to use

Use this skill when the user asks to research, review, evaluate, compare, or summarize an external agent-facing skill, prompt package, `SKILL.md`, slash-command set, or AI-agent instruction repository, especially when the source is a GitHub URL.

Typical triggers:
- "このスキルについてリサーチして"
- "この GitHub の skill を調べて"
- "このプロンプト/CLAUDE.md/agent skill を評価して"
- "Hermes に取り込む価値があるか見て"

Do not write to the user's wiki, create commits, or install the skill unless the user explicitly asks for ingestion, installation, or wiki update.

If the user follows up after a research-only answer with "Wiki に追加", "Wiki に取り込んで", or equivalent, treat it as an explicit wiki-ingestion request for the same external skill. Load `llm-wiki`, orient on `SCHEMA.md` / `index.md` / recent `log.md`, preserve the raw skill source under `raw/articles/` with `source_url`, `ingested`, and body `sha256`, create or update a concept page, update `index.md` and `log.md`, verify wikilinks and raw hash, then commit the wiki changes. If the configured `WIKI_PATH` is missing but a known project wiki path exists from memory or project context, report the mismatch and use the physically existing wiki path rather than silently failing.

## Core principle

Treat the external skill as a reusable procedure, not just a README. Inspect the physical files and repository evidence first, then summarize the operational workflow, trigger conditions, risks, and Hermes applicability.

## Procedure

1. Load relevant support skills first
   - `github-repo-management` for GitHub API/raw-file inspection.
   - `hermes-agent` if the assessment involves Hermes skill compatibility or installation.
   - `thinking-framework` for structured analysis if the user asks for evaluation or adoption judgment.

2. Identify the target class and physical location
   - Parse owner, repository, branch if provided, and subdirectory path.
   - Use GitHub API or raw URLs to list files in the exact target directory.
   - Prefer API/raw evidence over rendered GitHub HTML.

3. Capture physical evidence
   - Directory listing: file names and raw download URLs.
   - Repository metadata: description, default branch, stars/forks/issues if relevant.
   - Recent commits for the target path when history matters.
   - File size/hash/headings for the primary skill file when useful.

4. Read the primary instruction files
   - Prefer local-language files when available for the user, for example `SKILL-ja.md` for Japanese users.
   - Also inspect `SKILL.md` if it may differ materially from the localized file.
   - Extract frontmatter `name` and `description`, then compare description claims with body coverage.

5. Analyze class-first
   - Identify what class of task the external skill supports.
   - Extract when-to-use / when-not-to-use triggers.
   - Summarize the workflow as operational steps, not marketing language.
   - Identify evaluation metrics, artifacts, required tools, and environment assumptions.

6. Assess applicability to Hermes
   - Map foreign tool names to Hermes equivalents where possible, for example:
     - Claude Task tool / Agent dispatch → `delegate_task`
     - skill patching → `skill_manage(action="patch")`
     - file reads/searches → `read_file` / `search_files`
   - Explicitly state gaps where metadata or tool behavior is not equivalent, for example unavailable `tool_uses` or `duration_ms` fields.
   - Do not claim compatibility without evidence.

7. Report in the user's preferred evidence-first style
   - Conclusion first.
   - Physical evidence with raw output excerpts.
   - Structured summary tables in Japanese when the user uses Japanese.
   - Operational value, risks, and adoption recommendations.
   - State whether any wiki/write/install action was intentionally not performed.

## Useful commands

List a GitHub directory via API:

```bash
python3 - <<'PY'
import urllib.request, json
url='https://api.github.com/repos/OWNER/REPO/contents/PATH'
with urllib.request.urlopen(url) as r:
    data=json.load(r)
for item in data:
    print(item['type'], item['name'], item['download_url'] or item['html_url'])
PY
```

Read raw files:

```bash
python3 - <<'PY'
import urllib.request
urls=[
  ('SKILL.md','https://raw.githubusercontent.com/OWNER/REPO/BRANCH/PATH/SKILL.md'),
]
for name,url in urls:
    print(f'===== {name} =====')
    print(urllib.request.urlopen(url).read().decode('utf-8')[:12000])
PY
```

Repository metadata and path history:

```bash
python3 - <<'PY'
import urllib.request, json
for label,url in {
  'repo':'https://api.github.com/repos/OWNER/REPO',
  'commits_path':'https://api.github.com/repos/OWNER/REPO/commits?path=PATH&per_page=5',
}.items():
    print('===== '+label+' =====')
    with urllib.request.urlopen(url) as r:
        data=json.load(r)
    if label == 'repo':
        for k in ['full_name','description','html_url','default_branch','stargazers_count','forks_count','open_issues_count','updated_at','pushed_at']:
            print(f'{k}: {data.get(k)}')
    else:
        for c in data:
            print(c['sha'][:12], c['commit']['author']['date'], c['commit']['message'].split('\n')[0])
PY
```

File headings and hash:

```bash
python3 - <<'PY'
import urllib.request, hashlib
url='https://raw.githubusercontent.com/OWNER/REPO/BRANCH/PATH/SKILL.md'
text=urllib.request.urlopen(url).read().decode('utf-8')
print('bytes', len(text.encode('utf-8')))
print('chars', len(text))
print('sha256', hashlib.sha256(text.encode('utf-8')).hexdigest())
print('headings:')
for line in text.splitlines():
    if line.startswith('#'):
        print(line)
PY
```

## Pitfalls

- Do not summarize from GitHub's rendered page alone; use raw/API evidence.
- Do not install, import, or write to the wiki unless the user explicitly requests it.
- Do not confuse repository management with skill evaluation; repository metadata is supporting evidence, not the main analysis.
- Do not overclaim Hermes compatibility when the external skill assumes another agent's usage metadata or dispatch semantics.
- If localized and English files both exist, note which one was used as the primary source.
