<!-- markdownlint-disable MD024 -->

# Hermes Agent Lab — 進捗ログ

`AGENTS.md` の Mandatory Cycle（仮説→証拠→実行→観測検証）と Hard Gates（観測検証なしに完了を
宣言しない）をそのままラボ運用に適用する。

各エントリのフォーマット：

```markdown
## YYYY-MM-DD: <見出し>

### 実施
- （実行したコマンド／変更）

### 観測
- （コマンド出力・バージョン・エラー等、観測事実のみ）

### 未解決
- （あれば）
```

---

<!-- エントリはここから下に時系列で追記する -->

## 2026-04-21: devcontainer baseline に ripgrep を追加

### 実施

- [.devcontainer/Dockerfile](../../.devcontainer/Dockerfile) のベース apt パッケージへ `ripgrep` を追加
- [docs/hermes-agent/setup.md](setup.md) の前提条件に `ripgrep` (`rg`) を追記
- `npm run test:shells` を実行

### 観測

- `npm run test:shells` は `63 tests, 0 failures, 2 skipped` を出力
- テンプレート側コミット `e861a7581ff0543a75e2800064e4c54ad3da18d6` の差分は 3 ファイルで、現リポジトリへ対応可能だった
- devcontainer リビルド後の観測: `command -v rg` → `/usr/bin/rg`
- devcontainer リビルド後の観測: `rg --version` → `ripgrep 14.1.0`
- devcontainer リビルド後の観測: `command -v hermes` → `/home/vscode/.local/bin/hermes`
- devcontainer リビルド後の観測: `hermes doctor | grep -i 'ripgrep (rg)'` → `✓ ripgrep (rg) (faster file search)`

### 未解決

- 特になし

## 2026-04-17: ラボ初期セットアップ

### 実施

- `feature/integrate-hermes-agent` ブランチ作成
- `.gitignore` に `external/` を追加
- `docs/hermes-agent/` 配下に README / setup / progress / findings を作成
- `git clone https://github.com/NousResearch/hermes-agent external/hermes-agent`
- `cd external/hermes-agent && uv venv .venv --python 3.11`
- `uv pip install --python .venv/bin/python -e ".[all,dev]"`
- `.venv/bin/hermes --version` / `--help` / `doctor` を実行

### 観測

- Clone: commit `436a7359` を HEAD として取得、サイズ 164M
- uv が CPython 3.11.15 を自動ダウンロード（ローカル未取得だったため）
- venv 作成後、`.venv/bin/python --version` → `Python 3.11.15`
- 依存解決: `Resolved 165 packages` で成功。`warning: Failed to hardlink files; falling back to full copy.`（性能注意、致命ではない）
- `hermes --version` 出力:

  ```text
  Hermes Agent v0.10.0 (2026.4.16)
  Project: /workspaces/hermes-agent-template/external/hermes-agent
  Python: 3.11.15
  OpenAI SDK: 2.32.0
  Up to date
  ```

- `hermes --help`: 30+ のサブコマンド（`chat`, `model`, `gateway`, `setup`, `doctor`, `mcp`, `skills`, `plugins`, `insights`, `acp` 他）を列挙。ヘルプ取得自体はエラーなし。
- `hermes doctor` exit code `0`。主な警告：
  - `~/.hermes/.env` 未作成 → 想定内（未対話セットアップ）
  - `config.yaml not found (using defaults)` → 想定内
  - `Nous Portal auth (not logged in)` / `Google Gemini OAuth (not logged in)` / `OpenRouter API (not configured)` → 想定内（今回は認証スコープ外）
  - `~/.local/bin/hermes not found` → venv 内 CLI のみで運用する方針のため想定内
  - `ripgrep (rg) not found` → 代替 grep で動く、当面は放置
  - `agent-browser not installed (run: npm install)` → upstream 側の npm 未実行、該当機能は今回未使用
  - `tinker-atropos not found` → RL extras は今回スコープ外、プラン通り
  - ツール可否: `moa`, `rl`, `messaging`, `vision`, `homeassistant`, `image_gen` が system dep or key 未整備。使用時に個別対応。
