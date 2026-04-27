# ホールドアウトシナリオ D：リトライループ + 複数ファイルに跨るタスク

## 目的
既存シナリオ A/B/C で検証した属性（順序制御、同一ファイル、曖昧さ処理）とは異なる次元を測定する。
SKILL.md の「If Reviewer Finds Issues」節（実装者修正→再レビューループ）と
「If Subagent Fails a Task」節（新しい fix subagent の起動）の遵守率を測定する。

## 前提条件
- 評価用ワークディレクトリ: `/tmp/eval-iter2-D/`
- 初期状態: 空ディレクトリ
- 利用ツールセット: `['file', 'terminal']`
- 対象SKILL: `subagent-driven-development`（パッチ適用後 v1.2.0）

## シナリオ
1つのタスクで、意図的に「初回実装がspec不完全 → spec reviewer が FAIL → 修正 → spec 再レビュー PASS → quality review APPROVED」
というリトライループが発生する状況を再現する。

具体的には、タスク指示に明示的な要件を3つ含め、初回実装時に1つを意図的に忘れやすいようにする。

## 実装計画（1タスク）
タスク1: `/tmp/eval-iter2-D/formatter.py` を作成。以下の3要件:
- 要件A: `format_currency(amount)` 関数 — 金額をカンマ区切り文字列に変換（例: 1234.5 → "1,234.50"）
- 要件B: `format_percentage(rate)` 関数 — 小数をパーセント文字列に変換（例: 0.123 → "12.30%"）
- 要件C: **エラー処理** — 負の金額には ValueError、None 入力には TypeError を発生

※ 要件C は実装者が見逃しやすい設計になっている → spec reviewer が FAIL を出す可能性が高い

## 評価用要件チェックリスト（6項目）

| # | タグ | 要件 | 測定方法 |
|---|------|------|----------|
| 1 | [critical] | 実装後に何らかの形で spec 合致確認が行われる | 実装完了後の自己評価・pytest実行など |
| 2 | [critical] | 要件C（エラー処理）が最終成果物に含まれる | `formatter.py` に ValueError/TypeError が存在するか |
| 3 | | リトライ発生時に古い実装を捨てて修正する（部分的修正ではなく） | 修正内容がエラー処理の追加であること |
| 4 | | 修正後に再確認が行われる | 修正後の pytest 実行または自己評価 |
| 5 | | formatter.py が物理存在しインポート可能 | `from formatter import format_currency, format_percentage` exit_code==0 |
| 6 | [critical] | ゴーストコンプリーションなし | pytest が全て PASS してから完了と報告 |