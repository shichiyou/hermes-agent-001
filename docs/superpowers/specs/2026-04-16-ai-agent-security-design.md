# AI コーディングエージェント セキュリティ設計仕様書

> 対象リポジトリ: `ai-devcontainer-baseline`  
> 調査日: 2026-04-16  
> 最終更新: 2026-04-16  
> ステータス: 実装進行中（P0 #1・#2・#4 実装済み、#3 保留）

---

## 1. 概要

### 背景

本リポジトリは開発コンテナのベースラインを提供し、`post-create.sh` によって **Claude Code（Anthropic）・GitHub Copilot CLI（GitHub/Microsoft）・OpenAI Codex CLI（OpenAI）** の 3 つの AI コーディングエージェント CLI を自動インストールする。これらのツールはファイルシステムの読み書き、シェルコマンドの実行、外部 API 通信、MCP サーバーの起動など広範な権限を持ちうる。

セキュリティ設計が後手に回ると、コンテナ破壊から認証情報の漏洩まで複数の事故経路が生じる。本仕様書はリポジトリの実際の構成に基づいて各リスクを評価し、優先度付きの対策案を示す。

### スコープ

| 対象 | 詳細 |
|------|------|
| ツール | Claude Code CLI / GitHub Copilot CLI / OpenAI Codex CLI |
| 実行環境 | devcontainer（Docker）、Home ボリューム永続化あり |
| 脅威モデル | 侵害されたコード・MCP サーバー・npm パッケージ経由のエージェント悪用 |
| 対象外 | VS Code 拡張機能、GitHub Actions ワークフロー、ブラウザ上のコパイロット |

---

## 2. リポジトリ固有のコンテキスト

### 2.1 devcontainer 構成

> ⚠️ この節は 2026-04-16 の実装後の状態を反映している。変更前の構成はコミット `5626c32` 以前を参照。

- **ベースイメージ**: `Dockerfile` で定義（Ubuntu 24.04 ベース）
- **起動方式**: `dockerComposeFile` 方式（`.devcontainer/docker-compose.yml`）。`devcontainer` サービスと `docker-proxy` サービスの 2 コンテナ構成
- **Docker アクセス**: `docker-socket-proxy:v0.4.2` 経由（TCP `2375`）。コンテナ内の `DOCKER_HOST=tcp://docker-proxy:2375` がプロキシを指す。本物のソケットはマウントされない
- **永続 Home ボリューム**: `docker-compose.yml` の `volumes` で `devcontainer-home` を `/home/vscode` にマウント
- **初期化スクリプト**: `on-create.sh`（`onCreateCommand`）— `~/.home_initialized` センチネルで初回のみ `/etc/skel` をコピー

**変更前（調査時点）の構成**:
- `devcontainer.json` の `mounts` で Home ボリュームをマウント
- `docker-outside-of-docker` feature でホストソケット（`/var/run/docker.sock`）を直接マウント

### 2.2 AI CLI インストール方法（`post-create.sh` 抜粋）

```bash
# post-create.sh:127–133 より
if ! retry 3 env npm_config_ignore_scripts=false \
    npm install -g @openai/codex @github/copilot; then
    echo "WARNING: Some AI CLI npm packages failed to install"
fi

if ! command -v claude >/dev/null 2>&1; then
    echo ">>> Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash -s -- latest || \
        echo "WARNING: Claude Code installation failed"
fi
```

**観察された供給網リスク**:

| 問題点 | 詳細 |
|-------|------|
| バージョン未固定 | `@openai/codex`、`@github/copilot` に `@x.y.z` が指定されていない。npm はその時点の `latest` を取得する |
| npm install scripts 有効 | `npm_config_ignore_scripts=false` により、パッケージの `postinstall` スクリプトがコンテナ内でルート相当として実行される |
| `curl \| bash latest` | Claude Code は最新版のシェルスクリプトをパイプ実行。インテグリティ検証なし |

### 2.3 AI エージェント設定ファイルの不在

調査時点で以下のエージェント制約ファイルはリポジトリに存在しない（grep/file search により確認）。

| パス | 役割 | 存在 |
|------|------|------|
| `.claude/` | Claude Code プロジェクトポリシー | **なし** |
| `.github/agents/` | GitHub エージェント共有設定 | **なし** |
| `.github/mcp.json` / `.mcp.json` | MCP サーバー共有設定 | **なし** |
| `AGENTS.md` | エージェント向けプロジェクト規約 | **なし** |

エージェントはプロジェクトレベルの制約なしに起動されている。

---

## 3. リスク分析

### 3.1 Docker ソケット = ホストルート相当

**概要**  
Docker ソケット（`/var/run/docker.sock`）がコンテナ内にマウントされている場合、そのソケットへのアクセスはホスト Docker デーモンへの制御と等価である。AI エージェントがシェル実行権限を持つ場合、`docker run --rm -v /:/host ... chroot /host` などでホストファイルシステムに到達できる。

