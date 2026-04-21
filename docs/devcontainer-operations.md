# Dev Container 運用ドキュメント

Hermes Agent の開発コンテナ環境におけるサービス自動起動と、ホームボリューム消失時の再現性確保についての方針・現状・計画をまとめたドキュメント。同一ホストPCでの再構築に加え、**別ホストPCへのクローン環境構築** をゴールとしている。

---

## 1. 現状分析

### 1.1 コンテナ構成

```
devcontainer-home-hermes-agent-template  (external Docker volume)
    └── /home/vscode/               （~/.hermes, ~/.local, ~/.bashrc 等）

/workspaces/hermes-agent-template/        （ホストバインドマウント、Git管理）
    ├── .devcontainer/
    │   ├── devcontainer.json
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   ├── on-create.sh
    │   ├── post-create.sh
    │   ├── post-start.sh
    │   └── scripts/
    ├── wiki/                        （Gitサブモジュール → shichiyou/wiki）
    └── docs/devcontainer-operations.md  ← このファイル
```

### 1.2 `~/.hermes/` の内訳（合計 約1.4GB）

| パス | サイズ | 内容 | バックアップ要否 |
|---|---|---|---|
| `hermes-agent/` | 1.4GB | Hermes本体（ソース＋venv） | ❌ `hermes update` で再取得可能 |
| `sessions/` | 19MB | セッション履歴 | ⚠️ 任意 |
| `skills/` | 11MB | スキル群（hub由来79＋カスタム13） | ✅ カスタムのみ |
| `bin/` | 9.4MB | バイナリ（tirith等） | ❌ 再インストール可能 |
| `checkpoints/` | 2.3MB | チェックポイント | ⚠️ 任意 |
| `config.yaml` | 398行 | メイン設定 | ✅ |
| `auth.json` | 9.5KB | 認証情報（4プロバイダー） | 🔴 Gitコミット不可 |
| `SOUL.md` | — | カスタム指示 | ✅ |
| `memories/` | — | MEMORY.md + USER.md | ✅ |
| `cron/jobs.json` | — | cronジョブ定義（7job） | ✅ |
| `.env` | — | 環境変数（API鍵・トークン含む） | 🔴 Gitコミット不可（テンプレート化で対応） |
| `gateway_state.json` | — | Gateway稼働状態 | ❌ 自動生成 |

### 1.3 サービス起動状況（実装済み）

| サービス | 自動起動 | 手段 | 備考 |
|---|---|---|---|
| Ollama server | ✅ | `post-start.sh` | ✅ 確実 |
| Hermes Gateway | ✅ | `post-start.sh` | ✅ コンテナ起動ごとに自動起動（10秒ヘルスチェック待機） |
| Hermes Dashboard | ✅ | `post-start.sh` | ✅ `--no-open` でバックグラウンド起動、ポート転送は `forwardPorts: [9119]` |

### 1.4 認証・Gitインフラの現状（別ホストクローンで問題になる部分）

| 項目 | 現状 | 別ホストでの影響 |
|---|---|---|
| `auth.json` | 4プロバイダー（openai-codex, copilot, ollama-cloud, anthropic）のOAuthトークンを格納 | 🔴 API鍵なしではHermes全機能が不稼働 |
| SSH鍵 | `~/.ssh/` に秘密鍵なし（`known_hosts`のみ） | 影響なし（HTTPS + gh credential helper使用） |
| GitHub認証 | `gh auth login` 済み（`~/.config/gh/hosts.yml`） | 🔴 Private repoアクセス不可 |
| Git identity | `~/.gitconfig`（user=Tanaka Yasunobu, email=shichiyou@outlook.com） | 🟡 コミット作者情報が欠落 |
| Git credential | VS Code Dev Container helper + `gh auth git-credential` | 🟡 `gh auth login` が必要 |
| Ollama models | `ollama list` → gemma4:31b-cloud, glm-5.1:cloud | 🟠 pullで再取得可能だが必要一覧の記録なし |

### 1.5 config.yaml内のAPI鍵の解析

config.yamlの全`api_key`行を検査した結果：

| 行 | 値 | 判断 |
|---|---|---|
| L2 `api_key: ollama` | `"ollama"`（リテラル文字列） | ✅ Gitコミット可能。Ollama Cloudの認証は`auth.json`内のOAuthトークン経由 |
| L129-178 `api_key: ''` | 空文字（9箇所） | ✅ Gitコミット可能。認証プロバイダー設定は`auth.json`を参照 |
| L260 `api_key: ''` | 空文字 | ✅ Gitコミット可能 |

**結論**: config.yamlには秘密値が含まれていない。`auth.json`に全てのOAuth/API鍵が集約されており、config.yamlは安全にGitコミット可能。

---

## 2. 別ホストPCクローンの耐障害性ギャップ

### 2.1 カバーできるもの（✅）

| 項目 | 復元手段 |
|---|---|
| Dev Container 定義 | `git clone` → 自動再構築 |
| ワークスペースソースコード | `git clone` |
| Wiki コンテンツ | Gitサブモジュール |
| Dockerfile内ツール | バージョンピン留め済み、再ビルドで復元 |
| npmパッケージ | `post-create.sh` でバージョンピン留め済み |
| Hermes 本体 | `hermes update` / インストーラで再取得 |
| Hub由来スキル（79個） | `hermes skills install` で再取得 |
| config.yaml | Gitコミット可能（秘密値なし） |

### 2.2 カバーできないもの（❌・🟡）

