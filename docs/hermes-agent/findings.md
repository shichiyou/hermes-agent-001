# Hermes Agent Lab — 知見集

ラボ活動で得た再利用可能な知見をトピック別にまとめる。時系列の経過は `progress.md`、
本書は「結論と回避策」のインデックス。

## 導入・ビルド関連

- `uv pip install -e ".[all,dev]"` は Python 3.11.15 上で問題なく完走（2026-04-17、hermes-agent
  commit `436a7359`）。165 packages を解決。所要数分。
- uv が `hardlink` にフォールバックした旨の警告が出る。性能が若干落ちるのみで機能影響なし。
  回避する場合は uv のキャッシュと venv を同一ファイルシステムに置く必要があるが、devcontainer
  環境では通常そうなっているため無視可。
- `tinker-atropos` submodule は `rl` 機能のため必須。初期ラボでは未初期化で問題なし（`hermes
  doctor` が警告を出すのみ）。必要になったら `git submodule update --init --recursive` を
  `~/.hermes/hermes-agent/` 内で実行する。

## 実行時挙動（CLI・モデル選択・メッセージング）

- `hermes doctor` は認証未整備・設定未投入の初期状態でも exit code `0` を返す（警告は出るが
  失敗扱いにはしない）。ラボではまずこの状態を起点とする。
- CLI エントリポイントは `venv/bin/hermes`・`hermes-agent`・`hermes-acp` の 3 つ。ラボでは
  `hermes` を主に使い、install.sh が作成する `~/.local/bin/hermes` symlink 経由で呼び出す。
- tool 可否は doctor 出力の「Tool Availability」に集約されている：デフォルト有効なのは
  `browser, clarify, code_execution, cronjob, delegation, file, memory, terminal,
  session_search, skills, todo, tts`。`moa / rl / messaging / vision / homeassistant /
  image_gen` は追加設定要。

## 設定・環境変数

- 状態ディレクトリは `~/.hermes/`（devcontainer Home volume に載る）。`config.yaml`・`.env`・
  `sessions/`・`logs/`・`memories/`・`SOUL.md` などをここに保持する。ラボ本体の `.gitignore`
  と独立（Home 側）なので、リポジトリコミット対象にはならない。
- 認証は `hermes login <provider>` または `.env` に API キーを入れる方式。OpenRouter・Nous
  Portal・OpenAI・Anthropic 等を想定。キーは絶対にリポジトリへ入れない。

## 互換性・バージョン

<!-- 例: Python 3.11 / 3.12 / 3.14 の差、OS 差、依存ライブラリのバージョン固定 -->

- hermes-agent は `requires-python >=3.11`。ラボ本体は 3.14 だが、hermes-agent 自体は
  install.sh が構築する `~/.hermes/hermes-agent/venv/`（Python 3.11 系）で運用する。

## パフォーマンス・リソース消費

<!-- 例: 起動時間、メモリ使用量、トークン消費の傾向 -->

## 既知の問題と回避策

<!-- 発見次第追記 -->

- `.devcontainer/post-start.sh` で `nohup ... > "${XDG_STATE_HOME}/.../service.log"` のようにサービスログをリダイレクトする場合は、起動前に親ディレクトリを `mkdir -p` で明示作成すること。未作成だとプロセス本体ではなくシェルのリダイレクト段階で `No such file or directory` になる
- `tests/post-start.bats` は Ollama 系だけでなく Hermes 系のログディレクトリ自動作成も確認する。起動ブロックが複数ある場合、片方だけのテストでは対称性崩れを見逃しやすい

## 公式 install.sh の挙動と現ラボとの差分

公式インストール手順（`curl -fsSL ... | bash`）を `scripts/install.sh` の静的読解で分析（2026-04-17）。

### install.sh が行うこと

