- Wiki: /workspaces/hermes-agent-001/wiki, ~/wikiはsymlink, GitHub shichiyou/wiki Private
§
## Discord Gateway 運用メモ（Private Bot）
- Bot Permissions: View Channels, Send, Send in Threads, Embed, Attach, Read History, Add Reactions
- Privileged Intents: Server Members ON, Message Content ON 必須
- DISCORD_ALLOWED_USERS必須（未設定=全許可となる実装）
- **ロールメンション（@役職）は反応しない** — `message.mentions`に含まれないため。ユーザーメンション（@Bot名）を使うこと
- manage_threads権限なし。auto_thread有効だがスレッド作成不可でフォールバック動作
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
Project root mapping: The "official" project root in documentation/Wiki is `/workspaces/hermes-agent-001`, but the actual active environment is `/workspaces/hermes-agent-001`. The agent must treat Wiki as "canonical" and map it to the actual physical paths during execution.
§
When working with Git submodules, user expects parent repository submodule pointers to be committed and pushed alongside submodule changes. Missing this step is treated as incomplete work, even after declaring the submodule work itself "done".
§
## Post-Submodule-Work Verification Protocol (Self-Correction)
After reporting completion of work inside a Git submodule (e.g., `experiences/*`, `wiki`), the agent MUST perform `git status --short` in the parent repository (`/workspaces/hermes-agent-001/`) BEFORE declaring the task fully done. A submodule pointer update is an uncommitted change (`M <path>`) in the parent repo and must be staged, committed, and pushed separately. This check is non-negotiable; skipping it constitutes a "Ghost Completion".