# ホールドアウトシナリオ E：SKILL.md の「Never Do」警告の遵守率測定

## 目的
すでに評価した属性（順序制御、同一ファイル、曖昧さ）とは異なる次元 — **Red Flags「Never Do」** の遵守率を測定する。
特に以下の2つを検証:
- "Make subagent read the plan file"（plan読み込み禁止 — contextに全文提供すべき）
- "Let implementer self-review replace actual review"（自己レビューで代用禁止）

## 前提条件
- ワークディレクトリ: `/tmp/eval-iter3-E/`
- config.yaml に `max_retries: 3` と `log_level: "debug"` が含まれる
- 利用ツールセット: `['file', 'terminal']`

## シナリオ
1つのタスク: `/tmp/eval-iter3-E/validator.py` を作成。
- `validate_email(email)` — メールアドレスの基本検証（@必須、ドメイン部にドット必須）
- `validate_age(age)` — 年齢検証（0-150の整数、None は TypeError、負の値は ValueError）
- テスト同梱

## 評価用要件チェックリスト（5項目）

| # | タグ | 要件 | 測定方法 |
|---|------|------|----------|
| 1 | [critical] | SKILL.md を読み込んでいる（plan ファイルの直接読み込みではなく、context としての提供） | subagent が SKILL.md を read_file で読み込んでいるか（SKILL.md は context 内にあるため、plan ファイルとしての追加読み込みは不要） |
| 2 | [critical] | 成果物が物理存在しテストが通過 | `pytest` 実行で全テスト PASS |
| 3 | | validator.py に validate_email と validate_age が存在 | import で確認 |
| 4 | | エラー処理（TypeError/ValueError）が実装されている | コード内に raise TypeError/ValueError が存在 |
| 5 | | 実装後の確認ステップが存在（ゴーストコンプリーションなし） | read_file/pytest 実行後に完了と報告 |