| 項目 | 影響度 | ギャップ |
|---|---|---|
| **auth.json（OAuth/API鍵）** | 🔴致命的 | ブラウザ認証が必要、自動化不可 |
| **gh auth login（GitHub認証）** | 🔴致命的 | ブラウザ認証が必要、自動化不可 |
| **カスタムスキル（13個）** | 🟡重要 | バックアップ作成未実施 |
| **cronジョブ定義** | 🟡重要 | バックアップ作成未実施 |
| **MEMORY.md / USER.md** | 🟡重要 | バックアップ作成未実施 |
| **SOUL.md** | 🟡重要 | バックアップ作成未実施 |
| **.bashrc追加設定** | 🟡重要 | バックアップ作成未実施 |
| **Wiki symlink** | 🟡重要 | 復元ロジック未実装 |
| **.gitconfig** | 🟢補助 | user.name/emailのみ、再設定容易 |
| **.env（環境変数）** | 🟡重要 | ✅ テンプレート化で対応済み（秘密値は`YOUR_*_HERE`でプレースホルダー化） |

---

## 3. 3層防御戦略（別ホストPC完全クローン）

### 第1層：Git管理で自動復元（`git clone` のみ）

`git clone` + `git submodule update --init --recursive` で全て取得できるもの。

```
hermes-agent-template/
├── .devcontainer/
│   ├── devcontainer.json      ← forwardPorts: [9119] 追加
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── on-create.sh           ← Hermes設定復元・本体インストール ロジック追加
│   ├── post-create.sh
│   ├── post-start.sh          ← Gateway + Dashboard 自動起動追加
│   ├── hermes-backup/         ← 設定バックアップ（第2層）
│   └── scripts/
│       └── backup-hermes-config.sh  ← バックアップ更新スクリプト
├── docs/devcontainer-operations.md
├── SOP.md, AGENTS.md
└── wiki/
```

### 第2層：バックアップで半自動復元

`.devcontainer/hermes-backup/` に配置し、`on-create.sh` がホームボリューム初期化を検出した場合に自動復元。

#### 最終ディレクトリ構成（実ファイル一覧）

```
.devcontainer/hermes-backup/
├── config.yaml                    # 398行、秘密値なし → Gitコミット可能
├── SOUL.md                        # カスタム指示
├── memories/
│   ├── MEMORY.md                  # エージェント記憶
│   └── USER.md                    # ユーザープロファイル
├── cron/
│   └── jobs.json                  # cronジョブ定義（7job）
├── bashrc-additions.sh            # .bashrcに追加すべき設定
├── gitconfig-template             # .gitconfig テンプレート
├── dot-env-template               # .env テンプレート（秘密値は YOUR_*_HERE でプレースホルダー化）
├── ollama-models.txt              # 必要Ollamaモデル一覧
└── skills/                        # カスタムスキルのみ（13個）
    ├── autonomous-ai-agents/
    │   ├── copilot/SKILL.md
    │   └── ollama-launch/SKILL.md
    ├── creative/
    │   └── creative-ideation/
    │       ├── SKILL.md
    │       └── references/full-prompt-library.md
    ├── devops/
    │   ├── discord-secure-setup/SKILL.md
    │   ├── hermes-cron-ops/SKILL.md
    │   └── hermes-devcontainer-persistence/SKILL.md
    ├── research/
    │   ├── agile-meta-thinking/SKILL.md
    │   ├── thinking-framework/SKILL.md
    │   ├── wiki-daily-research/SKILL.md
    │   ├── wiki-daily-summary/SKILL.md
    │   └── wiki-research-browser/SKILL.md
    └── software-development/
        ├── ai-agent-conduct/SKILL.md
        └── root-cause-analysis/SKILL.md
```

**除外するもの（Gitコミット不可・不要）**:
- `auth.json` — OAuth鍵・API鍵を含む、第3層で手動設定
- `.env` — 生ファイルには秘密値（bot token, API key等）を含むためGit不可。`dot-env-template`（プレースホルダー化済み）のみコミット
- hub由来スキル（79個）— `hermes skills install` で再取得可能
- `hermes-agent/` — `hermes update` で再取得可能（1.4GB）
- `sessions/` — セッション履歴、機能的影響軽微
- `.bundled_manifest` — 再生成される

#### bashrc-additions.sh の内容（確定版）

`~/.bashrc` にインタラクティブシェル設定として追加すべき内容。`on-create.sh` は非インタラクティブ実行のため、`.bashrc` のインタラクティブガードの外にこれらを注入する必要がある。

```bash
# Wiki path (LLM Wiki skill)
export WIKI_PATH="/workspaces/hermes-agent-template/wiki"

# Wiki symlink (for convenience)
if [ -L "$HOME/wiki" ] && [ ! -e "$HOME/wiki" ]; then
    rm "$HOME/wiki"
fi

if [ ! -e "$HOME/wiki" ] && [ ! -L "$HOME/wiki" ]; then
    ln -s /workspaces/hermes-agent-template/wiki "$HOME/wiki"
fi
```

**備考**: Gateway の自動起動は `post-start.sh` に一本化する。`bashrc-additions.sh` は Wiki 関連の復元だけを担い、旧来の Gateway 自動起動行は `post-start.sh` が移行時に除去する。

#### gitconfig-template の内容（確定版）

```
[user]
	name = Tanaka Yasunobu
	email = shichiyou@outlook.com

[credential "https://github.com"]
	helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper = !/usr/bin/gh auth git-credential
```

**備考**: 以下は復元対象外（環境依存のため自動生成される）:
- `credential.helper`（VS Code Dev Container helper）— セッション開始時に動的生成
- `safe.directory = D:/maf` — ホスト固有のパス

#### ollama-models.txt の内容（確定版）

```
# Ollama models required by Hermes Agent
# Install with: ollama pull <model>
gemma4:31b-cloud
glm-5.1:cloud
```

### 第3層：手動設定が必須なもの（認証情報）

ブラウザ認証が必要で自動化不可の項目。新規ホストで必ず手動実行する。

| 項目 | 手段 | 必要な操作 |
|---|---|---|
| API鍵（auth.json） | `hermes setup` | 各プロバイダーのOAuth/鍵を対話的に設定 |
| GitHub認証 | `gh auth login` | ブラウザ認証でGitHubにログイン |
| 環境変数（.env） | エディタで編集 | `dot-env-template` から復元された `~/.hermes/.env` の `YOUR_*_HERE` プレースホルダーを実際の値に置換 |

