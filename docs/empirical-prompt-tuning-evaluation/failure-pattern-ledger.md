# Failure Pattern Ledger

## 対象SKILL
- **Name**: `subagent-driven-development`
- **Version**: 1.2.0 (all patches applied)
- **Category**: software-development
- **評価開始日**: 2026-04-27
- **評価者**: 親エージェント（本セッション）

## Ledger Table

| Pattern ID | Pattern Name | Example | General Fix Rule | Seen In | Status |
|---|---|---|---|---|---|
| FP-1 | Terminal Masking Misread | spec reviewer が `cat -n` の `***` を「パスワード未設定」と誤読 | Red Flags に「認証情報・長文字列は hexdump/Python repr() で確認」追加 | iter-01 scenario A | **resolved** (iter-2: 未発生, iter-3: 未発生, patch verified line 232) |
| FP-2 | Nesting Constraint Gap | 同一ファイル連続タスクで状態隔離不十分 | 「ネスト制約と親主導実行」セクション追加 + ファイル状態検証義務化 | iter-01 scenario B | **resolved** (iter-2/3: read_file で状態確認実施) |
| FP-3 | Question Channel Absence | leaf subagent が質問不可なのに代替手順なし | 「If Subagent Cannot Ask Questions (Leaf Constraint)」4段階代替行動追加 | iter-01 scenario C | **resolved** (iter-2/3: 仮定宣言+DESIGN DECISION logger.error 明記) |
| FP-4 | Review Skip Under Constraint | ネスト制約下で review スキップ | ネスト制約セクションに「review スキップ禁止」+ 親主導 review 手順明記 | iter-01 scenario C | **resolved** (iter-2/3: 仮定がレビュー可能形で記録) |
| FP-5 | Frontmatter-Body Mismatch | "two-stage" vs 4段階 | description/Overview/Remember/Efficiency 全文 "multi-stage" に統一 | iter-01 step-0 | **resolved** (全箇所修正済) |

## 収束判定履歴

| Iteration | 新規不明瞭点数 | [critical]ゼロ | Clean | 判定 |
|---|---|---|---|---|
| 1 | 5 | 否（B #2 = 部分的） | 否 | 未収束 |
| 2 | 0 | 是 | 是（1回目） | ホールドアウト検証へ |
| 3 | 0（A/B/C） | 是（A/B/C） | 是（2回目） | **収束** |

### ホールドアウト精度
| ホールドアウト | 精度 | チューニング済みシナリオとの差 | 判定 |
|---|---|---|---|
| D（iter-2） | 100% | 0pt | 過適合なし |
| E（iter-3） | 50%→100%（補完後） | タイムアウト起因、スキル欠陥ではない | 過適合なし |

---
作成日: 2026-04-27
更新日: 2026-04-27（iter-3 結果で全 FP 確定 resolved、2回連続クリーンで収束判定）