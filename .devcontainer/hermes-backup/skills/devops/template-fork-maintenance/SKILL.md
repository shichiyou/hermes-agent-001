---
name: template-fork-maintenance
description: >
  Post-fork maintenance protocol after creating a repository from a template.
  Covers hardcoded reference audit (repo-name, paths, container names,
  package metadata), lock-file updates, cron prompt fixes, backup-directory
  synchronization, and verification.
triggers:
  - Created a repo from "Use this template" or forked a template repo
  - Renamed a repository after fork/template creation
  - Detected hardcoded old repo names in lifecycle scripts or docs
version: 1.0.0
metadata:
  hermes:
    tags: [devops, git, template, fork, maintenance, rename]
    related_skills:
      - workspace-hygiene-and-git-discipline
      - experience-repository-setup
---

# Template Fork Maintenance — Hardcoded Reference Replacement

## Trigger

- テンプレートリポジトリから "Use this template" または fork で新規リポジトリを作成した後
- リポジトリ名変更後に旧名が残存していると気づいた場合
- `.devcontainer/` ライフサイクルスクリプト、ドキュメント、パッケージ名に旧名が残っている疑いがある場合

## Overview

テンプレートリポジトリから派生したリポジトリには、旧リポジトリ名が多数のファイルにハードコードされたまま残存している。これらを修正しないと：

- コンテナ起動・再起動時にパス不整合でエラー
- cron ジョブ実行時に `cd` 失敗
- DevContainer ボリューム名・コンテナ名の不一致
- ドキュメント・メモリ内の不正確なパス参照

## Execution Steps

### Step 0: Prepare

1. **リモートURL確認**: `git remote -v` で現在のリポジトリ名を確認
2. **物理パス確認**: `pwd` で実際のワークスペースパスを確認（`/workspaces/<repo-name>`）

### Step 1: Physical Scan

```bash
grep -rn "<OLD_NAME>" --exclude-dir=.git --exclude-dir=wiki \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.hermes .
```

`<OLD_NAME>`: テンプレート元の名前（例: `hermes-agent-template`, `hermes-agent-lab`）

**重点対象ファイル**: `.devcontainer/on-create.sh`, `.devcontainer/post-start.sh`, `.devcontainer/scripts/backup-hermes-config.sh`, `docs/`, `AGENTS.md`

### Step 2: Prioritized Replacement

| 優先度 | 対象 | 例 |
|--------|------|-----|
| **A** | `.devcontainer/on-create.sh` symlink パス | `/workspaces/<旧名>/wiki` |
| **A** | `.devcontainer/post-start.sh` バックアップパス | `git -C /workspaces/<旧名> add ...` |
| **A** | `.devcontainer/scripts/backup-hermes-config.sh` | `WIKI_PATH`, symlink テンプレート |
| **A** | `~/.hermes/cron/jobs.json`（実行元） | cron prompt 内の旧名 |
| **A** | `.devcontainer/hermes-backup/cron/jobs.json` | cron prompt 内の旧名 |
| **B** | `.devcontainer/devcontainer.json` | `"name": "<旧名>"` |
| **C** | `package.json`, `package-lock.json` | `"name": "<旧名>"` |
| **C** | `pyproject.toml`, `uv.lock` | `name = "<旧名>"` |
| **D** | `docs/`, `AGENTS.md`, `log.md` | ドキュメント内参照 |
| **D** | `.devcontainer/hermes-backup/skills/` | スキルファイル内パス |

### Step 3: Backup Directory Synchronization

`.devcontainer/hermes-backup/` は `backup-hermes-config.sh` の**出力先である**。手動でファイルを編集してはいけない。

```bash
cd <WORKSPACE_ROOT> && bash .devcontainer/scripts/backup-hermes-config.sh
```

この実行で以下が再生成される：
- `bashrc-additions.sh`（WIKI_PATH, symlink）
- `cron/jobs.json`
- `.env` テンプレート
- `memories/MEMORY.md`
- カスタムスキル群

### Step 4: Verification (Hard Gate)

```bash
cd /workspaces/<NEW_NAME> && \
grep -rn "<OLD_NAME>" --exclude-dir=.git --exclude-dir=wiki \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.hermes . | wc -l
# Expected: 0
grep -rn "<OLD_NAME>_2" --exclude-dir=.git --exclude-dir=wiki \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.hermes . | wc -l
# Expected: 0 (重複修正ミス防止)
```

### Step 5: Commit and Push

```bash
git add . && git status --short
git diff --stat  # 変更ファイル一覧確認
git commit -m "fix: replace old repo names (<old>) with <new>"
git push origin main
```

## Pitfalls

1. **Lock files must be updated**: `package-lock.json`（2箇所）と `uv.lock`（1箇所）は `name` フィールドに旧名を含む。`npm`/`uv` 再生成ではなく `sed` で置換可能。
2. **Two-sided cron fix**: `~/.hermes/cron/jobs.json`（実行元）と `.devcontainer/hermes-backup/cron/jobs.json`（バックアップ）の両方を修正する必要がある。`~/.hermes/cron/jobs.json` は `cronjob(action='update')` で更新されず手動編集が必要。
3. **`.devcontainer/hermes-backup/skills/.archive/`**: バックアップスクリプトは旧スキルを `.archive/` に移動する。`.archive/` 内のファイルも旧名を含む可能性がある。
4. **Wiki entries remain as-is**: `wiki/` はサブモジュールであり、固有名詞としての「テンプレートリポジトリ名」言及は修正不要。
5. **Do not double-replace**: 同じ置換を2回実行すると「`/workspaces/hermes-agent-001` → `hermes-agent-001_2`」のような壊れた文字列が生成される。`read_file` で現在の内容を確認してから `sed` するか、`sed` 実行後に grep で検証する。
6. **`.devcontainer/hermes-backup/bashrc-additions.sh`**: 手動編集ではなく backup スクリプト再生成で更新。

## Related

- `workspace-hygiene-and-git-discipline` — 親リポジトリ汚染防止
- `experience-repository-setup` — Git サブモジュールを使った隔離実験リポジトリセットアップ