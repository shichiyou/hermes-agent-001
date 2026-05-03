- Wiki: /workspaces/hermes-agent-001/wiki, ~/wikiはsymlink, GitHub shichiyou/wiki Private
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
For this user, recurrence prevention is only considered effective when applied to the actual control path that caused the failure; patching unused skills does not count as prevention.
§
When working with Git submodules, user expects parent repository submodule pointers to be committed and pushed alongside submodule changes. Missing this step is treated as incomplete work, even after declaring the submodule work itself "done".
§
## Post-Submodule-Work Verification Protocol (Self-Correction)
After reporting completion of work inside a Git submodule (e.g., `experiences/*`, `wiki`), the agent MUST perform `git status --short` in the parent repository (`/workspaces/hermes-agent-001/`) BEFORE declaring the task fully done. A submodule pointer update is an uncommitted change (`M <path>`) in the parent repo and must be staged, committed, and pushed separately. This check is non-negotiable; skipping it constitutes a "Ghost Completion".
§
Biome/VS Code multi-root: `.code-workspace` の `[/path]` 形式で `biome.enabled` を制御するのは信頼できない。root `/workspaces/hermes-agent-001/.vscode/settings.json` と `/home/vscode/.vscode/settings.json` で制御する。`/workspaces/hermes-agent-001/.hermes` は Hermes Agent 本体であり、削除・退避候補として扱わない。