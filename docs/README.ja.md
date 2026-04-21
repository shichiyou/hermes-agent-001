# Python / TypeScript モノレポ Dev Container ベースライン

このドキュメントは日本語向けの概要です。正本の README は [README.md](../README.md) です。

## これは何か

このリポジトリは、Python と TypeScript のモノレポ向けに用意した VS Code Dev Container の
ベースラインです。再現しやすい開発環境、プロジェクトローカル依存、任意の AI CLI 統合を
まとめて扱えるようにしています。

アプリ本体ではなく、テンプレートまたは開始点として使う前提です。
このリポジトリを派生させて独自のベースラインを作る場合、locale、タイムゾーン、AI ツール、
Home ボリュームのデフォルト値はチームに合わせてカスタマイズしてください。

## 主な特徴

- VS Code Dev Container ベースライン
- Python と TypeScript のモノレポ前提
- `node_modules/` と `.venv/` をプロジェクトローカルに分離
- Claude Code、Codex、Copilot CLI、Ollama などの任意統合

## 誰向けか

- Python と TypeScript プロジェクトで統一された開発環境が必要なチーム
- グローバルなツールの分散を避けたい場合
- AI CLI ツールを任意で統合したいが、ベンダー固有のアカウントを全員に強制したくない場合

## クイックスタート

### 前提条件

- Docker Desktop または互換性のある Docker エンジン
- VS Code と Dev Containers 拡張機能

### ベースラインを開く

1. このリポジトリをクローンします。
2. VS Code で開きます。
3. 「Dev Containers: Reopen in Container」をクリックします。
4. `.devcontainer/post-create.sh` が `package.json`、`pyproject.toml`、`.devcontainer/devcontainer.json` の pin を更新し、lockfile の更新、依存同期、AI CLI ツール導入を終えるまで待ちます。
5. ベースライン確認コマンドを実行します：

```bash
npm ci
uv sync --dev
npm run lint
npm run test:shells
npm run test
```

これらのコマンドは [.github/workflows/ci.yml](../.github/workflows/ci.yml) の smoke CI ワークフローと同一です。

## プロジェクト構造

```text
.
├── .devcontainer/           # Dev Container 定義とセットアップスクリプト
│   ├── devcontainer.json    # コンテナ設定、Feature、拡張機能、環境変数
│   ├── Dockerfile           # ベースイメージ + システムツール
│   ├── on-create.sh         # 初回 Home ボリューム初期化
│   ├── post-create.sh       # プロジェクト依存同期と任意 AI CLI セットアップ
│   ├── post-start.sh        # 起動時バックグラウンドサービス確認
│   └── scripts/
│       ├── lib/            # 共有シェルスクリプトライブラリ
│       │   ├── logging.sh  # ログレベル付き統一ログ関数
│       │   ├── retry.sh    # 指数バックオフ付きリトライユーティリティ
│       │   ├── version.sh  # バージョン比較・正規化関数
│       │   └── workspace.sh # ワークスペース検出・検証ユーティリティ
│       └── update-tools.sh  # ツールアップデートヘルパー
├── apps/                    # アプリケーションワークスペース（空から開始可）
├── packages/                # 共有パッケージワークスペース（空から開始可）
├── docs/                    # Supporting documentation
├── tests/                   # bats ベースシェルスクリプトテスト
├── package.json             # npm workspace root
├── pyproject.toml           # uv workspace root
├── turbo.json               # Turborepo タスク定義
└── biome.json               # JS/TS フォーマット・lint 設定
```

`apps/` と `packages/` ディレクトリはモノレポ構造の一部です。 реальные パッケージやアプリケーションを
追加するまでは空のままです。

## テンプレートとして使う

このベースラインから新規プロジェクトを始める場合は、
[docs/project-init.ja.md](project-init.ja.md) に従ってください。リポジトリのコピー、
テンプレート固有の識別子の置換、GitHub リポジトリ作成、ベースラインの検証までを
一貫して説明しています。同じ手順を自動化する AI エージェント向けプロンプトは
[.github/prompts/project-init.prompt.md](../.github/prompts/project-init.prompt.md)
にあります。

## カスタマイズ

現在のベースラインは locale、タイムゾーン、Home ボリューム共有、AI ツール設定について
明示的なデフォルトを持っています。これらはリポジトリ固有の選択であり、普遍的な要件ではありません。

[docs/customization.md](customization.md) で以下を確認できます：

- locale とタイムゾーンのデフォルト
- Home ボリュームの動作
- worktree 使用
- 任意の AI 統合
- アップデート戦略とトレードオフ

## ツールのアップデート

コンテナを再ビルドせずにツールをリフレッシュできます：

```bash
update-tools.sh
update-tools.sh npm
update-tools.sh node-deps
update-tools.sh node-deps-check
update-tools.sh python-deps
update-tools.sh python-deps-check
update-tools.sh uv claude-code
./.devcontainer/scripts/check-package-updates.sh
./.devcontainer/scripts/check-python-package-updates.sh
update-tools.sh --list
update-tools.sh --versions
```