- venv 隔離確認：
  - ラボ本体 `/workspaces/hermes-agent-template/.venv/bin/python` → `Python 3.14.4`
  - hermes 専用 `/workspaces/hermes-agent-template/external/hermes-agent/.venv/bin/python` → `Python 3.11.15`
  - それぞれ独立した Python を参照している
- `.gitignore` 効果確認: `git check-ignore -v external/hermes-agent/.venv` が `.gitignore:59:external/` にヒット。`git status` はラボ側 `.gitignore` と `docs/hermes-agent/` のみ差分。

### 未解決

- 実 API キーを投入した `hermes chat` 等の対話セッションは未検証（今回スコープ外）。
- `hermes update` の動作・挙動は未確認（ラボでは手動 `git pull` 運用でよいか要判断）。
- `hardlink` 警告の実影響（次回以降の同一 venv 再構築で時間が増える可能性）。

---

## 2026-04-17: install.sh 静的分析・hermes グローバル化

### 実施（install.sh 分析）

- `scripts/install.sh` を全読解（静的分析）
- `ln -sf /workspaces/hermes-agent-template/external/hermes-agent/.venv/bin/hermes ~/.local/bin/hermes` を実行
- `which hermes` / `hermes --version` で動作確認
- Windows ホスト側から `docker run --rm -it ubuntu:24.04 bash -c '...'` を試みた（install.sh の実行環境検証）

### 観測（install.sh 分析）

- `which hermes` → `/home/vscode/.local/bin/hermes`（symlink 有効）
- `hermes --version` → `Hermes Agent v0.10.0 (2026.4.16) / Python 3.11.15`（venv 経由で正常起動）
- ホスト側 Docker での検証コマンドは `ubuntu:24.04` の apt が `archive.ubuntu.com:80` に接続拒否されて失敗。ポート 80 は devcontainer と同じネットワーク制約を受けている環境と判断。
- install.sh 静的読解の主な知見（詳細は `findings.md` 参照）:
  - clone 先: `~/.hermes/hermes-agent/`（lab の `external/` とは別）
  - venv 名: `venv/`（lab は `.venv/`）
  - extras: `.[all]` のみ（lab は `.[all,dev]`）
  - Node.js: `~/.local/bin/node` に Node 22 LTS symlink を作成 → nvm Node 24 との競合リスクあり
  - `~/.hermes/` ディレクトリ群 + `~/.hermes/.env` / `config.yaml` / `SOUL.md` を自動生成
  - symlink 作成ロジックは lab の手動 symlink と同等

### 未解決（install.sh 分析）

- ホスト側 Docker での install.sh 実行検証は未実施（ネットワーク制約により）。
- `~/.hermes/` の設定ディレクトリ未生成（`hermes doctor` が各種 "not found" 警告を出す状態）。API キー投入のタイミングで `hermes setup` を実行して生成予定。

---

## 2026-04-17: アプローチ変更・環境クリーンアップ

### 実施

- `~/.local/bin/hermes` symlink を削除（`rm ~/.local/bin/hermes`）
- `external/hermes-agent/` ディレクトリを削除（`rm -rf external/hermes-agent`）
- `.gitignore` から `external/` セクションを削除
- `docs/hermes-agent/setup.md` を install.sh 方式に書き直し
- `docs/hermes-agent/README.md` の位置づけ記述を更新

### 観測

- `which hermes` → not found（クリーン状態に戻った）
- `ls external/` → ディレクトリ消滅を確認

### 変更理由

fresh clone 方式（`external/` + `.venv/`）は Lab リポジトリの git 履歴を汚さない目的で
採用したが、結果として公式 QuickStart と乖離した手順になり、コア機能（LLM 対話）の
検証に至らなかった。install.sh 方式に切り替え、公式手順に沿った評価を行う。

### 未解決

- install.sh の実行および `hermes setup` による API キー設定が未実施。

---

## 2026-04-17: install.sh 実行・動作確認

### 実施