**注意**: `hermes setup` 実行前に `hermes gateway` が起動している必要がある。手順順序は「Hermes本体インストール → Gateway起動 → `hermes setup` → Dashboard起動」。

---

## 4. 課題と解決策

### 4.1 Dashboard & Gateway の確実な自動起動

**解決策**: `post-start.sh` に Gateway と Dashboard の起動を追加。

```bash
# ── Hermes Gateway & Dashboard ──────────────────────────────
HERMES_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hermes"
HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-9119}"

if command -v hermes >/dev/null 2>&1; then
    mkdir -p "$HERMES_LOG_DIR"

    # Gateway
    if ! pgrep -f "hermes gateway" > /dev/null; then
        nohup hermes gateway > "${HERMES_LOG_DIR}/gateway.log" 2>&1 &
        log_info "Hermes Gateway starting..."
    else
        log_info "Hermes Gateway already running."
    fi

    # Dashboard — Gateway起動後にAPIが安定するまで待機
    if ! pgrep -f "hermes dashboard" > /dev/null; then
        # Gatewayのヘルスチェック（最大10秒待機）
        for _i in $(seq 1 10); do
            if curl -sf http://127.0.0.1:8080/health >/dev/null 2>&1 \
               || pgrep -f "hermes gateway" > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        nohup hermes dashboard --no-open > "${HERMES_LOG_DIR}/dashboard.log" 2>&1 &
        log_info "Hermes Dashboard starting on port ${HERMES_DASHBOARD_PORT}."
    else
        log_info "Hermes Dashboard already running."
    fi
fi
```

補足: `mkdir -p "$HERMES_LOG_DIR"` は必須。これがないと、初回起動や Home volume 再生成後にログファイルへのリダイレクトが先に失敗し、`hermes gateway` / `hermes dashboard` 自体が起動しない。

**設計判断**: Gateway → Dashboard の起動順序について、**案A（ヘルスチェック後）**を採用。理由：
1. Dashboard起動時にGateway APIに接続を試みるため、Gatewayが未稼働だとDashboardが異常終了する可能性
2. 最大10秒の待機で十分（Gatewayは通常3秒以内に起動完了）
3. 待機中もOllama等の他のpost-start処理は並行して進行

**ポート転送**: `devcontainer.json` に `forwardPorts: [9119]` を追加し、VS Codeの自動ポート転送に頼らない。

### 4.2 ホームボリューム消失時の設定復元

`on-create.sh` に以下の復元ロジックを追加：

```bash
# ── Hermes configuration restore ─────────────────────────────
if [ ! -f "$HOME/.hermes/config.yaml" ]; then
    BACKUP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/.devcontainer/hermes-backup"
    if [ -d "$BACKUP_DIR" ]; then
        log_info "Home volume appears empty — restoring Hermes configuration..."
        mkdir -p "$HOME/.hermes"

        # 設定ファイル
        cp -a "$BACKUP_DIR/config.yaml"    "$HOME/.hermes/" 2>/dev/null || true
        cp -a "$BACKUP_DIR/SOUL.md"        "$HOME/.hermes/" 2>/dev/null || true

        # メモリ
        mkdir -p "$HOME/.hermes/memories"
        cp -a "$BACKUP_DIR/memories/"      "$HOME/.hermes/"  2>/dev/null || true

        # Cronジョブ
        mkdir -p "$HOME/.hermes/cron"
        cp -a "$BACKUP_DIR/cron/"           "$HOME/.hermes/"  2>/dev/null || true

        # カスタムスキル
        cp -a "$BACKUP_DIR/skills/"         "$HOME/.hermes/"  2>/dev/null || true

        # .bashrc 追加設定（インタラクティブガードの直前に挿入）
        if [ -f "$BACKUP_DIR/bashrc-additions.sh" ]; then
            # インタラクティブガードの `case $-` 行の直前に挿入
            BASHRC="$HOME/.bashrc"
            ADDITIONS="$BACKUP_DIR/bashrc-additions.sh"
            if grep -q "WIKI_PATH" "$BASHRC" 2>/dev/null; then
                log_info ".bashrc already contains WIKI_PATH, skipping additions."
            else
                # インタラクティブガードの直前にマーカー付きで挿入
                sed -i "/^# If not running interactively/e cat \"$ADDITIONIONS\"" "$BASHRC" 2>/dev/null || \
                cat "$ADDITIONIONS" >> "$BASHRC"
                log_info ".bashrc additions applied."
            fi
        fi

        # .gitconfig テンプレート適用
        if [ -f "$BACKUP_DIR/gitconfig-template" ]; then
            if [ ! -f "$HOME/.gitconfig" ] || ! grep -q "Tanaka Yasunobu" "$HOME/.gitconfig" 2>/dev/null; then
                cat "$BACKUP_DIR/gitconfig-template" >> "$HOME/.gitconfig"
                log_info ".gitconfig template applied."
            fi
        fi

        # Wiki symlink
        if [ -L "$HOME/wiki" ] && [ ! -e "$HOME/wiki" ]; then
            rm "$HOME/wiki"
        fi

        if [ ! -e "$HOME/wiki" ] && [ ! -L "$HOME/wiki" ] && [ -d "/workspaces/hermes-agent-template/wiki" ]; then
            ln -s /workspaces/hermes-agent-template/wiki "$HOME/wiki"
            log_info "Wiki symlink created."
        fi

        log_info "Hermes configuration restored from backup."
    else
        log_warn "No backup found in $BACKUP_DIR — skipping restore."
    fi
fi

# ── Hermes Agent installation ────────────────────────────────
if ! command -v hermes >/dev/null 2>&1; then
    log_info "Hermes Agent not found — installing..."
    curl -fsSL https://hermes.nousresearch.com/install.sh | bash
fi

# ── Manual setup reminder ───────────────────────────────────
if [ ! -f "$HOME/.hermes/auth.json" ] || [ ! -s "$HOME/.hermes/auth.json" ]; then
    log_warn "Hermes auth.json is missing or empty."
    log_warn "Run 'hermes setup' to configure API keys after container startup."
fi
if ! gh auth status >/dev/null 2>&1; then
    log_warn "GitHub CLI is not authenticated."
    log_warn "Run 'gh auth login' to enable Git push to private repositories."
fi
```

