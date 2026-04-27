# Step 4: パッチ設計 — イテレーション 1 → 2

## パッチ設計日時
2026-04-27T10:25:00Z

## テーマ選定
テーマ1: **ネスト制約と親主導実行**（FP-2, FP-3, FP-4）

理由: 
- [critical] 失敗（シナリオ B #2）に直結
- 3/5 FP がこのテーマに属する
- 実行時の最大の不確実性要因

テーマ2（レビュー品質向上: FP-1, FP-5）はイテレーション 2 の結果を見てから適用判断。

## パッチ対象と期待効果

### パッチ 1: frontmatter description 修正（FP-5）
- **Fix target**: FP-5 (Frontmatter-Body Mismatch)
- **Patch location**: frontmatter `description` フィールド
- **Expected effect**: "two-stage review" と body 4段階の不整合を解消
- **内容**: `two-stage review (spec compliance then code quality)` → `multi-stage review (spec compliance, code quality, final integration) with parent-orchestrated execution under nesting constraints`

### パッチ 2: 新セクション追加「Nesting Constraint and Parent-Orchestrated Execution」（FP-2, FP-4）
- **Fix target**: FP-2 (Nesting Constraint Gap), FP-4 (Review Skip Under Constraint)
- **Patch location**: Overview セクション直後、または The Process の前に新セクション
- **Expected effect**: leaf subagent のネスト制約と親主導の逐次実行パターンを明記することで、同一ファイル連続タスクの状態隔離と review スキップを防止
- **内容**:
  1. leaf subagent は delegate_task を呼び出せない制約を明記
  2. 親主導の逐次実行パターン（親が各 subagent を順次起動）を正規手順として定義
  3. 同一ファイルを触る連続タスクは、状態隔離のため必ず別の subagent で実行することを明記

### パッチ 3: 「Handling Issues」に質問チャネル不在の代替行動追加（FP-3）
- **Fix target**: FP-3 (Question Channel Absence)
- **Patch location**: 「Handling Issues > If Subagent Asks Questions」セクション
- **Expected effect**: leaf subagent が質問できない場合の正規代替行動（仮定宣言＋エラーログ出力）を定義
- **内容**: 「If the subagent cannot ask questions (e.g., leaf subagent without a response channel), it must: (1) explicitly state its assumption, (2) log the assumption as a design decision, (3) proceed with the safest interpretation」