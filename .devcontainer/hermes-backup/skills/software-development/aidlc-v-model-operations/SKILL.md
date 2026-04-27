---
name: aidlc-v-model-operations
description: Operate and continuously improve an AI-DLC × V-model workflow using CoDD traceability, Graphify structural evidence, quality gates, human decision points, and physical Raw Output verification.
category: software-development
tags:
  - aidlc
  - v-model
  - codd
  - graphify
  - operations
  - traceability
  - governance
---

# AI-DLC × V字モデル運用改善スキル

## 目的

このスキルは、AI-DLC × V字モデル × CoDD × Graphify の仕組みを実際に運用し、運用中に見つかった不足を適切に改善するための手順です。

主眼は、AIエージェントが自律的に作業を進めつつ、仕様判断・リスク受容・ゲート例外・リリース判断などの人間判断を勝手に代替しないことです。

## 使うべき場面

このスキルは、次のいずれかに該当する場合に使います。

- AI-DLC運用定義に従って開発やラボ作業を進めるとき
- 曖昧な構想を、要求定義・要件定義・仕様合意へ収束させるとき
- AI-DLCの入口で、完全新規、グリーンフィールド、既存リポジトリへの新サービス追加、既存機能変更、非機能改善、障害対応などの開発案件分類を行うとき
- グリーンフィールド/ブラウンフィールドの違いを、Mermaidのフロー図・シーケンス図・ゲート表で認知負荷が下がる形に文書化するとき
- V字モデルの各フェーズ、ゲート、承認条件を運用するとき
- CoDDの要求・設計・コード・テストのトレースを確認または改善するとき
- `codd measure` のカバレッジ不足を改善するとき
- Graphify生成物や差分をレビューするとき
- 運用後の改善点を `docs/process/ai-agent-v-model-operating-model.md` に反映するとき
- サブモジュール型ラボで、ラボ側と親リポジトリ側を両方保全するとき

## 前提となる代表的なファイル

ラボまたは対象プロジェクトに、可能な限り以下が存在することを確認します。

