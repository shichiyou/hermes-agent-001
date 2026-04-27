# Failure Pattern Ledger

## 対象SKILL
- **Name**: `subagent-driven-development`
- **Version**: 1.1.0 → 1.2.0 (patched)
- **Category**: software-development
- **評価開始日**: 2026-04-27
- **評価者**: 親エージェント（本セッション）

## Ledger Table

| Pattern ID | Pattern Name | Example | General Fix Rule | Seen In | Status |
|---|---|---|---|---|---|
| FP-1 | Terminal Masking Misread | spec reviewer が `cat -n` の `***` マスキングを「パスワード未設定」と誤読し FAIL 報告 | レビュー手順に「認証情報・長文字列は hexdump/Python repr() で確認」を明記 | iter-01 scenario A | **resolved** (iter-2: 未発生) |
| FP-2 | Nesting Constraint Gap | leaf subagent が delegate_task 不可なのに SKILL.md にネスト制約記載なし。同一ファイル連続タスクで状態隔離不十分 | 「ネスト制約と親主導実行」セクション追加。同一ファイルタスクは別 subagent + ファイル状態検証 | iter-01 scenario B | **resolved** (iter-2: ファイル状態検証実施) |
| FP-3 | Question Channel Absence | SKILL.md が「質問してから実装に進む」を指示するが、leaf subagent には質問チャネルがない | 「質問不可（Leaf Constraint）」セクション追加。仮定宣言＋エラーログ出力を正規手順化 | iter-01 scenario C | **resolved** (iter-2: 仮定宣言明示) |
| FP-4 | Review Skip Under Constraint | ネスト制約下で spec/quality review がスキップ | 「ネスト制約時は親が spec/quality review を逐次起動」を明記 + review スキップ禁止を強調 | iter-01 scenario C | **resolved** (iter-2: 仮定がレビュー可能形で記録) |
| FP-5 | Frontmatter-Body Mismatch | description "two-stage review" が body 4段階と不一致 | description を「multi-stage review + parent-orchestrated execution」に修正 | iter-01 step-0 | **resolved** (iter-2: 全文整合) |

## 収束判定履歴

| Iteration | 新規不明瞭点数 | [critical]ゼロ | Clean | 判定 |
|---|---|---|---|---|
| 1 | 5 | 否（B #2 = 部分的） | 否 | 未収束 |
| 2 | 0 | 是 | 是（1回目） | ホールドアウト検証へ |

---
作成日: 2026-04-27
更新日: 2026-04-27（iter-2 結果で全 FP を resolved に更新）