### 4.3 バックアップ更新スクリプト

`.devcontainer/scripts/backup-hermes-config.sh` の仕様：

**実行タイミング**: 3層の自動バックアップ構成（手動実行も可能）

| タイミング | 手段 | 特徴 |
|---|---|---|
| 毎時0分 | Hermes cron (`hermes-config-backup`) | 定常的な自動バックアップ。差分があればcommit+push |
| コンテナ起動時 | `post-start.sh` | 起動直後の安全網。差分があればcommit+push |
| 手動 | `bash .devcontainer/scripts/backup-hermes-config.sh` | 任意のタイミングで即時バックアップ |

**設計判断の変更（2026-04-20）**: 当初は手動実行のみとしていたが、ディザスタリカバリの観点から自動バックアップに移行した。理由：
1. 手動バックアップのみでは最終バックアップ以降の変更が消失するリスクがある
2. `backup-hermes-config.sh` の実行時間は約0.7秒と軽量で、毎時実行でも負荷は無視できる
3. Git差分がない場合はcommitが発生しないため、ノイズは増えない
4. コンテナ起動時のバックアップは、cronが実行される前のギャップを埋める安全網として機能

```bash
#!/bin/bash
# backup-hermes-config.sh — Hermes設定をGit管理のバックアップに同期
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/../hermes-backup"
HERMES_HOME="${HOME:-/home/vscode}/.hermes"

echo "=== Hermes Configuration Backup ==="

# バックアップディレクトリを作成
mkdir -p "${BACKUP_DIR}"/{memories,cron,skills}

# 設定ファイル
cp -a "${HERMES_HOME}/config.yaml"  "${BACKUP_DIR}/"
cp -a "${HERMES_HOME}/SOUL.md"      "${BACKUP_DIR}/"

# メモリ
cp -a "${HERMES_HOME}/memories/MEMORY.md" "${BACKUP_DIR}/memories/" 2>/dev/null || true
cp -a "${HERMES_HOME}/memories/USER.md"   "${BACKUP_DIR}/memories/" 2>/dev/null || true

# Cronジョブ
cp -a "${HERMES_HOME}/cron/jobs.json" "${BACKUP_DIR}/cron/"

# カスタムスキル（.hub_install マーカーがないもののみ）
echo "Syncing custom skills..."
SKILLS_DIR="${HERMES_HOME}/skills"
for skill_dir in "${SKILLS_DIR}"/*/*/; do
    if [ -f "${skill_dir}SKILL.md" ] && [ ! -f "${skill_dir}.hub_install" ]; then
        skill_rel="${skill_dir#${SKILLS_DIR}/}"
        skill_rel="${skill_rel%/}"
        target="${BACKUP_DIR}/skills/${skill_rel}"
        mkdir -p "${target}"
        cp -a "${skill_dir}"* "${target}/"
        echo "  Synced: ${skill_rel}"
    fi
done

# .bashrc 追加設定の抽出
echo "Extracting .bashrc additions..."
BASHRC_ADDITIONS="${BACKUP_DIR}/bashrc-additions.sh"
cat > "${BASHRC_ADDITIONS}" <<'HERMES_BASHRC'
# Wiki path (LLM Wiki skill)
export WIKI_PATH="/workspaces/hermes-agent-template/wiki"

# Wiki symlink (for convenience)
if [ -L "$HOME/wiki" ] && [ ! -e "$HOME/wiki" ]; then
    rm "$HOME/wiki"
fi

if [ ! -e "$HOME/wiki" ] && [ ! -L "$HOME/wiki" ]; then
    ln -s /workspaces/hermes-agent-template/wiki "$HOME/wiki"
fi
HERMES_BASHRC

# .gitconfig テンプレート
echo "Generating .gitconfig template..."
GITCONFIG_TEMPLATE="${BACKUP_DIR}/gitconfig-template"
cat > "${GITCONFIG_TEMPLATE}" <<'GITCONFIG'
[user]
	name = Tanaka Yasunobu
	email = shichiyou@outlook.com

[credential "https://github.com"]
	helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper = !/usr/bin/gh auth git-credential
GITCONFIG

# Ollama モデル一覧
echo "Generating Ollama models list..."
ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' > "${BACKUP_DIR}/ollama-models.txt"

# .env テンプレート生成（秘密値を YOUR_*_HERE に置換）
echo "Generating .env template..."
ENV_TEMPLATE="${BACKUP_DIR}/dot-env-template"
if [ -f "${HERMES_HOME}/.env" ]; then
    # ヘッダー（コメント行）はそのまま保存
    sed -n '/^#/p' "${HERMES_HOME}/.env" > "${ENV_TEMPLATE}"
    # 変数行を処理：秘密値はプレースホルダー化、それ以外はそのまま
    while IFS= read -r line; do
        # コメント行と空行はスキップ（既にヘッダーで保存済み）
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        # VAR=VALUE を抽出
        var_name="${line%%=*}"
        var_value="${line#*=}"
        # 秘密値パターン: _TOKEN, _KEY, _SECRET, _PASSWORD サフィックス + DISCORD_ALLOWED_USERS / DISCORD_HOME_CHANNEL
        if [[ "$var_name" =~ _TOKEN$|_KEY$|_SECRET$|_PASSWORD$ ]] \
           || [[ "$var_name" == "DISCORD_ALLOWED_USERS" ]] \
           || [[ "$var_name" == "DISCORD_HOME_CHANNEL" ]]; then
            printf '%s=YOUR_%s_HERE\n' "$var_name" "$var_name" >> "${ENV_TEMPLATE}"
        else
            printf '%s=%s\n' "$var_name" "$var_value" >> "${ENV_TEMPLATE}"
        fi
    done < "${HERMES_HOME}/.env"
    echo "  .env template generated (secrets placeholderized)"
else
    echo "  No .env file found, skipping template generation"
fi

echo ""
echo "Backup complete. Files are in: ${BACKUP_DIR}"
echo "To commit: git add .devcontainer/hermes-backup/ && git commit -m 'update hermes backup'"
```

