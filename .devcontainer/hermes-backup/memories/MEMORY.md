- Wiki: /workspaces/hermes-agent-001/wiki, ~/wikiはsymlink, GitHub shichiyou/wiki Private
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
- クリーンDRテスト: `docker volume rm devcontainer-home-hermes-agent-001` → Rebuild
§
## 課題解決プロセス
障害→物理証拠→仮説→反証→戦術。日本語Markdown/audit追記はshell heredoc/printfを避け、write_file/read_file/patchで実施・検証する。
§
AGENTS.mdの原則(物理的証拠の最優先、ストーリー構築の禁止、Surgical Changesの徹底、誠実性の担保)を思考の最優先制約として遵守する。効率や完了報告よりも、正当なプロセスと物理的根拠を重視し、不都合な事実を隠さない。
§
Wikiはプロジェクトの正典(Master)であり、個別の実行環境のパスを書き込まず概念的に記述する。AI側で「Wikiの概念表現 $\rightarrow$ 現環境の物理パス」へのマッピングを行い、操作を完遂させる。
§
Emotional Design implementation: Priority is on "Reliability" and "Intellectual Satisfaction" via transparency and cognitive ease. Rules are codified in AGENTS.md: Standard Communication Structure (Conclusion -> Physical Evidence -> Details -> Value Delivered) and Conceptual Mapping (Wiki concepts -> current physical paths).
§
Project root mapping: The "official" project root in documentation/Wiki is `/workspaces/hermes-agent-lab`, but the actual active environment is `/workspaces/hermes-agent-001`. The agent must treat Wiki as "canonical" and map it to the actual physical paths during execution.