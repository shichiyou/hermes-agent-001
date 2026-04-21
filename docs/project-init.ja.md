# プロジェクト初期化手順書

このドキュメントは `ai-devcontainer-baseline` をテンプレートとして新規プロジェクトを
立ち上げる際の手順書です。英語版は [project-init.md](project-init.md) にあります。

初期化作業を AI コーディングエージェントに委譲する場合は、
[.github/prompts/project-init.prompt.md](../.github/prompts/project-init.prompt.md)
を使用してください。

## 概要

`ai-devcontainer-baseline` はアプリケーションではなく、コピーして使う開始点です。
実際のプロジェクトで使用する手順は以下の通りです。

1. リポジトリの内容を Git 履歴なしでコピーする
2. 作業フォルダ名を決める（Dev Container の Home ボリューム名を決定する）
3. テンプレート固有の識別子（著者、パッケージ名、CODEOWNERS）を置換する
4. 任意でロケール、タイムゾーン、ツールバージョンを調整する
5. 新規 Git リポジトリを作成し、GitHub に push する
6. Dev Container で開き、ベースラインを検証する

この全工程は Dev Container 起動**前**のホスト側で実行します。

## 前提条件

- Git
- Docker Desktop または互換性のある Docker エンジン
- VS Code と Dev Containers 拡張機能
- アカウントまたは Organization で認証済みの GitHub CLI（`gh`）

## Step 1: リポジトリをコピーする

以下のいずれかの方法を選択してください。すべての方法でテンプレートへの Git 履歴参照を
残さない新規作業コピーが得られます。

### 方法 A: GitHub CLI（推奨）

```bash
gh repo clone shichiyou/ai-devcontainer-baseline <新フォルダ名> -- --depth 1
rm -rf <新フォルダ名>/.git
git -C <新フォルダ名> init -b main
```

### 方法 B: "Use this template" ボタン

GitHub のリポジトリページで **Use this template → Create a new repository** を
クリックし、作成された新リポジトリをローカルにクローンします。

### 方法 C: ZIP ダウンロード

GitHub から ZIP をダウンロードして展開し、フォルダ名を変更してから
`git init -b main` を実行します。

## Step 2: フォルダ名を決定する

Dev Container はワークスペースフォルダ名を基にして `/home/vscode` 用の
Named Docker ボリュームを作成します。

具体的には [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) が
以下のコマンドを実行します。

```text
docker volume create devcontainer-home-${localWorkspaceFolderBasename}
```

さらに `.devcontainer/.env` に
`DEVCONTAINER_HOME_VOLUME=devcontainer-home-<フォルダ名>` を書き出し、
[.devcontainer/docker-compose.yml](../.devcontainer/docker-compose.yml) が
これを参照します。

**影響:**

- フォルダ名が異なれば Home ボリュームも別になります。同一ホスト上の複数プロジェクトが
  干渉しません。
- 初回コンテナ起動**後**にフォルダ名を変更すると、古い Home ボリュームが孤立します。
  Step 7 の前に最終的なフォルダ名を決定してください。

## Step 3: 必須の書き換え

テンプレート固有の識別子をプロジェクトの値に置換します。

| ファイル | フィールドまたは文字列 | 置換後 |
|---|---|---|
| [CODEOWNERS](../CODEOWNERS) | `@tanaka-yasunobu`（全行） | `@<GITHUB_USERNAME>` |
| [package.json](../package.json) | `"name": "monorepo"` | `"name": "<PROJECT_NAME>"` |
| [package.json](../package.json) | `"author": "Tanaka Yasunobu"` | `"author": "<AUTHOR_NAME>"` |
| [pyproject.toml](../pyproject.toml) | `name = "monorepo"` | `name = "<PROJECT_NAME>"` |
| [pyproject.toml](../pyproject.toml) | `description = "Python/TypeScript monorepo workspace"` | プロジェクトの説明 |
| [pyproject.toml](../pyproject.toml) | `authors = [{ name = "Tanaka Yasunobu" }]` | `authors = [{ name = "<AUTHOR_NAME>" }]` |
| [LICENSE](../LICENSE) | `Copyright (c) 2026 Tanaka Yasunobu` | `Copyright (c) <YEAR> <AUTHOR_NAME>` |
| [README.md](../README.md) | タイトル・説明・著者表記 | プロジェクトのテキスト |
| [docs/README.ja.md](README.ja.md) | 同上（日本語版） | プロジェクトのテキスト |
| [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) | `"name": "Ubuntu Dev Container"` | `"name": "<コンテナ表示名>"` |

