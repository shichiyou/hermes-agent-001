## CLIエージェント動作特性
- Codex CLI: bubblewrap制限で`--dangerously-bypass-approvals-and-sandbox`が必要
- Claude Code: `--acp`削除済み、非対話は`-p`モード
- ollama launch: モデルルーティング自動化
- /home/vscodeはnamed volume（down -vで消滅）、/workspacesはホストバインド（安全）

## Wiki/Cron環境 統合（2026-04-19）
- Wiki: /workspaces/hermes-agent-001/wiki, ~/wikiはsymlink, GitHub shichiyou/wiki Private
- hermes gateway必須（cronスケジューラが内部スレッド）。~/.bashrcに自動起動設定済み
- Grounding Directive: 全7jobに注入済み（simulation hallucination防止）
- wiki-daily-summaryはdeliver=local（originで配信エラー）
- SOP: SOP.md Physical Evidence First。Wiki操作: SCHEMA→index→logの順で読む
§
## Hermes Agent Discord Gateway 設定（Private Bot運用）

### Private Bot設定手順の重要な順序
1. Installation → Install Link → None に変更して保存（先にやらないとPublic Bot OFFを保存できない）
2. Bot → Public Bot OFF, Require OAuth2 Code Grant OFF → Save Changes
3. Bot → Privileged Gateway Intents → Server Members ON, Message Content ON → Save
4. OAuth2 → URL Generator → bot + applications.commands スコープ + Bot Permissions → URL生成

### 既知のセキュリティ問題（コード監査済み）
- `discord.py:1397`: ALLOWED_USERS未設定→全員許可（必ずDISCORD_ALLOWED_USERSを設定）
- `discord.py:3119`: 承認ボタンの_check_authが空allowlist→誰でも承認可能
- `session.py:258,240`: display_name/channel_topicがシステムプロンプトに未サニタイズで流入
- ツールセットがCLIと同一（terminal, read_file等が承認なしで利用可能）
§
## Discord Gateway 運用メモ（Private Bot）
- Bot Permissions: View Channels, Send, Send in Threads, Embed, Attach, Read History, Add Reactions
- Privileged Intents: Server Members ON, Message Content ON 必須
- DISCORD_ALLOWED_USERS必須（未設定=全許可となる実装）
- **ロールメンション（@役職）は反応しない** — `message.mentions`に含まれないため。ユーザーメンション（@Bot名）を使うこと
- manage_threads権限なし。auto_thread有効だがスレッド作成不可でフォールバック動作
§
## Devcontainer DR（feat/devcontainer-persistence）
- Claude Code消失: Dockerfile層がhome volumeマウントで隠蔽 → on-create.shフォールバックインストール
- Hermes 429: 3回リトライ10s間隔, .dr_recoveryマーカーで自動バックアップブロック
- クリーンDRテスト: `docker volume rm devcontainer-home-hermes-agent-001` → Rebuild
§
## 課題解決プロセス（thinking-framework常時適用）
障害→MECE分類+物理証拠確認→仮説→反証可能性自問→戦術設計
§
AGENTS.mdの原則(物理的証拠の最優先、ストーリー構築の禁止、Surgical Changesの徹底、誠実性の担保)を思考の最優先制約として遵守する。効率や完了報告よりも、正当なプロセスと物理的根拠を重視し、不都合な事実を隠さない。