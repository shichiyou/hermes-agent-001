# Failure Pattern Ledger

## 対象SKILL
- **Name**: `subagent-driven-development`
- **Version**: 1.1.0
- **Category**: software-development
- **評価開始日**: 2026-04-27
- **評価者**: 親エージェント（本セッション）

## Ledger Table

| Pattern ID | Pattern Name | Example | General Fix Rule | Seen In | Status |
|---|---|---|---|---|---|
| FP-1 | Terminal Masking Misread | spec reviewer が `cat -n` の `***` マスキングを「パスワード未設定」と誤読し FAIL 報告 | レビュー手順に「認証情報・長文字列は hexdump/Python repr() で確認」を明記 | iter-01 scenario A | open |
| FP-2 | Nesting Constraint Gap | leaf subagent が delegate_task 不可なのに SKILL.md にネスト制約の記載がなく、同一ファイル連続タスクで状態隔離不十分 | 「ネスト制約と親主導実行」セクションを追加し、状態隔離方法を明記 | iter-01 scenario B | open |
| FP-3 | Question Channel Absence | SKILL.md が「質問してから実装に進む」を指示するが、leaf subagent には親への質問チャネルがない | 「subagent は質問不可」前提を明記し、代替行動（仮定宣言＋エラーログ）を正規手順化 | iter-01 scenario C | open |
| FP-4 | Review Skip Under Constraint | ネスト制約下で spec/quality review がスキップされ、実装+自己評価で完結 | 「ネスト制約時は親が spec/quality review を逐次起動」を Per-Task Workflow に追記 | iter-01 scenario C | open |
| FP-5 | Frontmatter-Body Mismatch | description "two-stage review" が body の 4段階構造（実装+spec+quality+final）と不一致 | frontmatter を「multi-stage review (spec compliance, code quality, final integration)」に修正 | iter-01 step-0 | open |

## 現在の Failure Patterns（イテレーションごとに更新）

### Iteration 1
- FP-1: Terminal masking misread — open
- FP-2: Nesting constraint gap — open
- FP-3: Question channel absence — open
- FP-4: Review skip under constraint — open
- FP-5: Frontmatter-body mismatch — open

## 収束判定履歴

| Iteration | 新規不明瞭点数 | [critical]ゼロ | Clean | 判定 |
|---|---|---|---|---|
| 1 | 5 | 否（B #2 = 部分的） | 否 | 未収束 |

---
作成日: 2026-04-27
更新日: 2026-04-27