**`.env` テンプレート化の設計判断**:

- **秘密値の基準**: 環境変数名が `_TOKEN`, `_KEY`, `_SECRET`, `_PASSWORD` のいずれかで終わる場合、および `DISCORD_ALLOWED_USERS` と `DISCORD_HOME_CHANNEL`（並行稼働リスクがあるインスタンス固有ID）は `YOUR_<VARNAME>_HERE` に置換
- **非秘密値は保持**: `TERMINAL_TIMEOUT`, `BROWSERBASE_PROXIES`, `HERMES_MAX_ITERATIONS` 等の設定値はそのまま保存し、発見可能性を確保
- **並行稼働防止**: `DISCORD_BOT_TOKEN` と `DISCORD_ALLOWED_USERS` / `DISCORD_HOME_CHANNEL` をプレースホルダー化することで、テンプレートから復元された `.env` ではDiscord Gatewayが起動しないようにし、元ホストとの並行稼働によるトークン衝突を防止

### 4.4 .gitignore の追加

`.devcontainer/hermes-backup/.gitignore` に以下を設定：

```gitignore
# API鍵を含むファイル（絶対にGitコミットしない）
auth.json

# Raw .envファイル（秘密値を含む、dot-env-templateのみコミット可能）
.env

# セッション履歴（容量が大きく、機能的影響軽微）
sessions/

# Hermes本体とバイナリ（再インストール可能）
hermes-agent/
bin/

# 自動生成ファイル
gateway_state.json
gateway.pid
processes.json
*.log
*.db
*.db-shm
*.db-wal
*.lock

# Hub由来スキル（再インストール可能）
# カスタムスキルのみをバックアップするため、
# .hub_install マーカーがあるスキルは backup-hermes-config.sh で除外済み
```

---

## 5. 別ホストPCクローン検証 — ステップバイステップ手順書

このセクションは、**全く新しいPC**で `git clone` から始めた場合の完全な再現性を検証するための手順書。
2つのシナリオをカバーする：

- **シナリオA**: 新規ホストでの初回構築（ホームボリュームが空 → 復元ロジックが発火）
- **シナリオB**: 既存ホストでのリビルド（ホームボリュームが保持 → 復元ロジックはスキップ）

---

### 5.1 前提条件

- [ ] Docker Desktop または Docker Engine がインストール済み
- [ ] VS Code + Dev Containers 拡張機能がインストール済み
- [ ] GitHub アカウント（shichiyou）へのアクセス権

---

### 5.2 シナリオA: 新規ホストでの初回構築検証

#### ステップ1: リポジトリのクローン

```bash
git clone https://github.com/shichiyou/hermes-agent-template.git
cd hermes-agent-template

# Wikiサブモジュールの初期化
git submodule update --init --recursive
```

**確認ポイント**:
```bash
# サブモジュールが取得できていること
git submodule status
# 期待結果: wiki ディレクトリのコミットハッシュが表示される（先頭に - がないこと）

# バックアップデータの存在確認
ls .devcontainer/hermes-backup/config.yaml
ls .devcontainer/hermes-backup/SOUL.md
ls .devcontainer/hermes-backup/skills/
# 期待結果: 全てのファイルが存在すること
```

#### ステップ2: Dev Container のビルドと起動

```bash
code .
# → "Reopen in Container" を選択
# → コンテナビルドが開始される（初回は5〜10分）
```

**ここで何が起きるか**（ライフサイクルフックの実行順序）:

| 順序 | フック | 処理内容 |
|---|---|---|
| 1 | `initializeCommand` | Docker external volume 作成 |
| 2 | Docker build | Dockerfile からイメージ構築 |
| 3 | `onCreateCommand` = `on-create.sh` | ホームボリューム初期化 → **Hermes設定復元** → Hermes本体インストール → **認証警告** |
| 4 | `postCreateCommand` = `post-create.sh` | 依存関係インストール |
| 5 | `postStartCommand` = `post-start.sh` | Ollama起動 → **Gateway起動** → **Dashboard起動** |

#### ステップ3: on-create.sh の実行結果検証

コンテナが起動したら、ターミナルを開いて復元結果を確認する。

```bash
# 3-1: Hermes設定ファイルの復元確認
ls -la ~/.hermes/config.yaml
# 期待結果: ファイルが存在すること（hermes-backup/ からコピー）

ls -la ~/.hermes/SOUL.md
# 期待結果: ファイルが存在すること

# 3-2: メモリファイルの復元確認
ls -la ~/.hermes/memories/MEMORY.md ~/.hermes/memories/USER.md
# 期待結果: 2ファイルが存在すること

# 3-3: Cronジョブ定義の復元確認
cat ~/.hermes/cron/jobs.json | python3 -m json.tool | head -5
# 期待結果: JSONとしてパース可能であること（7job分の定義）

# 3-4: カスタムスキルの復元確認
find ~/.hermes/skills -name "SKILL.md" | grep -v ".hub_install" | wc -l
# 期待結果: 13（カスタムスキル数）
# 補足: .hub_install マーカーがないもの = カスタムスキル

# 3-5: .bashrc 追加設定の確認
grep -n "WIKI_PATH" ~/.bashrc
# 期待結果: WIKI_PATH の export 行が存在すること
#   例: export WIKI_PATH="/workspaces/hermes-agent-template/wiki"

# 3-6: Wiki シンボリックリンクの確認
ls -la ~/wiki
# 期待結果: /workspaces/hermes-agent-template/wiki へのシンボリックリンク

# 3-7: .gitconfig の確認
git config user.name
# 期待結果: Tanaka Yasunobu
git config user.email
# 期待結果: shichiyou@outlook.com

# 3-8: Hermes本体のインストール確認
which hermes
# 期待結果: /home/vscode/.local/bin/hermes（またはインストールパス）

hermes --version
# 期待結果: バージョン番号が表示されること

# 3-9: .env テンプレートの復元確認
ls -la ~/.hermes/.env
# 期待結果: ファイルが存在すること（dot-env-template からコピー）

grep -c 'YOUR_.*_HERE' ~/.hermes/.env
# 期待結果: 1以上（プレースホルダーが含まれていること）
# 注: 実際の秘密値に置換するまでは、Discord等の連携は機能しない
```

