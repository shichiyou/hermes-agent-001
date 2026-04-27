# 統合評価計画書：Empirical Prompt Tuning on `subagent-driven-development`

## 1. 評価対象

| 項目 | 内容 |
|---|---|
| 対象SKILL | `subagent-driven-development` (software-development カテゴリ) |
| 評価プロトコル | `empirical-prompt-tuning` (software-development カテゴリ) |
| 評価者 | 親エージェント（本セッション） |
| 被験者（Executor） | 白紙状態の `delegate_task` subagent |

## 2. シナリオ概要

| ID | タイプ | 目的 | タスク数 | 固有のエッジ要素 |
|---|---|---|---|---|
| A | Median Realistic | 標準フロー（独立タスク3つのバッチ実行） | 3 | バッチ投入時の「specレビュー→品質レビュー」順序の遵守 |
| B | Edge Case | 同一ファイル `shared.py` を触る連続タスク | 2 | 「同じファイルに並列subagentを投げるな」の警告遵守 |
| C | Edge Case | 設計に曖昧さがあるケース（認証方式不明） | 1 | 「質問をしてから実装に進む」の遵守 |

## 3. ディレクトリ構造

```
/workspaces/hermes-agent-001/docs/empirical-prompt-tuning-evaluation/
├── README.md                    # 本ファイル（統合計画書）
├── planning/                    # 計画関連
│   └── evaluation-plan.md      # 評価計画の詳細
├── scenarios/                   # シナリオ定義（subagent投入用の実行コンテキスト）
│   ├── scenario-A.md          # シナリオA：独立タスク3つのバッチ実行
│   ├── scenario-B.md          # シナリオB：同一ファイル連続タスク
│   └── scenario-C.md          # シナリオC：曖昧設計・質問挙動
├── templates/                   # 評価用テンプレート
│   └── invocation-template.md  # subagentへの実際の実行指示文テンプレート
├── results/                     # 実行結果
│   ├── iter-01/             # イテレーション1（ベースライン）
│   ├── iter-02/             # イテレーション2（パッチ適用後）
│   └── iter-03/             # イテレーション3（最終確認）
├── artifacts/                   # 物理的証拠
│   ├── iter-01/
│   ├── iter-02/
│   └── iter-03/
└── failure-pattern-ledger.md   # Failure Pattern 台帳
```

## 4. 実施手順（7ステップ）

### Step 0: Static Consistency Check（静的構造ミスマッチチェック）
- [ ] 対象SKILLの `description` と `body` の整合性確認
- [ ] 必須ツール名が Hermes 用語で記述されているか確認
- [ ] 環境制約が明示されているか確認
- [ ] 成功基準と検証ステップが存在するか確認

### Step 1: Baseline Preparation（ベースライン作成）
- [ ] シナリオA/B/Cの実行コンテキストを作成
- [ ] 各シナリオに3〜7要件を定義（最低1つ `[critical]`）
- [ ] 評価後にチェックリストを変更しない誓約

### Step 2: 1st Empirical Iteration（第1回実証実行）
- [ ] シナリオA: `delegate_task` 起動（バッチ3タスク）
- [ ] シナリオB: `delegate_task` 起動（同一ファイル連続タスク）
- [ ] シナリオC: `delegate_task` 起動（曖昧設計・質問）
- [ ] 結果回収・要件スコアリング表作成
- [ ] Failure Pattern Ledger 初期化

### Step 3: Parent-Side Evaluation（親側評価）
- [ ] Success/Failure（[critical] 項目から）
- [ ] Accuracy 計算
- [ ] Weak Phase 特定
- [ ] 不明瞭点 → Issue/Cause/General Fix Rule に構造化
- [ ] 裁量補完記録
- [ ] 再試行カウント

### Step 4: Patch Discipline（パッチ適用）
- [ ] 連続する2回のイテレーションで同じ General Fix Rule が再発したか確認
- [ ] 前回の修正がなぜ再発を防げなかったか分析
- [ ] Fix target → Patch location → Expected effect のマッピング作成
- [ ] `skill_manage(action="patch")` で最小パッチ適用
- [ ] `skill_view` / `read_file` で物理的証拠を確認

### Step 5: 2nd/3rd Empirical Iteration（再評価）
- [ ] 同じシナリオを新規 subagent で再実行
- [ ] 結果比較
- [ ] 収束または発散判定

### Step 6: Hold-out Verification（ホールドアウト検証）
- [ ] チューニング未使用の新シナリオを1つ追加
- [ ] Accuracy が直近チューンドシナリオと比較して15ポイント以上低下した場合、過適合と見なしてシナリオ設計再開

### Step 7: Final Reporting（最終報告）
- [ ] `report.md` に全体サマリ作成
- [ ] 残存リスクを開示
- [ ] 対象SKILLを `final-tuned` バージョンとして保存

## 5. 停止条件

| 条件 | 判定基準 |
|---|---|
| **Converged（通常）** | 連続2イテレーションで：新不明瞭点ゼロ、[critical]ゼロ、accuracy改善≤3%、再試行増加なし |
| **High-importance** | 連続3回 clean（高重要度プロンプト用） |
| **Diverged** | 3回以上イテレーション後、新不明瞭点が減少しない → 構造再設計 |
| **Resource stop** | ユーザーが残存リスク許容またはコスト超過を宣言 |

## 6. タイムスタンプ管理

| フェーズ | 開始 | 終了 | 実行者 |
|---|---|---|---|
| Step 0 | 2026-04-27 | 2026-04-27 | 親エージェント |
| Step 1 | — | — | 待機中 |
| Step 2 | — | — | 待機中 |
| ... | | | |

---
作成日: 2026-04-27
ステータス: 計画書完成・実行待機中