```text
docs/process/ai-agent-v-model-operating-model.md
docs/process/ai-agent-requirements-prompt-guide.md
docs/process/ai-agent-v-model-prompt-guide.md
docs/process/v-model-development-process.md
wiki/concepts/aidlc-greenfield-brownfield-flow.md
codd/codd.yaml
sample-app/graphify-out/graph.json
sample-app/graphify-out/GRAPH_REPORT.md
```
```

存在しない場合は、「存在しない」と明示し、勝手に存在する前提で作業を進めないこと。

## 絶対ルール

1. `codd validate`, `codd scan`, `codd measure` のRaw Outputを見るまで、CoDD状態を語らない。
2. `status: draft` の運用定義を「承認済み標準」と呼ばない。
3. `Coverage: 0/... source files tracked` のような出力を見た場合、成果物トレース不足として扱う。
4. Graphify生成物の語数差分、JSONキー順、推定リンク方向の揺れを単独のCI失敗条件にしない。
5. Graphifyが対象ソースを読めない場合は失敗条件として扱う。
6. AIエージェントは、仕様判断・スコープ判断・リスク受容・リリース判断を人間の代わりに決めない。
7. 解釈余地がある場合は、選択肢・推奨案・リスクを添えて質問する。
8. 変更後は、テスト・CoDD・Git状態で物理的証拠を確認する。
9. サブモジュール型ラボでは、まずサブモジュールをコミット・pushし、その後、親リポジトリのサブモジュールポインタをコミット・pushする。
10. 最終報告には、コマンドとRaw Outputを必ず含める。

## 標準ワークフロー

### 1. 物理的な作業場所を確認する

対象がラボサブモジュールの場合、ラボルートを基準にする。

```bash
pwd
git status --short --branch
git log --oneline -3
```

親リポジトリも関係する場合は、親側も確認する。

```bash
git -C /workspaces/hermes-agent-001 status --short --branch
git -C /workspaces/hermes-agent-001 submodule status --recursive
```

### 2. 運用定義を読む

まず次を確認する。

```text
docs/process/ai-agent-v-model-operating-model.md
```

特に見る項目:

- frontmatter の `status`
- AIエージェントの自律実行条件
- 人間への質問・承認条件
- 品質ゲート
- CoDD frontmatter標準
- カバレッジ基準
- 逸脱管理
- この文書を基準にした次の整備順序

### 3. CoDD状態を確認する

```bash
. .venv/bin/activate  # venvがある場合
codd validate
codd scan
codd measure
```

確認するポイント:

| 出力 | 解釈 |
|---|---|
| `OK: validated ... Markdown files` | CoDD frontmatterの形式は妥当 |
| `Frontmatter: N documents in docs` | CoDDが認識した文書数 |
| `Graph: N nodes, M edges` | トレースグラフの規模 |
| `Coverage: A/B source files tracked` | 文書からコードが追跡されている割合 |
| warning/error | ゲート未達または改善対象 |

### 4. 現在状態を分類する

未成熟・未決定事項を次に分類する。

| 分類 | 例 |
|---|---|
| プロセス未承認 | 運用定義が `status: draft` のまま |
| 要求粒度不足 | 個別要求が `req:*` に分解されていない |
| 設計粒度不足 | 詳細設計やコンポーネント設計が不足 |
| トレース不足 | `depends_on`, `depended_by`, `source_files`, `test_files` が不足 |
| カバレッジ不足 | `Coverage: 0/... source files tracked` など |
| テスト対応不足 | 要求・設計とテストの対応が不明 |
| Graphify確認不足 | 対象コードがgraphに含まれるか未確認 |
| 自動検査不足 | `scripts/check_traceability_coverage.py` がない |
| 逸脱管理不足 | 逸脱記録テンプレートや例外承認記録がない |
| CI不足 | GitHub Actions等にゲートが組み込まれていない |

### 5. AI自律実行と人間確認を分ける

AIが自律実行してよい作業:

- 現状調査
- `codd validate`, `codd scan`, `codd measure`, `pytest`, `graphify update` の実行
- 既存規則に沿ったfrontmatter形式修正
- READMEリンク追加
- トレース表やテンプレートの案作成
- 明らかな文書構文修正

人間確認が必要な作業:

- 要求の採否
- スコープ変更
- 物理削除か論理削除かなどの業務判断
- 品質閾値の最終決定
- ゲート未達での例外進行
- リリース判断
- Graphify差分の意味が不明な場合の受容判断

### 6. 小さな変更要求で運用する

初回運用では、小さな変更要求を1件流して、運用定義が機能するか確認する。

例:

```text
タスク削除機能を追加する
```

このとき観察すること:

| 観察対象 | 見るべき挙動 |
|---|---|
| 要求定義 | 物理削除か論理削除かを人間に質問するか |
| 受入条件 | 削除済みタスクを一覧に出すか確認するか |
| 設計 | `TaskService` や `Repository` への影響を整理するか |
| CoDD | `req:*`, `design:*`, `source_files`, `test_files` を作るか |
| 実装 | テスト駆動で進めるか |
| Graphify | 影響範囲と構造変化を見るか |
| ゲート | pytest / codd validate / codd scan / カバレッジ確認を行うか |
| 逸脱 | 未決事項があれば停止・質問するか |

### 7. 改善点を反映する

運用中に見つかった不足は、次のいずれかへ反映する。

| 改善対象 | 例 |
|---|---|
| 運用定義 | 質問条件、ゲート条件、逸脱条件の追加 |
| テンプレート | CoDD frontmatter、質問テンプレート、逸脱記録 |
| 成果物 | 要求、設計、トレース表、テスト記録 |
| 自動検査 | カバレッジ検査、Graphify検査 |
| CI | `codd validate`, `codd scan`, `pytest`, traceability check |
| ハンズオン教材 | 手順、期待出力、失敗例、観察ポイント |

### 8. 検証する

変更後の最低検証:

```bash
python -m pytest -v sample-app/tests
codd validate
codd scan
codd measure
```

Graphifyを変更・再生成した場合:

```bash
graphify update sample-app
git diff -- sample-app/graphify-out/GRAPH_REPORT.md sample-app/graphify-out/graph.json
```

Graphify差分は、構造変化か生成揺れかを説明できる状態にする。

### 9. 保全する

サブモジュール型ラボの場合:

```bash
# submodule
cd /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab
git status --short --branch
git diff --name-status
git add <changed-files>
git commit -m "docs: ..."  # or feat/fix/test/chore
git push origin main
git rev-parse HEAD
git rev-parse origin/main

# parent
cd /workspaces/hermes-agent-001
git status --short --branch
git diff --submodule=log -- experiences/aidlc-codd-graphify-lab
git add experiences/aidlc-codd-graphify-lab
git commit -m "chore: update aidlc codd graphify lab ..."
git push origin main
git rev-parse HEAD
git rev-parse origin/main
git submodule status --recursive
```

## 質問テンプレート

人間判断が必要な場合は、以下の形式で質問する。

```markdown
## 判断が必要な事項

### 背景
何が不明確か、どの成果物・ゲートに影響するか。

### 選択肢
A. 案1
- 内容:
- 利点:
- リスク:
- 影響範囲:

