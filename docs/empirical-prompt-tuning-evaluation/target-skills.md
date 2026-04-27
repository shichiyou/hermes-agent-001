# 評価対象スキル候補一覧と選定理由

## Bundle vs 非 Bundle 一覧

### Bundle 対象（Hub 配布）
`apple-notes`, `apple-reminders`, `architecture-diagram`, `arxiv`, `ascii-art`, `ascii-video`, `audiocraft-audio-generation`, `axolotl`, `baoyu-comic`, `baoyu-infographic`, `blogwatcher`, `claude-code`, `codebase-inspection`, `codex`, `design-md`, `dogfood`, `dspy`, `evaluating-llms-harness`, `excalidraw`, `findmy`, `fine-tuning-with-trl`, `gif-search`, `github-auth`, `github-code-review`, `github-issues`, `github-pr-workflow`, `github-repo-management`, `godmode`, `google-workspace`, `heartmula`, `hermes-agent`, `himalaya`, `huggingface-hub`, `ideation`, `imessage`, `jupyter-live-kernel`, `linear`, `llama-cpp`, `llm-wiki`, `manim-video`, `maps`, `minecraft-modpack-server`, `nano-pdf`, `native-mcp`, `notion`, `obliteratus`, `obsidian`, `ocr-and-documents`, `opencode`, `openhue`, `outlines`, `p5js`, `pixel-art`, `plan`, `pokemon-player`, `polymarket`, `popular-web-designs`, `powerpoint`, `requesting-code-review`, `research-paper-writing`, `segment-anything-model`, `serving-llms-vllm`, `songsee`, `songwriting-and-ai-music`, `spotify`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `unsloth`, `webhook-subscriptions`, `weights-and-biases`, `writing-plans`, `xurl`, `youtube-content`

### 非 Bundle（オリジナル・この環境限定）
| スキル名 | 説明 | empirical-prompt-tuning 適用可否 |
|---|---|---|
| `ai-agent-conduct` | 原則・方針の列挙 | 実行手順が少なく測定困難 |
| `aidlc-codd-experience-setup` | 環境構築手順 | 実行に時間がかかりすぎる |
| `aidlc-v-model-operations` | V字モデル運用手順 | 実行に時間がかかりすぎる |
| `an-anti-hallucination-framework` | 反ハルシネーションプロトコル | **適用可能**。文章量が適度で Raw Output 遵守率を測定可能 |
| `empirical-prompt-tuning` | 本プロトコル自身 | 自己適用はメタ的すぎる |
| `intellectual-integrity-verification` | 知的誠実性検証 | 原則列挙が中心で測定困難 |
| `physical-evidence-first-verification` | 物理的証拠優先検証 | **最適**。ファイル操作後の `read_file`/`git status` 遵守を数値化可能 |
| `physical-verification-failure-recovery` | 検証失敗復旧 | エッジケース特化で一般シナリオ設計が難しい |
| `root-cause-analysis` | 根本原因分析 | 4phase手順は測定可能だが時間がかかる |
| `workspace-hygiene` | 親リポジトリ汚染防止 | 環境依存が強すぎる |

## 選定理由：subagent-driven-development

| 観点 | 評価 |
|---|---|
| **構造的測定性** | specレビュー→品質レビューの順序、同ファイル並列禁止、self-review代替禁止などが明確なチェック項目となる |
| **delegate_task 親和性** | 対象スキルが `delegate_task` を頻繁に使用し、評価プロトコルも `delegate_task` を使用することで一貫性がある |
| **実行コスト** | コード生成タスクとして完了まで数分程度で収まる |
| **改善効果の可視性** | 手順の順序や粒度の問題は、パッチ適用後に明確なスコア変化として現れる |
| **Red Flags の適用** | 赤旗に挙げられた誤り（順序逆転、subagent再利用、self-review代替など）が実際に測定できる |

## 第2候補

| 順位 | スキル名 | 選ばなかった理由 |
|---|---|---|
| 2 | `physical-evidence-first-verification` | 優先度1と同等だが、ファイル操作手順の測定は subagent-driven-development に包含される側面があるため、第2イテレーションで実施 |
| 3 | `an-anti-hallucination-framework` | 文章量が少なくイテレーション回数が少なく済むが、測定可能な構造がやや弱い |
