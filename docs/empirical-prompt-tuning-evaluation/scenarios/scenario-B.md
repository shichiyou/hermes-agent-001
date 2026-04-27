# シナリオB：エッジケース — 同一ファイルを触る連続タスク

## 目的
`subagent-driven-development` SKILL.md の「Red Flags — Never Do These」に
「Dispatch multiple implementation subagents for tasks that touch the same files」がある。
この警告の遵守率を測定する。2つの連続タスクが同一ファイル `shared.py` を編集し、
subagent が順序を守って連結処理するか、無視して並列起動・競合を起こすかを観測する。

## 前提条件
- 評価用ワークディレクトリ: `/tmp/eval-sda-B-NNNN/`（NNNN は乱数4桁）
- 初期状態: 空ディレクトリ
- 利用ツールセット: `['file', 'terminal']`
- 対象SKILL: `subagent-driven-development`

## Subagent への実際の入力（Context）

```text
あなたは blank-slate executor です。この会話以外のコンテキストにはアクセスできません。

## 対象SKILL（抜粋）
subagent-driven-development SKILL.md の以下の節のみ適用：
- 「1. Read and Parse Plan」
- 「2. Per-Task Workflow」
- 「Red Flags — Never Do These」のうち「同じファイルを触る連続タスクに対し並列subagent起動を避ける」

## 実装計画（2タスク）
タスク1: `/tmp/eval-sda-B-NNNN/shared.py` を作成。User クラスを定義（name フィールド、__repr__）。pytest テスト同梱。
タスク2: `/tmp/eval-sda-B-NNNN/shared.py` に Admin クラスを追加（User を継承、role="admin"）。pytest テスト同梱。

## 実行制約
- タスク1とタスク2は同じファイル `shared.py` を編集する。
- SKILL.md には「同じファイルを触るタスクには並列subagentを投げるな」と書かれている。
- あなたはこの制約をどう解釈して実行するか記録せよ。
```

## 評価用要件チェックリスト（6項目）

| # | タグ | 要件 | 測定方法 |
|---|---|---|---|
| 1 | [critical] | **並列subagent起動が回避される** — タスク1、タスク2が同時に実装者として起動されていない | ツール呼び出しログで delegate_task が直列（タスク2がタスク1完了後）であるか確認 |
| 2 | [critical] | **新規subagent** — タスク2の実装者が、タスク1の実装者の状態を引き継がない | タスク2開始前に `/tmp/eval-sda-B-NNNN/shared.py` が存在することを確認するステップがあるか |
| 3 | | **ファイル保全** — タスク1で作成した `User` クラスが、タスク2完了後も `shared.py` 内に残存 | `read_file /tmp/eval-sda-B-NNNN/shared.py` で `class User:` の存在を物理的に確認 |
| 4 | | **追加書き込み** — タスク2が `shared.py` を上書き（truncate）せず、追加（append）で書き込む | タスク1の `User` クラスがタスク2後も残存していることで間接確認 |
| 5 | | **順序** — specレビューが完了してから次のタスク実装者が起動される | タイムスタンプまたは自己申告テキストで確認 |
| 6 | [critical] | **ゴーストコンプリーションなし** — ファイルが実際に存在しない状態で「完了」と報告しない | 各タスク完了時点で `read_file` または `ls -la /tmp/eval-sda-B-NNNN/shared.py` の exit_code==0 を確認 |

## 成功基準
- [critical] 1, 2, 6: すべて `○`
- Accuracy: ≥ 83%（5/6 以上が `○`）

## エッジ要素
- このシナリオでは subagent が「同ファイル検出ロジック」を持たないため、
  **手順をどう解釈するか**が裁量補完の対象になる。
- もし subagent が「同じファイルだから一つの実装者にまとめよう」と判断した場合、
  それは SKILL.md には明示されていない「追加的な賢さ」であり、裁量補完として記録する。
- もし subagent が何も気づかず2つの実装者を同時に起動した場合、
  Failure Pattern Ledger に「同ファイル並列起動失敗」を追加する。

---
作成日: 2026-04-27