このアップデートヘルパーは、意図的に次の 3 種類の pin 更新をまとめて扱います：

- `package.json` と `pyproject.toml` の dependency pin 更新
- 次回 rebuild 用の `.devcontainer/devcontainer.json` の runtime pin 更新
- `node_modules/` と `.venv/` をそろえるための lockfile 更新と依存同期

実際には、`node-deps` は `package.json` の依存 pin を更新してから `npm update --package-lock-only` と `npm ci` を実行し、
`python-deps` は `pyproject.toml` の依存 pin を更新してから `uv lock --upgrade` と `uv sync --dev` を実行します。
また、`node`、`npm`、`python` の更新系は、次回 rebuild で使う runtime version も更新します。

`update-tools.sh` と `update-tools.sh --all` は、既定のツール更新だけを実行します。`node-deps` と
`python-deps` は、明示的に指定したときだけ実行されます。

`node-deps` と `python-deps` の manifest pin 更新は、既定で現在のメジャーバージョン内にとどまります。
Python 要件により厳しい上限が既にある場合は、その上限も維持します。

そのため、rebuild や worktree 同期の直後に `package.json`、`pyproject.toml`、`.devcontainer/devcontainer.json`、
`package-lock.json`、`uv.lock` が dirty になる場合があります。更新後の状態を CI や他の開発者とそろえたい場合は、
差分を確認してこれらのファイルを commit してください。

`node-deps-check` と `./.devcontainer/scripts/check-package-updates.sh` は、package.json のレンジ更新、
lockfile または `node_modules/` の同期だけで済む更新、`npm audit` の検出結果を分けて報告します。

`python-deps-check` と `./.devcontainer/scripts/check-python-package-updates.sh` は、Python 依存の
specifier 更新、`uv.lock` の更新候補、環境同期ずれ、`uv audit` の検出結果を分けて報告します。

## 共有ライブラリ

`.devcontainer/scripts/lib/` ディレクトリにはセットアップスクリプトから使われる
共有シェルスクリプトライブラリが含まれています：

- `logging.sh` - ログレベル（DEBUG、INFO、WARN、ERROR）付き統一ログ関数
- `retry.sh` - 指数バックオフ対応リトライユーティリティ
- `version.sh` - バージョン比較・正規化関数
- `workspace.sh` - ワークスペース検出・検証ユーティリティ

これらのライブラリは `on-create.sh`、`post-create.sh`、`post-start.sh`、`update-tools.sh` から
source されます。

## 検証と CI

GitHub Actions smoke CI は [.github/workflows/ci.yml](../.github/workflows/ci.yml) で定義されています。

現在の CI は以下を検証します：

- `.devcontainer/*.sh` の実行権限
- `npm ci`
- `uv sync --dev`
- `npm run lint`
- `npm run test:shells`
- `npm run test`

プルリクエストを開く前に、同じコマンドシーケンスをローカルで実行してください。

## ワークツリーワークフロー

このベースラインは `.worktree/` 以下に複数のワークツリーを保持し、
同じ共有 `/home/vscode` ボリュームを再利用することを前提としています。

例：

```bash
mkdir -p .worktree
git worktree add .worktree/feature-a -b feature-a
git worktree add .worktree/feature-b -b feature-b
```

新しいワークツリーを追加した場合は、そのワークツリー内で依存関係同期コマンドを実行してください。
`postCreateCommand` は Dev Container が作成されたときにのみ実行されるためです：

```bash
./.devcontainer/scripts/update-tools.sh node-deps
./.devcontainer/scripts/update-tools.sh node-deps-check
./.devcontainer/scripts/update-tools.sh python-deps
./.devcontainer/scripts/update-tools.sh python-deps-check
```

## トラブルシューティング

ワークツリーが依存関係缺失場合は、ローカル同期コマンドを再実行してください：

```bash
./.devcontainer/scripts/update-tools.sh node-deps python-deps
```

シェルスクリプトが `Permission denied` で失敗する場合は、実行権限を確認してください：

```bash
find .devcontainer -type f -name '*.sh' -exec test -x {} \; -print
```

コンテナ開始後に Ollama が応答しない場合は、ログを調査してください：

```bash
tail -n 20 ~/.local/state/ollama/post-start.log
tail -n 20 ~/.local/state/ollama/server.log
```

共有 Home 状態が矛盾している場合は、Docker ボリュームを削除してコンテナを開き直してください：

```bash
docker volume rm devcontainer-home
```

## コントリビュート

コントリビューターワークフローとリポジトリの期待は [CONTRIBUTING.md](../CONTRIBUTING.md) を参照してください。

## ライセンス

このリポジトリは [MIT ライセンス](../LICENSE) で公開されています。

[MIT](../LICENSE) © Tanaka Yasunobu

## 補足

現状のベースラインは `en_US.UTF-8` と `Etc/UTC` を既定値として持っています。
これは公開向けに中立化した選択ですが、派生テンプレートではチームや運用に合わせて変更できます。
たとえば日本語中心の業務環境なら `ja_JP.UTF-8` と `Asia/Tokyo` を使う構成も自然です。