B. 案2
- 内容:
- 利点:
- リスク:
- 影響範囲:

C. 保留
- 内容:
- 利点:
- リスク:
- 影響範囲:

### 推奨案
Aを推奨します。

### 推奨理由
既存要求との整合性、リスク、作業量、検証容易性の観点で理由を記述します。

### [Answer]
A / B / C / Other
```

## 報告テンプレート

最終報告では、以下を含める。

```text
結論:

実施内容:
- ...

物理的エビデンス:
1. git status
```text
...
```

2. pytest
```text
...
```

3. codd validate / scan / measure
```text
...
```

4. git commit / push
```text
...
```

未決定事項:
- ...

次の推奨:
- ...
```

## 成熟度判定

| 状態 | 判定 |
|---|---|
| 運用定義なし | 構想段階 |
| 運用定義あり、`status: draft` | 初版ベースライン |
| 小変更を1件流して改善済み | 試験運用済み |
| カバレッジ検査とCIゲートあり | 運用可能 |
| 逸脱管理・監査ログ・定期改善あり | 成熟運用 |
| 実案件で複数回使い、基準改定済み | 安定運用 |

## 要求定義・要件定義の扱い

AI-DLCでは、曖昧な初期要求も `Requirements Analysis (Adaptive)` の対象として扱う。

重要な区別:

| 項目 | 扱い |
|---|---|
| 曖昧な初期要求 | AIが `Clear` / `Vague` / `Incomplete` として分類する |
| 要求定義・要件定義 | `inception/requirements-analysis.md` の Requirements Analysis で実施する |
| 不明点・不足情報 | AIが質問として明示し、人間の回答を待つ |
| 人間判断 | 業務目的、スコープ、非機能要件水準、リスク受容、要求承認は人間が行う |
| 次工程への移行 | 要求文書レビューと明示承認後に進める |

確認すべき物理的根拠:

```text
.aidlc-rule-details/inception/requirements-analysis.md
```

特に確認する箇所:

- `Adaptive Phase: Always executes`
- `Request Clarity`: `Clear`, `Vague`, `Incomplete`
- `Thorough Completeness Analysis`
- `Generate Clarifying Questions`
- `GATE: Await User Answers`
- `Generate Requirements Document`

運用上の表現:

```text
AI-DLCは要求定義・要件定義を含んでいる。
ただし、AIが要求を勝手に決める工程ではない。
AIが曖昧な要求を構造化し、人間に質問し、合意可能な要求文書へ収束させる工程である。
```

この説明は、ユーザーが「AI-DLCでは要求定義や要件定義をカバーしていないのか」と質問した場合に再利用できる。

## 典型的な次の一手

現在のラボでよくある次の一手:

1. 要求を個別ID化する。
2. 詳細設計文書を追加する。
3. `source_files` を付与する。
4. `test_files` を付与する。
5. トレース表を作る。
6. カバレッジ検査スクリプトを作る。
7. 逸脱記録テンプレートを追加する。
8. CIゲートを追加する。
9. 小さな変更要求を1件流して、運用定義を改善する。
10. 十分に安定したら `status: approved` へ変更する。

## AIコーディングエージェントのドリフト対策計画を作る場合

ユーザーが「AIコーディングエージェントのドリフト対策」「OSS導入方針」「promptfoo / Langfuse / AgentOps / pre-commit / Danger JS / reviewdog / Semgrep / Guardrails / spec-kit との相性」などを、既存の AI-DLC × CoDD × Graphify ラボに適用したいと言った場合は、既存の AI-DLC / CoDD / Graphify を置き換える計画にしない。

推奨する判断順序:

1. 既存ラボの物理状態を確認する。
   - `git status --short --branch`
   - `test -e AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.aidlc-rule-details`
   - `test -e codd/codd.yaml`
   - `test -e sample-app/graphify-out/graph.json`, `GRAPH_REPORT.md`
   - `codd --version`
   - `graphify --help`
2. 既存の AI-DLC × CoDD × Graphify を中核として保持する。
3. 最優先は CoDD トレース密度改善にする。
   - `source_files`
   - `test_files`
   - 個別要求ID
   - 詳細設計文書
   - `codd measure` の coverage 改善
4. 次に pytest / CoDD / Graphify のCIゲート化を計画する。
5. その後に promptfoo でAI行動評価を追加する。
   - 承認なし実装禁止
   - 証拠なし完了禁止
   - スコープ外変更禁止
   - CoDD frontmatter必須
   - Graphify未実行主張禁止
6. Langfuse / AgentOps は AI-DLC audit の代替ではなく、LLM入出力・ツール呼び出しの実行観測レイヤーとして扱う。
7. pre-commit / Danger JS / reviewdog / Semgrep は Git差分・PRゲートとして扱う。
8. Guardrails AI / NeMo Guardrails は完了報告やJSON形式などの出力制約の補助扱いにする。
9. github/spec-kit は当面主役にしない。AI-DLC / CoDD と仕様管理の正典が分裂するため、導入するなら補助または取り込み元として再評価する。

適用計画書を作る場合の推奨パス:

```text
docs/process/ai-agent-drift-control-adoption-plan.md
```

CoDD frontmatter例:

```yaml
---
codd:
  node_id: "design:ai-agent-drift-control-adoption-plan"
  type: design
  status: draft
  depends_on:
    - id: "req:aidlc-codd-graphify-lab-requirements"
      relation: "derived_from"
    - id: "design:v-model-development-process"
      relation: "refines"
    - id: "design:ai-agent-v-model-operating-model"
      relation: "refines"
  confidence: 0.82