- `curl -fsSL .../install.sh | bash` を実行（Claude Bash ツール経由・非インタラクティブ）
- `hermes setup` をターミナルで手動実行（APIキー設定）
- Step 1〜5 の動作確認を hermes セッション内で実施

### 観測

- install.sh の完了状態:
  - clone: `~/.hermes/hermes-agent/`、venv: `~/.hermes/hermes-agent/venv/`（Python 3.11.15）
  - `~/.local/bin/hermes` symlink 作成済み（`~/.local/bin` は既に PATH にあったため `.bashrc` 追記なし）
  - Playwright Chromium（112 MiB）ダウンロード済み
  - WhatsApp bridge npm install 完了
  - 79 スキル同期済み
  - setup wizard は `/dev/tty` 未使用のため自動スキップ（exit code 1）、実害なし
- `hermes doctor` 確認:
  - `✓ API key or custom endpoint configured` / `✓ OpenAI Codex auth (logged in)`
  - コアツール 12種すべて `✓`（browser, terminal, file, memory 等）
  - npm audit 警告: agent-browser 1件 high、WhatsApp bridge 3件 critical（機能影響なし）

- **Step 1（基本対話）**: 日本語応答・レイテンシ問題なし ✓
- **Step 2（file ツール）**: リポジトリ構造の説明を正常実行 ✓
- **Step 3（terminal ツール）**: `git log --oneline -5` 実行・結果返却 ✓
- **Step 4（code_execution）**: FizzBuzz スクリプトを `fizzbuzz.py` として作成し terminal で実行 ✓
  - 実行場所は `/tmp/hermes_sandbox_XXXX/` ではなく terminal ツール経由（カレントディレクトリ付近）
- **Step 5（memory）**: `USER.md` への記録・次セッションへの持ち越しを確認 ✓
  - hermes は「知っていること」と「知らないこと」を明示分離して回答
  - 推測補完なしと自己宣言するなど AGENTS.md の観測駆動スタイルに近い応答

### 未解決

- web 検索（EXA/Tavily 等）・画像生成・vision・MoA は API キー未設定のため未検証。
- npm audit 警告の実影響（WhatsApp bridge の 3 critical は WhatsApp 未使用のため当面放置）。

---

## 2026-04-21: post-start の Hermes ログディレクトリ欠落を修正

### 実施

- `.devcontainer/post-start.sh` の Hermes Gateway / Dashboard 自動起動部を確認
- `No such file or directory` の原因を、ログ出力先ディレクトリ未作成として切り分け
- Hermes 起動前に `mkdir -p "$HERMES_LOG_DIR"` を追加
- `tests/post-start.bats` に Hermes ログディレクトリ自動作成の回帰テストを追加
- `npx bats --tap tests/post-start.bats` を実行

### 観測

- エラーは `hermes gateway` や `hermes dashboard` のプロセス本体ではなく、`"${HERMES_LOG_DIR}/gateway.log"` と `"${HERMES_LOG_DIR}/dashboard.log"` へのシェルリダイレクト失敗だった
- `OLLAMA_LOG_DIR` は `log_init` 経由で自動作成されていた一方、`HERMES_LOG_DIR` には同等の作成処理がなかった
- 実環境の `~/.local/state/` には `ollama/` は存在し、`hermes/` は存在しなかった
- 追加した Bats テストを含め `1..9` の 9 件すべて `ok` を観測

### 振り返り

- 不具合の根因は「サービス起動」ではなく「起動前提のファイルシステム準備」だった。標準出力リダイレクトを使う起動コードでは、プロセスの可用性確認より先に出力先の存在保証が必要
- 既存テストは Ollama 系ログしか見ておらず、Hermes 系の対称性が崩れていても検知できなかった。今回の回帰テスト追加で、同種の抜けを CI で捕捉できる状態にした
- 運用ドキュメント側のコード例も実装と同期しないと、将来の手修正や再実装で同じ欠落を再導入しやすい

### 未解決

- Hermes Gateway / Dashboard の実プロセス起動そのものは、今回のテストではスタブ化しており、本物の `hermes` バイナリ相手の E2E 検証は未実施