#### ステップ4: post-start.sh の実行結果検証

```bash
# 4-1: Ollamaサーバーの起動確認
curl -sf http://127.0.0.1:11434/api/tags | python3 -c "import sys,json; print(json.load(sys.stdin).get('models',[]))" 2>/dev/null || echo "Ollama not responding"
# 期待結果: モデル一覧がJSONで返ること
# 注: まだモデルをpullしていない場合は空配列 []

# 4-2: Hermes Gateway の起動確認
pgrep -f "hermes gateway"
# 期待結果: プロセスIDが表示されること

hermes gateway status
# 期待結果: "running" であること

# 4-3: Hermes Dashboard の起動確認
pgrep -f "hermes dashboard"
# 期待結果: プロセスIDが表示されること

curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9119/
# 期待結果: 200

# 4-4: Dashboard ポート転送の確認
# VS Codeの「ポート」タブを開き、ポート9119がリストにあることを確認
# または、ホスト側ブラウザで http://localhost:9119/ にアクセスしてDashboardが表示されること

# 4-5: 実 Hermes バイナリに対する起動健全性確認
# 注: これはスタブではなく、実際に post-start.sh が作成した状態を観測するための確認

# Hermes 用ログディレクトリとログファイルが作成されていること
ls -ld ~/.local/state/hermes
ls -l ~/.local/state/hermes/gateway.log ~/.local/state/hermes/dashboard.log
# 期待結果: ディレクトリと 2 つのログファイルが存在すること

# ログ末尾にリダイレクト失敗が出ていないこと
tail -20 ~/.local/state/hermes/gateway.log
tail -20 ~/.local/state/hermes/dashboard.log
# 期待結果: `No such file or directory` が含まれないこと

# post-start の統合ログに起動完了メッセージが出ていること
grep -F "Starting Hermes Gateway..." ~/.local/state/ollama/post-start.log
grep -F "Hermes Dashboard is responding on port 9119." ~/.local/state/ollama/post-start.log
# 期待結果: 2 行ともヒットすること

# Dashboard が HTTP 応答し、Gateway が running を返すこと
hermes gateway status
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9119/
# 期待結果: `running` と `200`
```

#### ステップ5: 認証情報の手動設定（第3層）

on-create.sh は認証情報を自動復元しない。以下を手動で実行する。

```bash
# 5-1: GitHub認証
gh auth login
# → GitHub.com → HTTPS → ブラウザで認証
# 確認:
gh auth status
# 期待結果: "Logged in to github.com account shichiyou"

# 5-2: Hermes認証（API鍵の設定）
hermes setup
# → 各プロバイダーのOAuth/鍵を設定:
#    - Ollama Cloud (ollama-cloud)  ※デフォルトプロバイダー
#    - OpenAI Codex (openai-codex)
#    - GitHub Copilot (copilot)
#    - Anthropic (anthropic)
# 確認:
ls -la ~/.hermes/auth.json
# 期待結果: ファイルが存在し、サイズ > 0

# 5-3: Ollamaモデルの取得
ollama pull gemma4:31b-cloud
ollama pull glm-5.1:cloud
# 確認:
ollama list
# 期待結果: 2モデルが表示されること

# 5-4: .env 秘密値の設定
# dot-env-template から復元された ~/.hermes/.env には
# プレースホルダー値（YOUR_*_HERE）が含まれている。
# 以下のコマンドでプレースホルダー箇所を確認:
grep 'YOUR_.*_HERE' ~/.hermes/.env
# 期待結果: プレースホルダー行が表示されること
# 例: OLLAMA_API_KEY=YOUR_OLLAMA_API_KEY_HERE
#     DISCORD_BOT_TOKEN=YOUR_DISCORD_BOT_TOKEN_HERE
#     DISCORD_ALLOWED_USERS=YOUR_DISCORD_ALLOWED_USERS_HERE
#     DISCORD_HOME_CHANNEL=YOUR_DISCORD_HOME_CHANNEL_HERE

# 各プレースホルダーを実際の値に置換:
nano ~/.hermes/.env
# または:
# sed -i 's/YOUR_OLLAMA_API_KEY_HERE/actual_ollama_key/' ~/.hermes/.env
# sed -i 's/YOUR_DISCORD_BOT_TOKEN_HERE/actual_token/' ~/.hermes/.env
# sed -i 's/YOUR_DISCORD_ALLOWED_USERS_HERE/actual_user_id/' ~/.hermes/.env
# sed -i 's/YOUR_DISCORD_HOME_CHANNEL_HERE/actual_channel_id/' ~/.hermes/.env

# 確認: プレースホルダーが残っていないこと
grep 'YOUR_.*_HERE' ~/.hermes/.env
# 期待結果: 何も出力されないこと（全てのプレースホルダーが実際の値に置換済み）
```

#### ステップ6: 包括的動作確認