作業完了後、残存している識別子がないことを確認します。

```bash
grep -rn "tanaka-yasunobu\|Tanaka Yasunobu\|\"monorepo\"\|name = \"monorepo\"" \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.git .
```

Step 3 完了時点でソースファイルにマッチがあってはなりません。

## Step 4: 任意の書き換え

既定値のままでも動作しますが、チームに合わせて調整できます。

| 対象 | ファイル | 既定値 |
|---|---|---|
| ロケール | `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile` | `en_US.UTF-8` |
| タイムゾーン | `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile` | `Etc/UTC` |
| Node.js / Python / CLI バージョン | `.devcontainer/devcontainer.json` の features, `.devcontainer/Dockerfile` の ARG | 各ファイル参照 |
| AI エージェントポリシー | `.github/copilot-instructions.md`, `AGENTS.md`, `.claude/settings.json`, `.codex/rules/default.rules` | 厳格な日英バイリンガルポリシー、`.secrets/` ディレクトリ保護 |

ロケール、タイムゾーン、Home ボリューム挙動、worktree、AI 統合、アップデート戦略の
詳細は [customization.md](customization.md) を参照してください。

## Step 5: GitHub リポジトリを作成する

新しいプロジェクトフォルダ内で実行します。

```bash
gh repo create <OWNER>/<REPO_NAME> --private --source=. --remote=origin
```

公開リポジトリにする場合は `--public` を指定します。
このコマンドが GitHub 上のリポジトリ作成と `origin` の設定を同時に行います。

## Step 6: 初回コミットと push

```bash
git add -A
git commit -m "chore: initialize from ai-devcontainer-baseline"
git push -u origin main
```

実行後に状態を確認します。

```bash
git log --oneline -1
git status
```

いずれも初回コミットが存在し、作業ツリーがクリーンであることを示すはずです。

## Step 7: Dev Container で開く

1. 新しいフォルダを VS Code で開きます。
2. コマンド **Dev Containers: Reopen in Container** を実行します。
3. `.devcontainer/post-create.sh` の完了を待ちます（バージョン pin の更新と AI CLI の
   インストールを行います）。

## Step 8: ベースラインを検証する

Dev Container 内で以下を実行します。

```bash
npm ci
uv sync --dev
npm run lint
npm run test:shells
npm run test
```

これらは [.github/workflows/ci.yml](../.github/workflows/ci.yml) の smoke CI と
同一です。5 つのコマンドすべてがエラーなく完了する必要があります。

## トラブルシューティング

### 他プロジェクトと Home ボリュームが衝突する

フォルダ名ごとに `devcontainer-home-<フォルダ名>` が対応します。過去の派生と同名の
フォルダ名を使うと古い Home 状態を引き継いでしまう可能性があります。コンテナを
開く前に古いボリュームを削除してください。

```bash
docker volume rm devcontainer-home-<古いフォルダ名>
```

### `initializeCommand` で `docker volume create` が失敗する

`devcontainer.json` の `initializeCommand` はボリューム作成エラーを抑制しますが、
`.devcontainer/.env` が書き込まれない場合、compose ステップは汎用の
`devcontainer-home` ボリュームにフォールバックします。
**Dev Containers: Rebuild Container** を実行して `initializeCommand` を再実行して
ください。

### `gh repo create` が認証エラーで失敗する

`gh auth login` を実行し、指定した owner でリポジトリを作成する権限があることを
確認してください。

## 次のステップ

- [customization.md](customization.md) でロケール、タイムゾーン、AI ツールの既定値を
  確認してください。
- `apps/` と `packages/` にプロジェクトコードを配置してください。
- `.github/copilot-instructions.md` と `AGENTS.md` をチームのポリシーに合わせて
  調整してください。
