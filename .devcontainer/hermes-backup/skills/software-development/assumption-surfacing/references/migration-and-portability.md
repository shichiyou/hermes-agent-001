# Migration and Portability Notes

## Skill Provenance

- **Origin**: Cole Medin, "Principles of Agentic Engineering" (2026-04-28 workshop)
- **Golden Rule #2**: "Reduce assumptions" — PRD前に質問、Jira前にPRDレビュー、実行前に計画レビュー
- **Generalization**: User pointed out (2026-04-30) that this principle is not limited to greenfield development — it applies to ALL task types (bug fixes, refactoring, docs, config changes, etc.)
- **Rename**: Initially created as `describe-clarify` (new-development-only), renamed to `assumption-surfacing` (always-on) to reflect the generalized scope

## Backup Location

```
.devcontainer/hermes-backup/skills/software-development/assumption-surfacing/SKILL.md
```

Auto-synced by hourly cron and boot-time backup script. See `hermes-devcontainer-persistence` skill.

## Cross-Environment Installation

### Hermes Agent Environment

Paste the following into a new session:

```
以下のスキルをインストールしてください。

スキル名: assumption-surfacing
カテゴリ: software-development
パス: ~/.hermes/skills/software-development/assumption-surfacing/SKILL.md

SKILL.mdの内容は、以下のGitHubリポジトリから取得してください:
https://github.com/shichiyou/hermes-agent-lab
パス: .devcontainer/hermes-backup/skills/software-development/assumption-surfacing/SKILL.md

取得コマンド例:
gh api /repos/shichiyou/hermes-agent-lab/contents/.devcontainer/hermes-backup/skills/software-development/assumption-surfacing/SKILL.md --jq .content | base64 -d
```

### Non-Hermes AI Agent Environments

Compressed ~40-line version for AGENTS.md / CLAUDE.md / .cursorrules / system prompt injection. See the "パターン2" section in `wiki/concepts/assumption-surfacing.md`.

### Private Repository Access

Both `shichiyou/hermes-agent-lab` and `shichiyou/wiki` are Private. Access requires:
- `gh auth login` (browser-based OAuth)
- Or SSH key with read access to the repository

## Integration with ai-agent-conduct

`ai-agent-conduct` was patched to add:
1. Frontmatter `related_skills` list: added `assumption-surfacing`
2. Body: "Assumption Surfacing (mandatory for ambiguous requirements)" paragraph after Principle 2's 3-Point Check

This creates a complementary pair:
- `ai-agent-conduct` Principle 2 → "HOW (implementation method) unknown? Stop and ask."
- `assumption-surfacing` → "WHAT (requirement itself) ambiguous? Don't silently infer — propose or ask."