---
```

あわせて更新する相互参照:

- `docs/requirements/requirements.md` の `depended_by`
- `docs/process/v-model-development-process.md` の `depended_by`
- `docs/process/ai-agent-v-model-operating-model.md` の `depended_by`
- `README.md` の「実開発プロセスへの適用」と使い分け表

検証コマンド:

```bash
python -m pytest -v sample-app/tests
codd validate
codd scan
codd measure
git status --short --branch
git diff --name-status
git ls-files --others --exclude-standard
```

重要な報告ポイント:

- `codd validate` が新規文書を含むMarkdown数でOKになったこと。
- `codd scan` の node/edge 数。
- `codd measure` の coverage がまだ `0/... source files tracked` なら、それを隠さず Phase 1 の最優先課題として報告すること。
- 新規ファイルは `git diff --stat` に出ないため、`git ls-files --others --exclude-standard` も提示すること。

### ドリフト対策を実際に導入する場合の実装メモ

`docs/process/ai-agent-drift-control-adoption-plan.md` に従って対策を「計画」ではなく「導入」する場合は、次を再利用する。

1. Phase 1 の CoDD coverage 改善では、設計文書の frontmatter に `codd.source_files` / `codd.test_files` だけでなく、トップレベル `source_refs` も付ける。
   - 現行 `codd measure` は coverage 集計でトップレベル `source_refs` を読む実装だった。
   - `codd.source_files` だけでは `codd validate` / `codd scan` には有用でも、`codd measure` の `Coverage: A/B source files tracked` が改善しない場合がある。
2. `codd measure` の分母は `source_dirs` 配下の全ファイルを数える実装の場合があり、`__pycache__` 等の生成物が含まれて `5/9` のように見えることがある。
   - その場合は隠さず報告し、主要対象だけを判定する補助スクリプト（例: `scripts/check_traceability_coverage.py`）で `sample-app/src/**/*.py` の実カバレッジを別途検査する。
3. CI・pre-commit・promptfoo・検査スクリプトのような `docs/` 外の成果物は、CoDDグラフに載せたい場合、対応する説明文書を `docs/process/*.md` に作り、`depends_on` と必要なら `source_refs` を付ける。
   - 例: GitHub Actionsゲート、ローカルゲート、promptfoo評価、Graphify検査、トレース検査をそれぞれ `doc:*` ノードとして文書化する。
4. `codd validate` の `missing_depended_by` warning は、参照先文書に reciprocal `depended_by` を追加して解消する。
   - 新しい `doc:*` が `design:taskflow-service-design` に `depends_on` するなら、設計文書側にも `depended_by` を追加する。
5. GitHub Actions YAML を Python/PyYAML で構文確認する場合、YAML 1.1 では `on` が boolean として読まれるため、`"on":` と引用する。
   - 確認コマンド例: `python - <<'PY' ... yaml.safe_load(...) ... PY`
   - 期待: top_keys に `'on'` が出ること（`True` になっていたら修正）。
6. 導入後の最小検証は次を一括で実行する。

```bash
. .venv/bin/activate
python -m pytest -v sample-app/tests
codd validate
codd scan
codd measure
python scripts/check_traceability_coverage.py
graphify update sample-app
python scripts/check_graphify_coverage.py
```

7. サブモジュール型ラボでは、導入後に必ず以下を行う。
   - サブモジュール側で commit / push / `rev-parse HEAD` と `rev-parse origin/main` 一致確認。
   - 親側で `git diff --submodule=log -- experiences/aidlc-codd-graphify-lab` を確認。
   - 親側サブモジュールポインタを commit / push。
   - 親側 `git submodule status --recursive` で新しいコミットを指していることを確認。