| 手順 | 内容 |
| ---- | ---- |
| clone 先 | `~/.hermes/hermes-agent/`（`HERMES_HOME` 配下） |
| venv 名 | `venv/`（`.venv/` ではない） |
| extras | `.[all]` のみ（`dev` は含まない） |
| Node.js | `~/.hermes/node/` に Node 22 LTS を DL、`~/.local/bin/` に `node`/`npm`/`npx` symlink を作成 |
| PATH 追記 | `~/.bashrc`（他に `~/.bash_profile`、`~/.profile`）に `export PATH="$HOME/.local/bin:$PATH"` を追記 |
| browser | `npm install` + `npx playwright install --with-deps chromium`（Ubuntu では sudo 要求） |
| WhatsApp | `scripts/whatsapp-bridge/` で `npm install` |
| 設定 | `~/.hermes/.env`、`~/.hermes/config.yaml`、`~/.hermes/SOUL.md` を雛形から生成 |
| ディレクトリ | `~/.hermes/{cron,sessions,logs,pairing,hooks,image_cache,audio_cache,memories,skills,whatsapp/session}` を作成 |
| setup wizard | `hermes setup` を /dev/tty 経由でインタラクティブ実行（`--skip-setup` で省略可） |
| gateway | messaging token が `.env` に設定されていれば systemd サービスへの登録を提案 |

### 現ラボとの主要な差分

| 項目 | 現ラボ（lab 方式） | install.sh 方式 |
| ---- | ----------------- | --------------- |
| clone 先 | `external/hermes-agent/`（`.gitignore` 対象） | `~/.hermes/hermes-agent/`（Home volume） |
| venv パス | `external/hermes-agent/.venv/` | `~/.hermes/hermes-agent/venv/` |
| extras | `.[all,dev]` | `.[all]`（dev 無し） |
| `~/.local/bin/hermes` symlink | 手動作成済み（同等） | スクリプトが自動作成 |
| Node.js | devcontainer に nvm 管理 Node 24 あり（競合なし） | `~/.local/bin/node` に Node 22 を上書き → **nvm との競合リスク** |
| PATH 追記 | 不要（devcontainer の PATH に `~/.local/bin` 既存） | `~/.bashrc` に追記（冗長だが無害） |
| browser / Playwright | 未実施 | 自動実施 |
| `~/.hermes/` 設定ディレクトリ | 未生成（`hermes doctor` が警告） | 雛形から自動生成 |

### 注意点・副作用と現ラボの採用判断

1. **docker run 不可**: docker-socket-proxy の `POST: "0"` により devcontainer 内から `docker run` は 403 でブロックされる。使い捨てコンテナでの検証は**ホスト側ターミナル**から行う必要がある。
2. **Node.js 競合**: nvm が管理する Node 24（`~/.nvm/versions/node/...`）が既存であり、install.sh が `~/.local/bin/node` を Node 22 symlink に上書きすると `which node` の結果が変わる。
3. **Home volume 汚染**: `~/.hermes/`・`~/.bashrc` 追記・`~/.local/bin/node` はすべて Home volume（`devcontainer-home`）に永続化される。install.sh はアンインストール機能を持たないため、後から除去しにくい。

### 現ラボの採用方式

install.sh 自体の使用を全面禁止する意図ではなく、上記の副作用を把握した上で現ラボでは install.sh を採用している。
実際には Node.js 競合は発生しなかった（devcontainer に nvm Node 24 が入っており `command -v node` が通るため install.sh がスキップ）。

- install.sh を実行し `~/.hermes/hermes-agent/` に clone・venv を構築
- `~/.local/bin/hermes` symlink は install.sh が自動作成（`~/.local/bin` は既に PATH 上）
- `~/.hermes/` の設定ディレクトリも install.sh が自動生成し `hermes setup` で API キーを投入

## 非スコープ（現ラボで扱わない）

- hermes-agent 本体への改造
- upstream への PR／fork 作成
- RL extras（`tinker-atropos` submodule）
- メッセージング Gateway（Telegram/Discord 等）の実運用
- 実 API キーを伴う対話セッションのリポジトリ内検証