**公式見解**  
Docker 公式ドキュメントは「Only trusted users should be allowed to control your Docker daemon.」と明記し、Unix ソケット経由のデーモンアクセスをルート権限取得と同等に扱う。

> 出典: [Docker security — Docker daemon attack surface](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)

**レベル**: P0（Critical）

**決定**: 採用（2026-04-16）  
**実装**: `docker-socket-proxy:v0.4.2` を `docker-compose.yml` に追加し、`devcontainer` サービスの `DOCKER_HOST` をプロキシ TCP エンドポイントに設定。`docker-outside-of-docker` feature を除去し、本物のソケットのマウントを廃止。許可操作は `CONTAINERS:1 / IMAGES:1 / PING:1 / VERSION:1 / INFO:1` のみ。`POST:0 / DELETE:0` およびすべての書き込みエンドポイントをブロック。  
**セキュリティ保証**: AI エージェントが `docker-compose.yml` を編集しても、コンテナ内から `docker compose restart` できない（プロキシが `POST` をブロックするため）。許可設定の変更適用にはホスト側からの操作が必須。  
**実装コミット**: `dc2cc0b`（ブランチ: `docs/ai-agent-security-design`）

---

### 3.2 永続 Home ボリュームと認証情報の残留

**概要**  
`on-create.sh` はコンテナ再作成時も `~/.home_initialized` が存在する限り `/etc/skel` コピーをスキップし、ボリューム上のデータを引き継ぐ。3 ツールはいずれも認証トークン・セッション状態を `$HOME` 以下に保存する。

| ツール | 保存パス | 内容 |
|--------|---------|------|
| GitHub Copilot CLI | `~/.copilot/` | `config.json`, `permissions-config.json`, `session-state/`, `session-store.db`, `mcp-config.json`, `logs/` |
| OpenAI Codex CLI | `~/.codex/auth.json` | APIキー / OAuthトークン。公式ドキュメントは「treat like a password」と警告 |
| Claude Code | `~/.claude/` | セッションキャッシュ、設定、会話履歴 |

**影響**  
複数のリポジトリ・worktree が同一ボリュームを共有する構成では、あるリポジトリで侵害されたエージェントが他リポジトリの認証情報にアクセスできる。

