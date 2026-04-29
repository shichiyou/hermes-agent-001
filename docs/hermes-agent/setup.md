# Hermes Agent 導入手順

本書は公式 `install.sh` を使って hermes-agent をこの devcontainer 上で動かすための再現手順をまとめる。
upstream を改造しない前提。

## 前提条件

- devcontainer の中で作業していること
- ネットワークから GitHub に到達できること（HTTPS、ポート443）
- `uv` と `git` が PATH にあること（ベースラインで導入済み）
- `ripgrep` (`rg`) が PATH にあること（この devcontainer ではベースラインで導入される想定）
- main ブランチへの直接作業を避け、feature ブランチで作業していること（例: `feature/integrate-hermes-agent`）

## 手順

### 1. 作業ブランチ確認

```bash
cd /workspaces/hermes-agent-001
git branch --show-current   # 期待: feature/integrate-hermes-agent
```

### 2. install.sh を実行

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

> **再現性に関する注意**: 上記 URL は upstream の `main` 先端を常に参照するため、
> 実行タイミングによって内容が変わる可能性があります。特定バージョンに固定したい場合は
> `main` をタグ（例: `v0.10.0`）またはコミット SHA に置き換えてください。
> 本ラボの検証は commit `436a7359`（v0.10.0）時点を基準としています。

install.sh が行うこと（静的分析済み、`findings.md` 参照）:

- `~/.hermes/hermes-agent/` に clone
- `~/.hermes/hermes-agent/venv/` に Python 3.11 venv を作成し `.[all]` をインストール
- `~/.local/bin/hermes` symlink を作成
- `~/.hermes/.env` / `config.yaml` / `SOUL.md` を雛形から生成
- `~/.hermes/{cron,sessions,logs,...}` ディレクトリを作成
- Node.js が未検出の場合は `~/.hermes/node/` に Node 22 LTS をインストール
- npm install + Playwright Chromium をインストール
- `hermes setup`（セットアップウィザード）を起動

`--skip-setup` を付けると setup wizard をスキップできる:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup
```

### 3. 動作確認

```bash
hermes --version   # 期待: Hermes Agent vX.Y.Z
hermes doctor      # 構成診断。警告内容を progress.md に記録
```

### 4. API キー設定

```bash
hermes setup
# または ~/.hermes/.env を直接編集して API キーを投入
```

キーは `~/.hermes/.env`（Home volume）に保存され、リポジトリには入らない。

### 5. 対話確認

```bash
hermes
# または
hermes chat
```

### 6. 記録

`docs/hermes-agent/progress.md` に当日の日付エントリを追加し、以下を残す:

- 実行したコマンドと出力（抜粋）
- `hermes --version` の出力
- `hermes doctor` の警告内容
- 未解決事項

## install.sh のインストール先

| 種別 | パス |
| ---- | ---- |
| ソース | `~/.hermes/hermes-agent/` |
| venv | `~/.hermes/hermes-agent/venv/` |
| 設定 | `~/.hermes/.env` / `~/.hermes/config.yaml` |
| ペルソナ | `~/.hermes/SOUL.md` |
| コマンド | `~/.local/bin/hermes` (symlink) |
| Node.js | `~/.hermes/node/` (未検出時のみ自動インストール) |

すべて Home volume（`devcontainer-home`）に載るため、コンテナ再ビルドで消えない。

## やり直し・クリーンアップ

venv だけ再作成する:

```bash
cd ~/.hermes/hermes-agent
rm -rf venv
uv venv venv --python 3.11
uv pip install -e ".[all]"
```

install.sh ですべてインストールしたものを除去する（手動）:

```bash
rm -rf ~/.hermes/hermes-agent   # ソースと venv
rm -rf ~/.hermes/node           # Node.js（install.sh が自動インストールした場合）
rm ~/.local/bin/hermes          # symlink
# ~/.hermes/.env / config.yaml / SOUL.md は設定ファイルのため手動判断
```

## トラブルシューティング

- **`hermes` が見つからない**: `~/.local/bin` が PATH に入っているか確認。`echo $PATH | tr ':' '\n' | grep local`
- **install.sh が途中で止まる**: ネットワーク到達性を確認。`curl -I https://github.com` が応答するか。
- **Node.js バージョン競合**: devcontainer には nvm 管理の Node 24 があるため、`~/.local/bin/node` が上書きされていないか確認。`which node` と `node --version` で確認。
