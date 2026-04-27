# シナリオA：通常ケース — 独立タスク3つのバッチ実行

## 目的
`subagent-driven-development` SKILL.md の標準フローを測定する。
3つの独立したタスクを順次処理し、各タスクが手順通り「実装者→specレビュー→品質レビュー」を完遂するか検証する。

## 前提条件
- 評価用ワークディレクトリ: `/tmp/eval-sda-A-6947/`
- 初期状態: 空ディレクトリ
- 利用ツールセット: `['file', 'terminal']`
- 対象SKILL: `subagent-driven-development`

## Subagent への実際の入力（Context）

```text
あなたは blank-slate executor です。この会話以外のコンテキストにはアクセスできません。

## 対象SKILL（抜粋）
subagent-driven-development SKILL.md の以下の節のみ適用：
- 「1. Read and Parse Plan」：計画を読み込み todo list を作成
- 「2. Per-Task Workflow」：
  - Step 1: Dispatch Implementer Subagent
  - Step 2: Dispatch Spec Compliance Reviewer
  - Step 3: Dispatch Code Quality Reviewer
  - Step 4: Mark Complete
- 「Red Flags — Never Do These」：全部適用

## 実装計画（3タスク）
タスク1: `/tmp/eval-sda-A-6947/models/user.py` を作成。User クラス（email, password_hash）。pytest テスト同梱。
タスク2: `/tmp/eval-sda-A-6947/utils/hash.py` を作成。bcrypt ベースのハッシュ関数。pytest テスト同梱。
タスク3: `/tmp/eval-sda-A-6947/api/routes.py` を作成。Flask 用login Blueprint。pytest テスト同梱。

## 実行制約
- 各タスクは独立。ファイル間に依存関係なし。
- 各タスクの実装者は新規 subagent として起動。
- specレビューが PASS してから品質レビューを起動。
- 最後に Final Integration Reviewer を起動。
```

## 評価用要件チェックリスト（7項目）

| # | タグ | 要件 | 測定方法 |
|---|---|---|---|
| 1 | [critical] | タスク1〜3の実装者が、**各々別の delegate_task として起動される** | subagent 実行後、親セッションで `process(action="list")` または `delegate_task` の返却に `task_id` が3つ存在するか確認 |
| 2 | [critical] | 各タスクの specレビューが PASS してから、次のレビュー（品質）が起動される | subagent の自己申告または親側のツール呼び出し順序ログで確認 |
| 3 | [critical] | Final Integration Reviewer が、全タスク完了後に1回だけ起動される | 実行後の subagent 起動回数カウント |
| 4 | | タスク1の成果物: `models/user.py` が存在し `User` クラスが物理的に確認できる | `read_file` または `python -c "import models.user; print(models.user.User)"` の exit_code==0 |
| 5 | | タスク2の成果物: `utils/hash.py` が存在し `hash_password` 関数が呼び出せる | `python -c "from utils.hash import hash_password; hash_password('x')"` の exit_code==0 |
| 6 | | タスク3の成果物: `api/routes.py` が存在し `Flask` Blueprint がインポート可能 | `python -c "from api.routes import login_bp"` の exit_code==0 |
| 7 | | 3つのタスクに対して、品質レビューが全て APPROVED を返す | subagent の自己申告に「Verdict: APPROVED」が3回含まれるか |

## 成功基準
- [critical] 1, 2, 3: すべて `○`
- Accuracy: ≥ 85%（6/7 以上が `○`）

## エッジ要素
- バッチ投入時、親が3タスクを同時に投げても、**SKILL.md は「各タスク独立して review」を要求**している。しかし実際には「全タスクの specレビューが終わってから品質レビューに進むべきか」が不明瞭 → この曖昧さが Failure Pattern になる可能性がある。
- もし subagent が「3タスクすべての実装を同時並行でやり、レビューは後で纏めてやろう」と解釈した場合、[critical] 2 は `×` とする。

---
作成日: 2026-04-27
更新日: 2026-04-27