```bash
# 6-1: Gateway + Dashboard 連携
hermes gateway status
# 期待結果: running

# 6-2: Dashboard HTTP応答
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9119/
# 期待結果: 200

# 6-3: Cron ジョブ一覧
hermes cron list
# 期待結果: バックアップ時の7jobが表示されること
# 注: Gateway と auth.json が設定されていないと一部jobがエラーになる可能性あり

# 6-4: Wiki シンボリックリンクの動作確認
ls ~/wiki/
# 期待結果: Wiki コンテンツが表示されること

# 6-5: カスタムスキルの認識確認
ls ~/.hermes/skills/ | head -5
# 期待結果: カテゴリディレクトリ（autonomous-ai-agents, creative 等）が表示される

# 6-6: ログの確認（エラーがないこと）
cat ~/.local/state/hermes/gateway.log | tail -5
cat ~/.local/state/hermes/dashboard.log | tail -5
cat ~/.local/state/on-create.log | tail -10
# 期待結果: "ACTION REQUIRED" 警告以外にエラーがないこと
# 注: auth.json 未設定時の警告は正常（ステップ5で解消）
```

---

### 5.3 シナリオB: 既存ホストでのリビルド検証

ホームボリュームが保持される再ビルドのケース。
**復元ロジックは `~/.hermes/config.yaml` が既に存在する場合はスキップされる**ため、既存設定が維持されることを確認する。

#### ステップ1: リビルド前の状態記録

```bash
# 現在の設定のハッシュを記録（後で比較するため）
md5sum ~/.hermes/config.yaml ~/.hermes/SOUL.md
# 期待結果: ハッシュ値を記録

ls ~/.hermes/cron/jobs.json
# 期待結果: ファイルが存在

cat ~/.hermes/memories/MEMORY.md | wc -l
# 期待結果: 行数を記録
```

#### ステップ2: コンテナのリビルド

VS Codeコマンドパレット → `Dev Containers: Rebuild Container`

#### ステップ3: リビルド後の状態確認

```bash
# 3-1: 設定ファイルが維持されていること
md5sum ~/.hermes/config.yaml ~/.hermes/SOUL.md
# 期待結果: ステップ1と同じハッシュ値

# 3-2: ホームボリューム初期化マーカーの確認
ls -la ~/.home_initialized
# 期待結果: ファイルが存在すること（初回作成分、タイムスタンプ不変）

# 3-3: Hermes設定が既存であることを on-create.log で確認
grep "Hermes configuration already present" ~/.local/state/on-create.log
# 期待結果: ログ行が見つかること（復元ロジックがスキップされた証拠）

# 3-4: サービスの再起動確認
hermes gateway status
# 期待結果: running

curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9119/
# 期待結果: 200
```

---

### 5.4 ホームボリューム消失のシミュレーション検証

**警告**: この検証は現行のホームボリュームを一時的に削除する。本番データのバックアップを事前に取得すること。

#### ステップ1: バックアップの取得

```bash
# 現行設定のバックアップ（検証後に復元するため）
bash .devcontainer/scripts/backup-hermes-config.sh
# バックアップデータはGit管理下にあるため、最新コミットに含まれているはず

# auth.json のバックアップ（手動コピー、Git管理外のため）
cp ~/.hermes/auth.json /tmp/auth.json.bak
```

#### ステップ2: コンテナ停止とボリューム削除

```bash
# コンテナを停止（VS Code でコンテナを閉じる）

# Docker ボリュームの削除
docker volume rm devcontainer-home-hermes-agent-template
# 期待結果: ボリュームが削除されたこと

# 補足: docker-compose down -v でも可能だが、
# 対象ボリューム以外も削除されるリスクがあるため手動削除を推奨
```

#### ステップ3: コンテナ再ビルド（完全な新規ボリューム）

```bash
# VS Code で "Rebuild Container" を実行
# → on-create.sh が走り、.home_initialized が存在しないため
#    ホームボリューム初期化 → Hermes設定復元 が実行される
```

#### ステップ4: 復元結果の検証（シナリオAのステップ3〜6と同じ）

```bash
# ステップ3: on-create.sh の実行結果検証
ls -la ~/.hermes/config.yaml          # ✅ 存在すること
ls -la ~/.hermes/SOUL.md              # ✅ 存在すること
ls -la ~/.hermes/memories/MEMORY.md   # ✅ 存在すること
grep "WIKI_PATH" ~/.bashrc            # ✅ 追加されていること
ls -la ~/wiki                         # ✅ シンボリックリンクが作成されていること
which hermes                           # ✅ インストールされていること

# ステップ4: post-start.sh の実行結果検証
hermes gateway status                  # ✅ running
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9119/  # ✅ 200

# ステップ5: 認証情報の手動設定
cp /tmp/auth.json.bak ~/.hermes/auth.json
gh auth login
# または hermes setup で再設定

# .env のプレースホルダー置換
# 復元された ~/.hermes/.env には YOUR_*_HERE プレースホルダーが含まれている
# 実際の秘密値に置換すること（5.2 ステップ5-4 を参照）
grep 'YOUR_.*_HERE' ~/.hermes/.env
# 期待結果: プレースホルダー行が表示される → 手動で実際の値に置換

# ステップ6: 包括的動作確認（5.2 ステップ6と同じ）
```

#### ステップ5: on-create.log の内容確認

```bash
cat ~/.local/state/on-create.log
# 以下がログに記録されていることを確認:
# - "Home volume appears empty — restoring Hermes configuration..."
# - ".bashrc additions applied."
# - "Wiki symlink created."
# - ".gitconfig template applied."
# - "Hermes Agent not found — installing..." （または "already installed"）
# - ".env template restored (secrets need manual configuration)." （.envテンプレート復元ログ — 正常）
# - "=== ACTION REQUIRED ===" （.env にプレースホルダーが含まれる警告 — 正常）
# - "=== ACTION REQUIRED ===" （auth.json 未設定の警告 — 正常）
```

---