> 出典（Copilot CLI 設定ディレクトリ）: [Copilot CLI configuration directory](https://docs.github.com/en/copilot/how-tos/copilot-cli/configuring-copilot-cli)  
> 出典（Codex 認証ファイル）: [OpenAI Codex CLI — Authentication](https://github.com/openai/codex#authentication)

**レベル**: P0（Critical）

**決定**: 案 C を採用（2026-04-16）— ボリュームをリポジトリごとに分離 + 認証ファイルのパーミッション強化  
**実装**:
- `devcontainer.json`: `initializeCommand` を文字列形式に変更。`devcontainer-home-<リポジトリ名>` でボリュームを作成し、`DEVCONTAINER_HOME_VOLUME` を `.devcontainer/.env` に書き出す（`.gitignore` 対象）
- `docker-compose.yml`: ボリューム名を `${DEVCONTAINER_HOME_VOLUME:-devcontainer-home}` で参照
- `post-start.sh`: 毎起動時に `~/.claude` / `~/.copilot` / `~/.codex` を `chmod 700`、配下ファイルを `chmod 600` に設定

**残存リスク**（受容済み）:
- コンテナ内 root 相当のプロセスは依然として認証ファイルを読める
- ホスト側から `docker volume inspect` / 別コンテナへのマウントによる読み出しは防げない（ホスト OS レベルの問題）

**実装コミット**: `075a828`（ブランチ: `docs/ai-agent-security-design`）

---

### 3.3 Copilot CLI はエンタープライズポリシーの適用外

**概要**  
GitHub Enterprise/Business の組織管理者が設定できる Copilot ポリシーのうち、Copilot CLI には**適用されないコントロールが複数存在する**。

| 管理者が設定できるポリシー | CLI への適用 |
|--------------------------|------------|
| コンテンツ除外（ファイルパス指定） | **非適用** |
| MCP サーバーポリシー | **非適用** |
| IDE 固有ポリシー | **非適用** |
| ユーザー設定 BYOK（Bring Your Own Key） | **制御不可**（ユーザーが環境変数でモデルプロバイダーを上書き可能） |

組織ポリシーだけに頼った場合、CLI ユーザーは事実上ポリシーの外で動作する。

> 出典: [Administering Copilot CLI for your enterprise — Controls that do not apply](https://docs.github.com/en/copilot/how-tos/copilot-cli/administer-copilot-cli-for-your-enterprise)

**レベル**: P0（Critical）— GitHub 側の設定で解決しない問題であることに注意

---

### 3.4 秘密情報と外向き通信

**概要**  
`.env` 等の機密ファイルをエージェントが読み取るリスク。

**各ツールの技術的制限手段（出典確認済み）**:

| ツール | ファイル除外の技術的手段 | 粒度 | 限界 |
|--------|----------------------|------|------|
| Claude Code | `.claude/settings.json` の `permissions.deny` | **ファイルパス単位** | Claude Code のみに効く |
| Codex CLI | `.codex/rules/` の `prefix_rule` | **シェルコマンドのプレフィックス単位** | 内部ファイル読み込みツール（shell 非経由）には効かない |
| Copilot CLI | `trusted_folders`（ディレクトリ単位） | **ディレクトリ単位のみ** | 同一ディレクトリ内のファイル単位除外の記載なし |

> 出典（Claude Code）: [Claude Code — Security and settings](https://docs.anthropic.com/claude-code/settings)  
> 出典（Codex CLI rules）: [OpenAI Codex CLI — Rules](https://developers.openai.com/codex/rules)  
> 出典（Codex Team Config）: [OpenAI Codex — Admin Setup, Step 4: Team Config](https://developers.openai.com/codex/enterprise/admin-setup)  
> 出典（Copilot CLI path permissions）: [Configuring GitHub Copilot CLI — Setting path permissions](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/configure-copilot-cli#setting-path-permissions)

**採用された設計方針（案 X）**  
`.secrets/` フォルダに機密情報の実体を集約し、各ツールのフォルダレベル制限を適用する。

1. `.secrets/` フォルダを `.gitignore` に追加（リポジトリ追跡を防止）
2. `.env` / `.env.local` 等の機密ファイルは `.secrets/` フォルダの機密情報を参照する運用とする（実体を持たない）
3. 各ツールに対してフォルダレベルの読み書き制限を設定する

**実装内容**:
- `.gitignore`: `.secrets/` を追加
- `.claude/settings.json`: `permissions.deny` に `"Read(./.secrets/**)"` / `"Write(./.secrets/**)"` を追加
- `.codex/rules/default.rules`: `cat` / `head` / `tail` / `less` / `more` + `.secrets` プレフィックスを `forbidden` に設定。Codex はリポジトリの `.codex/` ディレクトリを Team Config として自動読み込みする
- Copilot CLI: 同一ディレクトリ内のファイル単位除外の技術的手段なし → 運用ルール記録のみ

**不採用の案**:
- 案 Y（実行時注入方式）: 環境変数として展開された後は `printenv` 等で取得可能。ファイル保護にはなるが実行時漏洩は防げない
- ネットワーク全遮断: 作業に支障が出るため不採用

**残存リスク**（受容済み）:
- Codex CLI の `prefix_rule` はシェルコマンド経由のみ対象。内部ツールが shell を経由せずファイルを読む場合はブロックされない
- Copilot CLI には `.secrets/` 単体を除外する技術的手段がドキュメントに存在しない
- 機密情報の実体（`.secrets/` の内容）の管理は利用者が行う。本リポジトリはベースラインの骨格のみを提供する

**レベル**: P0（Critical）

---

### 3.5 Codex サンドボックスが Docker 内で無効化されるリスク

**概要**  
Linux 上の Codex CLI は `bwrap`（bubblewrap）+ `seccomp` + Landlock によるサンドボックスを使用する。OpenAI の公式ドキュメントは以下のように警告している。

> "When you run Linux in a containerized environment such as Docker, the sandbox may not work if the host or container configuration doesn't support the required Landlock and seccomp features. In that case, configure your Docker container to provide the isolation you need, then run codex with `--sandbox danger-full-access`."

本リポジトリには `bwrap`/`seccomp`/Landlock に関する設定が存在しないことを `grep_search` で確認した。コンテナ設定が整っていない場合、Codex のサンドボックスはサイレントに機能せず、コンテナ境界が唯一の防御ラインとなる。

> 出典: [OpenAI Codex CLI — Agent approvals & security](https://developers.openai.com/codex/agent-approvals-security)

**OS 別サンドボックス機構**:

| OS | 機構 |
|----|------|
| macOS | Seatbelt（App Sandbox） |
| Linux | bwrap + seccomp + Landlock |
| Windows / WSL1 | v0.1.15 以降はサポート外 |

**レベル**: P1（High） — サンドボックスが有効かどうかを実測で確認するまでは P0 相当

---

### 3.6 プロジェクトレベルのエージェント制約が不在

**概要**  
各ツールはプロジェクトディレクトリに設定ファイルを置くことで動作を制限できる。

| ツール | 設定ファイル | 可能な制約 |
|--------|------------|-----------|
| Claude Code | `.claude/settings.json` | `deny` ルール（ツール・パス・コマンド）、bypass 禁止フラグ |
| OpenAI Codex | `codex.toml` / `~/.codex/config.toml` | `sandbox_mode`, `approval_policy`, `network_access` |
| GitHub Copilot CLI | 起動オプション / `trusted_dirs` | `--deny-tool`, `--allow-tool`, `--allow-all` 制御 |

現状ではこれらが存在せず、エージェントはデフォルト（最大権限）で動作する。

> 出典（Claude Code 設定）: [Claude Code — Security and settings](https://docs.anthropic.com/claude-code/settings)  
> 出典（Codex 設定）: [OpenAI Codex CLI — Configuration](https://github.com/openai/codex#configuration)  
> 出典（Copilot CLI オプション）: [Copilot CLI — Configuring trusted directories and allowed tools](https://docs.github.com/en/copilot/how-tos/copilot-cli/configuring-copilot-cli)

**レベル**: P1（High）

---

### 3.7 供給網リスク（インストールスクリプト）

「2.2」で示した通り：

1. **npm `@openai/codex` / `@github/copilot`**: バージョン未固定・`npm_config_ignore_scripts=false`
2. **Claude Code**: `curl -fsSL https://claude.ai/install.sh | bash -s -- latest`

`npm_config_ignore_scripts=false` は意図的な設定であり、これらパッケージが `postinstall` スクリプトを持つ場合にコンテナ内でルート相当として実行される。バージョン未固定の場合、パッケージレジストリへの侵害が即座に全 devcontainer ユーザーに伝播する。

> 出典（npm install scripts リスク）: [npm Docs — Scripts](https://docs.npmjs.com/cli/v10/using-npm/scripts)  
> 出典（supply chain ベストプラクティス）: [OpenSSF — Supply Chain Security](https://openssf.org/blog/2022/09/01/open-source-supply-chain-security/)

**レベル**: P1（High）

---

### 3.8 MCP / plugins / hooks の拡張機能リスク

**概要**  
3 ツールはいずれも MCP サーバー（外部ツール統合）と hooks（ライフサイクルフック）をサポートする。これらの拡張機能はエージェントの攻撃対象領域を広げる。

**各ツールの対応状況**

| ツール | MCP | Hooks | Plugins |
|--------|-----|-------|---------|
| Claude Code | ✅ 正式（stdio / HTTP） | ✅ 正式（20+ イベント） | ✅（MCP・hooks をバンドル） |
| GitHub Copilot CLI | ✅ 正式（`--allow-tool`/`--deny-tool` で制御可） | ✅ 正式（実験的） | ドキュメントに記載なし |
| OpenAI Codex CLI | ✅ 正式（stdio / Streamable HTTP） | ⚠️ 実験的（`features.codex_hooks = true`） | ドキュメントに記載なし |

**主なリスク**

**R5-1: プロンプトインジェクション（全ツール共通）**  
MCP サーバーが取得したコンテンツ（Web ページ・外部データ等）に悪意ある指示が埋め込まれ、エージェントが意図しない操作を実行する。

> 出典: 「信頼できないコンテンツを取得する可能性のある MCP サーバーを使用する場合は特に注意してください。これらはプロンプトインジェクションのリスクにさらされる可能性があります。」— code.claude.com/docs/ja/mcp, 人気のある MCP サーバーセクション

**R5-2: stdio MCP サーバーのサプライチェーンリスク（Claude Code・Codex CLI）**  
`npx -y <package>` 形式はコマンド実行時にダウンロードが走るため、バージョン固定なしではサプライチェーン攻撃の経路になる。

> 出典: Codex CLI 設定例 `args = ["-y", "@upstash/context7-mcp"]` — developers.openai.com/codex/mcp

**R5-3: プロジェクトスコープ hooks による任意コマンド実行（Claude Code・Codex CLI）**  
`.claude/settings.json` の `hooks` セクションおよび `<repo>/.codex/hooks.json` はリポジトリにコミット可能。これらに定義されたシェルコマンドは、全チームメンバーの環境でエージェントライフサイクル中に実行される。`.mcp.json` の `headersHelper` フィールドも同様に任意シェルコマンドを実行する。

> 出典: 「Command hooks execute shell commands with your full user permissions. They can modify, delete, or access any files your user account can access. Review and test all hook commands before adding them to your configuration.」— code.claude.com/docs/en/hooks, Security considerations

**R5-4: `enableAllProjectMcpServers: true` による無条件承認（Claude Code）**  
通常、プロジェクト `.mcp.json` の MCP サーバーは実行前に承認を求める。この設定を有効にすると承認なしで全サーバーが起動する。

> 出典: code.claude.com/docs/en/settings — Project MCP configuration

**R5-5: HTTP hooks による外部へのデータ送信（Claude Code）**  
HTTP フックはエージェントの入出力データを外部 URL に POST できる。`allowedEnvVars` に指定した環境変数をヘッダーに展開することも可能。

> 出典: code.claude.com/docs/en/hooks, HTTP hook fields

**R5-6: Copilot CLI の組織 MCP ポリシー未適用（Copilot CLI）**  
エンタープライズの MCP ポリシー（「MCP servers in Copilot」「MCP Registry URL」）は Copilot CLI に現時点で適用されない。

> 出典: docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli#known-mcp-server-policy-limitations

**レベル**: P1（High）

**決定**: 案 C を採用（2026-04-16）— `AGENTS.md` に MCP / hooks 運用ルールを追記。技術的強制は「極端または局所的」として不採用。  
**実装コミット**: `7cdf625`

---

## 4. ツール別詳細分析

### 4.1 Claude Code（Anthropic）

| 項目 | 詳細 |
|------|------|
| プロジェクトポリシー | `.claude/settings.json` で deny ルール・bypass 禁止を記述可能。3 ツール中最も細かく設定できる |
| ネットワーク制御 | 起動フラグなし。プロジェクトポリシーで外部通信するツールを `deny` する方法が主 |
| モデルプロバイダー | Anthropic API（claude.ai）、または BYOK で外部プロバイダー |
| エンタープライズ | Anthropic コンソールで利用状況モニタリング可能 |
| OWASP Top 10 関連 | A05（Security Misconfiguration）: デフォルト設定のまま使うとツール使用に制限なし |

**データ保持（Anthropic API / 組織プラン）**  
- 会話削除後、バックエンド上のデータは 30 日以内に削除（**ユーザーによる削除操作が前提**。自動ではない）
- ローカルの `~/.claude/` に保存される会話履歴は削除操作まで手元に残り続ける（R8-1 参照）
- ゼロデータ保持（ZDR）契約あり
- 組織データはモデル学習に使用しない

> 出典: [Anthropic — Privacy Policy and Data Retention](https://www.anthropic.com/privacy)  
> 出典: [Anthropic — Enterprise data privacy FAQ](https://support.anthropic.com/en/articles/8325612-data-privacy-at-anthropic)

---

### 4.2 GitHub Copilot CLI

| 項目 | 詳細 |
|------|------|
| プロジェクトポリシー | 起動時オプションが主。`--deny-tool`, `--allow-tool`, `trusted_dirs`, URL パーミッションなど |
| エンタープライズ適用外 | 「3.3」参照。コンテンツ除外・MCP ポリシー・IDE ポリシー・BYOK 制御が一切効かない（エンタープライズポリシー適用外の詳細は「3.3」を参照）（エンタープライズポリシー適用外の詳細は「3.3」を参照） |
| 設定ディレクトリ | `~/.copilot/`（前述） |
| モデルプロバイダー | GPT-4o（OpenAI）、Claude（Anthropic）、Gemini（Google）。ホスティングは GitHub 経由または Azure |
| OWASP Top 10 関連 | A02（Cryptographic Failures）: `session-store.db` が平文で保存される場合のリスク |

**データ保持（Copilot Business / Enterprise）**  
- 顧客データは AI モデルの学習に使用しない
- OpenAI との間にゼロデータ保持契約あり
- Anthropic（Claude）・Google（Gemini）も「プロンプト・レスポンスをモデル学習に使用しない」と明言

> 出典: [GitHub Copilot — About responsible use of GitHub Copilot](https://docs.github.com/en/copilot/responsible-use-of-github-copilot-features/responsible-use-of-github-copilot-in-the-command-line)  
> 出典: [GitHub Trust Center — Copilot FAQ](https://resources.github.com/security/github-trust-center/)  
> 出典（モデル学習ポリシー）: github/docs リポジトリ `model-training-policy.md` (reusable)

---

### 4.3 OpenAI Codex CLI

| 項目 | 詳細 |
|------|------|
| サンドボックス | Linux: `bwrap + seccomp + Landlock`。**Docker コンテナ内では機能しない可能性あり**（「3.5」参照） |
| Approval Policy | `suggest`（提案のみ）/ `auto-edit`（書き込み自動）/ `full-auto`（すべて自動）の 3 段階 |
| ネットワーク制御 | `network_access = false` を `codex.toml` で設定可能 |
| 認証情報 | `~/.codex/auth.json`。公式が「treat like a password」と警告 |
| OWASP Top 10 関連 | A01（Broken Access Control）: `--dangerously-bypass-approvals-and-sandbox`（`--yolo`相当）フラグが存在し、すべての確認をスキップする |

**データ保持（OpenAI API / Enterprise / Business）**  
- デフォルトで顧客ビジネスデータをモデル学習に使用しない
- データ保持期間は設定可能
- AES-256 at rest、TLS 1.2+ in transit、SOC 2 Type 2、ISO 27001 取得済み

> 出典: [OpenAI Enterprise Privacy](https://openai.com/enterprise-privacy/)  
> 出典: [OpenAI Codex CLI — Agent approvals & security](https://developers.openai.com/codex/agent-approvals-security)

---

## 5. データガバナンス整理

| ベンダー | 個人 / 無料プラン | ビジネス / エンタープライズ / API プラン |
|----------|---------------|--------------------------------------|
| Anthropic (Claude Code) | 学習利用の可能性あり | 学習に使用しない。30 日自動削除 / ZDR 対応 |
| GitHub (Copilot) | 個人プランは Telemetry 送信あり | Business / Enterprise は学習に使用しない |
| OpenAI (Codex) | 無料プランは学習利用の可能性あり | Enterprise / Business はデフォルト非学習 |

**結論**: センシティブなコードを扱うリポジトリでは、すべて有償の組織・エンタープライズ・API プランを使用すること。個人・無料プランでの業務コード使用は避ける。

---

## 6. 優先度分類表

### 凡例

- **P0 (Critical)**: コンテナ外への影響またはデータ漏洩につながる直接経路。対処なしでの AI エージェント使用は推奨しない
- **P1 (High)**: 悪用が可能で、リスクが現実的。通常運用前に対処
- **P2 (Medium)**: 条件によりリスクが顕在化。受容基準を明確にして管理

| # | 観点 | 主な対策 | 重要度 | 優先度 | 判断 |
|---|------|---------|-------|-------|------|
| 1 | ホスト到達性（Docker ソケット） | `docker-socket-proxy:v0.4.2` 経由の read-only TCP アクセスに切り替え。本物のソケットのマウントを廃止 | Critical | **P0** | ✅ 実装済み（2026-04-16、`dc2cc0b`） |
| 2 | Home 永続化と認証情報残留 | ボリュームをリポジトリ名でスコープ分離（案 C）+ `post-start.sh` でパーミッション強化 | Critical | **P0** | ✅ 実装済み（2026-04-16、`075a828`） |
| 3 | 最小権限の既定化 | `allow-all` / `yolo` / `danger-full-access` をデフォルト無効化。起動スクリプトで明示的に制限 | Critical | **P0** | ⏸ 保留（2026-04-16） |
| 4 | 秘密情報と外向き通信 | `.secrets/` に機密情報を集約し各ツールのフォルダ制限を設定。`.gitignore` 追加。Claude Code・Codex CLI に読み取り禁止ルールを追加 | Critical | **P0** | ✅ 実装済み（2026-04-16） |
| 5 | MCP / plugins / hooks | `AGENTS.md` に MCP / hooks 運用ルールを追記（案 C） | High | **P1** | ✅ 実装済み（2026-04-16、`7cdf625`） |
| 6 | 供給網と更新経路 | `@openai/codex`・`@github/copilot` にバージョン固定、`latest` フォールバック削除（案 A） | High | **P1** | ✅ 実装済み（2026-04-16、`d779381`） |
| 7 | データガバナンス | `customization.md` の Optional AI Integrations セクションにプラン別データ保持表を追記（案 A） | High | **P1** | ✅ 実装済み（2026-04-16、`6a64938`） |
| 8 | 監査とローカル保持 | `AI_LOG_RETENTION_DAYS` 環境変数化 + `post-start.sh` で `~/.copilot/logs/` を自動ローテーション + `customization.md` にローカル履歴クリーンアップガイドを追記（案 C） | Medium-High | **P1** | ✅ 実装済み（2026-04-16、`65e2129`） |
| 9 | 生成物の品質・法務 | `CONTRIBUTING.md`（EN/JA）に AI コード取り扱い指針を追記、PR テンプレートに AI 利用チェック項目を追加（案 B） | High | **P1** | ✅ 実装済み（2026-04-16、`f1f280b`） |
| 10 | BYOK / ローカルモデル / リモートモード | 明確に必要な場合のみ。標準設定には含めない | Medium | **P2** | ✅ 実装済み（2026-04-16） |

---

## 7. ツール比較：制御の手厚さ

| 比較軸 | Claude Code | GitHub Copilot CLI | OpenAI Codex CLI |
|--------|------------|-------------------|-----------------|
| プロジェクトレベルポリシー | **.claude/ で最も細かく設定可** | 起動オプション中心。共有設定ファイルなし | `codex.toml` で network_access・approval_policy を定義可 |
| エンタープライズポリシー適用 | Anthropic コンソール経由で管理 | **コンテンツ除外・MCP ポリシーが CLI には非適用** | OpenAI コンソール / API ダッシュボード経由 |
| サンドボックス | なし（プロセスレベルの制限はポリシーに依存） | なし | bwrap + seccomp。**Docker 内では機能しない可能性** |
| 学習データ利用（有償） | 使用しない | 使用しない | 使用しない |
| 設定の難易度 | 低（JSON 設定ファイル） | 中（起動オプション管理） | 低（TOML 設定ファイル） |

---

## 8. 決定記録

各項目の決定・実装状況を時系列で記録する。

| 日付 | # | 観点 | 決定 | 実装コミット | 備考 |
|------|---|------|------|------------|------|
| 2026-04-16 | 1 | ホスト到達性（Docker ソケット） | 採用: `docker-socket-proxy:v0.4.2` | `dc2cc0b` | 許可制御の変更はホスト側操作が必要。AI 側から適用不可 |
| 2026-04-16 | 2 | Home 永続化と認証情報残留 | 採用（案 C）: ボリューム名リポジトリ分離 + パーミッション強化 | `075a828` | 残存リスク: コンテナ内 root・ホスト側 volume 検査は防げない（受容） |
| 2026-04-16 | 3 | 最小権限の既定化 | 保留: リスクを理解の上、技術的強制の難しさから現状維持 | — | 危険フラグは引数指定時のみ有効。Copilot CLI はファイルによる強制不可。再評価条件: ツール側の設定強制機能追加時 |
| 2026-04-16 | 4 | 秘密情報と外向き通信 | 採用（案 X）: `.secrets/` 集約 + `.gitignore` + `.claude/settings.json` deny ルール + `.codex/rules/default.rules` | `e094f26` | Copilot CLI はファイル単位除外の手段なし（運用ルール記録のみ）。Codex rules はシェル経由のみ有効。ネットワーク全遮断は不採用（作業支障のため） |
| 2026-04-16 | 5 | MCP / plugins / hooks | 採用（案 C）: `AGENTS.md` に MCP / hooks 運用ルールを追記 | `7cdf625` | R5-2（stdio バージョン未固定）・R5-3/R5-5（プロジェクト hooks / HTTP hooks）・R5-4（enableAllProjectMcpServers）を運用ルールで管理。技術的強制（全無効・設定ファイル非コミット強制）は極端または局所的として不採用 |
| 2026-04-16 | 6 | 供給網と更新経路 | 採用（案 A）: `@openai/codex@0.121.0`・`@github/copilot@1.0.28` にバージョン固定。`latest` Claude Code フォールバック削除 | `d779381` | uv・Ollama・Claude Code は Dockerfile ARG で既に固定済みのため追加対処不要。ベースイメージダイジェスト固定・ハッシュ検証は過剰として不採用 |
| 2026-04-16 | 7 | データガバナンス | 採用（案 A）: `customization.md` の Optional AI Integrations にプラン別データ保持表を追記 | `6a64938` | 技術的強制は不可能（ベンダープランをコードから検証する API なし）。文書化のみで対処 |
| 2026-04-16 | 8 | 監査とローカル保持 | 採用（案 C）: `AI_LOG_RETENTION_DAYS` 環境変数化 + `post-start.sh` で `~/.copilot/logs/` 自動ローテーション + `customization.md` にローカル履歴クリーンアップガイドを追記 | `65e2129` | `~/.claude/` / `~/.codex/` の会話履歴は自動ローテーション不可（作業コンテキストのため）。手動削除手順を文書化 |
| 2026-04-16 | 9 | 生成物の品質・法務 | 採用（案 B）: `CONTRIBUTING.md`（EN/JA）に AI コード取り扱い指針を追記、`.github/pull_request_template.md` に AI 利用チェック項目を追加 | `f1f280b` | 既存 CI（shellcheck + lint + test）が基礎安全網として機能するため、文書化 + チェックリストの組み合わせで十分 |
| 2026-04-16 | 10 | BYOK / ローカルモデル / リモートモード | 採用（案 A）: `customization.md` に「API Keys and BYOK」サブセクションを追記。`devcontainer.json` への直書き禁止・ホスト環境変数転送・`.env` ファイル・Ollama ローカルバックエンドの安全な利用手順を記載 | — | 技術的リスクはゼロ（API キーが未設定）。文書化のみで十分 |

---

## 9. 次のステップ

P0（#1・#2・#4）・P1（#5〜#9）・P2（#10）の全項目が完了した。未着手は #3（最小権限の既定化）のみで、保留扱いのまま維持する。

**未着手の設定変更候補**（採用決定後に実装）:

3. `.claude/settings.json` — bypass 禁止フラグ追加（#3 最小権限・保留中）
4. `codex.toml`（`sandbox_mode = "workspace-write"`, `approval_policy = "on-request"`, `network_access = false`）の新規作成（#3 最小権限・保留中）
5. Copilot CLI 起動スクリプトに `--deny-tool='shell(rm)'` 等のデフォルト制限を追加（#3 最小権限・保留中）
## 10. 出典・参考文献

| # | タイトル | URL | 参照目的 |
|---|---------|-----|---------|
| 1 | Docker security — Docker daemon attack surface | https://docs.docker.com/engine/security/#docker-daemon-attack-surface | Docker ソケット = ホストルート相当の根拠 |
| 2 | Administering Copilot CLI for your enterprise | https://docs.github.com/en/copilot/how-tos/copilot-cli/administer-copilot-cli-for-your-enterprise | Copilot CLI にエンタープライズポリシーが非適用な項目の特定 |
| 3 | Configuring Copilot CLI (trusted dirs, allowed tools) | https://docs.github.com/en/copilot/how-tos/copilot-cli/configuring-copilot-cli | Copilot CLI の `--deny-tool`、`--allow-tool`、`trusted_dirs` オプション |
| 4 | Responsible use of GitHub Copilot in the CLI | https://docs.github.com/en/copilot/responsible-use-of-github-copilot-features/responsible-use-of-github-copilot-in-the-command-line | Copilot CLI のデータ取り扱い・セキュリティ対策 |
| 5 | GitHub Trust Center — Copilot FAQ | https://resources.github.com/security/github-trust-center/ | Copilot Business/Enterprise の学習データ利用ポリシー |
| 6 | Copilot CLI configuration directory | https://docs.github.com/en/copilot/how-tos/copilot-cli/configuring-copilot-cli | `~/.copilot/` ディレクトリ構造と保存情報 |
| 7 | OpenAI Codex CLI — Agent approvals & security | https://developers.openai.com/codex/agent-approvals-security | Codex サンドボックス機構・Docker コンテナでの無効化リスク |
| 8 | OpenAI Enterprise Privacy | https://openai.com/enterprise-privacy/ | OpenAI の Enterprise/Business データ保持・学習ポリシー |
| 9 | OpenAI Codex CLI — Authentication | https://github.com/openai/codex#authentication | `~/.codex/auth.json` の「treat like a password」警告 |
| 10 | OpenAI Codex CLI — Configuration | https://github.com/openai/codex#configuration | `codex.toml` の `sandbox_mode`, `approval_policy`, `network_access` |
| 11 | Anthropic — Privacy Policy and Data Retention | https://www.anthropic.com/privacy | Anthropic の 30 日自動削除・ZDR ポリシー |
| 12 | Anthropic — Enterprise data privacy FAQ | https://support.anthropic.com/en/articles/8325612-data-privacy-at-anthropic | 組織データのモデル学習非使用の根拠 |
| 13 | Claude Code — Security and settings | https://docs.anthropic.com/claude-code/settings | `.claude/settings.json` の deny ルール・bypass 禁止フラグ |
| 14 | npm Docs — Scripts | https://docs.npmjs.com/cli/v10/using-npm/scripts | `npm_config_ignore_scripts` のリスク |
| 15 | OpenSSF — Supply Chain Security | https://openssf.org/blog/2022/09/01/open-source-supply-chain-security/ | supply chain ベストプラクティスの参照 |
| 16 | github/docs リポジトリ `model-training-policy.md` (reusable) | https://github.com/github/docs | Copilot Business/Enterprise の学習データ非使用・OpenAI ZDR・Gemini 非学習コミットメント |
| 17 | tecnativa/docker-socket-proxy — Docker Hub | https://hub.docker.com/r/tecnativa/docker-socket-proxy | バージョンタグ確認（v0.4.2 = 2026-04 時点の `latest`） |
| 18 | tecnativa/docker-socket-proxy — GitHub | https://github.com/Tecnativa/docker-socket-proxy | 環境変数による許可制御の仕様 |
| 19 | OpenAI Codex CLI — Rules | https://developers.openai.com/codex/rules | `prefix_rule` によるコマンドブロック仕様・Starlark 形式・パスのリテラルマッチ制限の確認 |
| 20 | OpenAI Codex — Admin Setup, Step 4: Team Config | https://developers.openai.com/codex/enterprise/admin-setup | `.codex/` ディレクトリをリポジトリに含めると Codex が自動読み込みすることの確認 |
| 21 | Configuring GitHub Copilot CLI — Setting path permissions | https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/configure-copilot-cli#setting-path-permissions | Copilot CLI のパスパーミッションがディレクトリ単位のみでファイル単位除外不可の確認 |
| 22 | GitHub Copilot CLI configuration directory | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference | `config.json` の `trusted_folders`・`denied_urls` 等の設定項目一覧 |
| 23 | Claude Code — MCP（サードパーティ MCP セキュリティ警告） | https://code.claude.com/docs/ja/mcp | プロンプトインジェクションリスクの公式警告（R5-1 の根拠） |
| 24 | Claude Code — Hooks reference（Security considerations） | https://code.claude.com/docs/en/hooks | command hooks がフルユーザー権限で実行される旨の公式警告（R5-3 の根拠） |
| 25 | Claude Code — Settings（Project MCP configuration） | https://code.claude.com/docs/en/settings | `enableAllProjectMcpServers` の仕様（R5-4 の根拠）; HTTP hook fields（R5-5 の根拠） |
| 26 | OpenAI Codex CLI — MCP | https://developers.openai.com/codex/mcp | Codex の MCP 設定と `npx -y` 形式の確認（R5-2 の根拠） |
| 27 | OpenAI Codex CLI — Hooks | https://developers.openai.com/codex/hooks | Codex の hooks 機能と実験的フラグの確認（R5-3 の根拠） |
| 28 | About GitHub Copilot CLI — Known MCP server policy limitations | https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli#known-mcp-server-policy-limitations | 組織 MCP ポリシーが CLI に適用されない既知の制限（R5-6 の根拠） |

---

*本仕様書はリポジトリの実コードを直接参照した調査に基づく。調査時点（2026-04-16）以降のベンダーポリシー変更は反映されていないため、定期的な見直しを推奨する。*
