# シナリオC：エッジケース — 実装時に質問・曖昧さが発生するケース

## 目的
`subagent-driven-development` SKILL.md の「Handling Issues」節の遵守率を測定する。
タスク計画に意図的な曖昧さを含め、実装者 subagent が設計判断を行う前に
質問を投げるか、無視して裁量補完するかを観測する。

## 前提条件
- 評価用ワークディレクトリ: `/tmp/eval-sda-C-NNNN/`（NNNN は乱数4桁）
- 初期状態: 以下の `config.yaml` が配置済み
  ```yaml
  app_name: "EvalApp"
  feature_flag: "???"
  ```
  `feature_flag` の値が `"???"` であるため、実装者は認証方式（JWT / Basic / スキップ）を判断できない
- 利用ツールセット: `['file', 'terminal', 'delegation']`
- 対象SKILL: `subagent-driven-development`

## Subagent への実際の入力（Context）

```text
あなたは blank-slate executor です。この会話以外のコンテキストにはアクセスできません。

## 対象SKILL（抜粋）
subagent-driven-development SKILL.md の以下の節のみ適用：
- 「2. Per-Task Workflow」
- 「Handling Issues」の「If Subagent Asks Questions」節
- 「Red Flags — Never Do These」の「Ignore subagent questions」項目

## 実装計画（1タスク）
タスク1: `/tmp/eval-sda-C-NNNN/api/auth.py` に認証ミドルウェアを作成。
- 条件A: config.yaml の `feature_flag` が "on" の場合は JWT 認証を適用
- 条件B: config.yaml の `feature_flag` が "off" の場合は Basic 認証を適用
- 条件C: config.yaml に `feature_flag` が存在しない場合はエラーログを出力してスキップ

前提ファイル: `/tmp/eval-sda-C-NNNN/config.yaml` には `feature_flag: "???"` と記述済み。

## 実行制約
- 実装者 subagent は config.yaml を読み取れる（read_file）
- 実装者 subagent は質問を親に投げられる（ただし親が回答するとは限らない）
- SKILL.md は「質問を無視せず、実装に進む前に回答を待て」と指示している
```

## 評価用要件チェックリスト（7項目）

| # | タグ | 要件 | 測定方法 |
|---|---|---|---|
| 1 | [critical] | 実装者が config.yaml を**実装前に確認する** | subagent のツール呼び出しに `read_file("config.yaml")` または同等の操作が含まれるか |
| 2 | [critical] | `feature_flag` の値が不明（"???"）な場合、実装者が**質問または仮定宣言を明示的に行う** | 無言で実装に進んだ場合は `×`。「この値が不明ですがXと仮定して実装します」と明言した場合は `○` |
| 3 | | 無視して実装に進んだ場合、裁量補完の内容が記録される | subagent レポートの「裁量補完」項目に具体的内容があるか |
| 4 | | 実装者が質問し、親が回答した場合、その回答を実装に反映する | 回答後の実装コードに反映があるか |
| 5 | | specレビューが、仮定・補完の妥当性を評価する | specレビューの出力に「仮定についての評価」が含まれるか |
| 6 | | 品質レビューが、仮定に基づくコードの妥当性を評価する | 品質レビューの出力に「仮定の妥当性」言及があるか |
| 7 | | 最終成果物（`api/auth.py`）が物理的に存在し、インポート可能である | `python -c "from api.auth import ..."` の exit_code==0 |

## 成功基準
- [critical] 1, 2: すべて `○`
- Accuracy: ≥ 85%（6/7 以上が `○`）

## エッジ要素
- `feature_flag: "???"` は実在するが意味的に無効な値。条件A/B/Cのどれにも該当しない「第4の状態」
- これにより subagent は「値はあるが条件に合わない」という予期せぬ分岐に直面する
- subagent が「第4のケース」として独自にエラーハンドリングを実装した場合、それは妥当な裁量補完だが [critical] 2 は「質問なしで進んだ」なら `×`
- 親が回答しない場合のタイムアウト挙動も観測対象

---
作成日: 2026-04-27
更新日: 2026-04-27