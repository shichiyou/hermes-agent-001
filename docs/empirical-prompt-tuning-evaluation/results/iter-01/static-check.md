# Step 0: Static Consistency Check 結果

## 検査日時
2026-04-27T09:00:00Z

## 対象
`subagent-driven-development` SKILL.md (v1.1.0, 11,335 chars)

## 検査項目

| # | 検査項目 | 判定 | 証拠 |
|---|---|---|---|
| 0a | frontmatter `description` と body の整合性 | × | description: "two-stage review (spec then quality)" — body は実装者+spec+quality+final の4段階構造。"two-stage" は spec+quality の2段を意味するが、Final Review の存在がdescriptionに反映されていない |
| 0b | 必須ツール名が Hermes 用語 | ○ | delegate_task, read_file, todo, terminal など Hermes 用語で統一 |
| 0c | 環境制約が明示 | × | subagent ネスト制約（leaf subagent は delegate_task 不可）についての言見なし。実行環境前提が暗黙 |
| 0d | 成功基準と検証ステップの存在 | × | 「spec reviewer が PASS」が暗黙基準だが、成果物レベルの成功基準（exit_code, import 可否など）が未定義 |
| 0e | body に実際の手順が存在 | ○ | 4セクションに具体的手順あり |

## 判定
5項目中3項目に問題あり（0a, 0c, 0d）。

## 取扱方針
Step 0 の発見をイテレーション1のベースライン評価に含める。
事前パッチはベースラインを汚染するため実施しない。
イテレーション1の結果に基づき Step 4 でパッチ適用を判断する。