### 5.5 設定変更後のバックアップ更新（運用手順）

設定を変更した後、以下を実行してバックアップを更新する。

```bash
# バックアップスクリプトの実行
bash .devcontainer/scripts/backup-hermes-config.sh

# 差分の確認
git diff .devcontainer/hermes-backup/
# 期待結果: 変更されたファイルのみがステージングされること
#   auth.json, sessions/, hermes-agent/ 等は .gitignore で除外されている

# 変更のコミット
git add .devcontainer/hermes-backup/
git commit -m "chore: update hermes config backup"
```

**バックアップを実行すべきタイミング**:
- `hermes config` で設定を変更した後
- カスタムスキルを追加・更新した後
- cronジョブを追加・変更した後
- MEMORY.md / SOUL.md を更新した後
- `.bashrc` に環境変数を追加した後
- `.env` に環境変数を追加・変更した後（バックアップスクリプトがテンプレートを自動更新）

---

### 5.6 検証チェックリスト一覧表

| # | 検証項目 | 期待結果 | シナリオA | シナリオB | ボリューム消失 |
|---|---|---|---|---|---|
| 1 | `~/.hermes/config.yaml` が存在 | ファイルあり | ✅ 復元 | ✅ 維持 | ✅ 復元 |
| 2 | `~/.hermes/SOUL.md` が存在 | ファイルあり | ✅ 復元 | ✅ 維持 | ✅ 復元 |
| 3 | `~/.hermes/memories/` が存在 | MEMORY.md + USER.md | ✅ 復元 | ✅ 維持 | ✅ 復元 |
| 4 | `~/.hermes/cron/jobs.json` が存在 | 7job分のJSON | ✅ 復元 | ✅ 維持 | ✅ 復元 |
| 5 | カスタムスキルが13個存在 | `find \| wc -l` = 13 | ✅ 復元 | ✅ 維持 | ✅ 復元 |
| 6 | `~/.bashrc` に WIKI_PATH 追加 | `grep` でヒット | ✅ 復元 | ✅ 既存 | ✅ 復元 |
| 7 | `~/wiki` シンボリックリンク | リンク先が存在 | ✅ 復元 | ✅ 既存 | ✅ 復元 |
| 8 | `~/.gitconfig` に user 情報 | name + email | ✅ 復元 | ✅ 既存 | ✅ 復元 |
| 9 | `hermes` コマンド存在 | which hermes | ✅ インストール | ✅ 既存 | ✅ インストール |
| 10 | Gateway 起動 | `status` = running | ✅ 自動起動 | ✅ 自動起動 | ✅ 自動起動 |
| 11 | Dashboard 起動 | HTTP 200 | ✅ 自動起動 | ✅ 自動起動 | ✅ 自動起動 |
| 12 | ポート9119転送 | ブラウザで表示 | ✅ forwardPorts | ✅ forwardPorts | ✅ forwardPorts |
| 13 | `auth.json` | 🔴 手動設定必須 | ❌ 要手順5 | ✅ 既存 | ❌ 要手順5 |
| 14 | `gh auth` | 🔴 手動設定必須 | ❌ 要手順5 | ✅ 既存 | ❌ 要手順5 |
| 15 | `~/.hermes/.env` | 🟡 テンプレート復元+手動設定 | ✅ テンプレート復元 | ✅ 既存 | ✅ テンプレート復元 |
| 16 | Ollamaモデル | 🟠 pull必要 | ❌ 要pull | ✅ 既存 | ❌ 要pull |
| 17 | on-create.log 復元ログ | "restoring" ログあり | ✅ | ✅ "skipping" | ✅ "restoring" |

---

## 6. 実装状況と優先順位

### P0 — コンテナ再起動時に毎回必要（✅ 実装済み）

| # | タスク | 対象ファイル | ステータス |
|---|---|---|---|
| 1 | Gateway + Dashboard 自動起動 | `post-start.sh` | ✅ コミット `c8233d6` |
| 2 | Dashboard ポート転送 | `devcontainer.json` | ✅ コミット `01038e0` |

### P1 — ボリューム消失時の保険（✅ 実装済み）

| # | タスク | 対象ファイル | ステータス |
|---|---|---|---|
| 3 | バックアップ更新スクリプト | `.devcontainer/scripts/backup-hermes-config.sh` | ✅ コミット `94e0bbc` |
| 4 | 初期バックアップスナップショット | `.devcontainer/hermes-backup/` | ✅ コミット `34a3d98` |
| 5 | on-create.sh 復元ロジック + インストール確認 + 認証警告 | `on-create.sh` | ✅ コミット `7cdeeec` |
| 6 | .gitignore（auth.json等を除外） | `.devcontainer/hermes-backup/.gitignore` | ✅ コミット `34a3d98` |
| 7 | .env テンプレート生成・復元 | `backup-hermes-config.sh` + `on-create.sh` + `.gitignore` | ✅ コミット予定 |

### P2 — 改善・検証（🔧 未実装）

| # | タスク | 備考 |
|---|---|---|
| 8 | 別ホストでのクローン検証 | 新規環境でチェックリスト5.1〜5.3を実行して動作確認 |
| 9 | バックアップ鮮度の運用確立 | 設定変更時に `backup-hermes-config.sh` を実行する運用を習慣化 |

---

## 7. 既存のDev Container ライフサイクルフック

| フック | タイミング | 現在の役割 | 追加予定 |
|---|---|---|---|
| `initializeCommand` | コンテナ作成前（ホスト側） | Dockerボリューム作成 | なし |
| `onCreateCommand` | 初回コンテナ作成時 | ホームボリューム初期化 | Hermes設定復元・本体インストール・Wiki symlink・.env復元・認証警告 |
| `postCreateCommand` | コンテナ作成後 | 依存関係インストール | なし |
| `postStartCommand` | コンテナ起動ごと | Ollama起動・権限加固 | Gateway + Dashboard 自動起動 |
