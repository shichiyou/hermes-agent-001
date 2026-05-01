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

## AI-DLC 用語階層（方法論定義論文 vs OSS実装の差異）

方法論定義論文（`https://prod.d13rzhkk8cj2z0.amplifyapp.com/`）と `aidlc-workflows` OSS実装の間で用語の粒度・存在に差異がある。

**方法論上の階層**: Intent → Unit → Bolt

| 用語 | 方法論定義論文 | aidlc-workflows実装 |
|---|---|---|
| **Intent** | 事業的意図/要求。全ての出発点 | 明示的なステージ名としては存在しない。Requirements Analysisが相当 |
| **Unit** | Intentから導出される凝集性のある機能ブロック（DDDサブドメイン/Epic相当）。疎結合で独立デプロイ可能 | Unit of Work（UOW）として同じ概念。Application Designステージの前提が必要。マイクロサービスなら各Unitが独立デプロイ可能サービス、モノリスならアプリ全体が1Unit |
| **Bolt** | AI-DLCの最小反復単位（Sprint相当、ただし時間〜日単位）。1Unitは1以上のBoltで実行（並列/順次）。AIが計画、開発者/POが検証 | **明示的なステージ/成果物として存在しない**。Construction Phase内のCode Generation/Build & Testサイクルが暗黙的にBolt相当の働きをする |

重要な観察:
- kiakiraki氏の批判「10-26人間検証ポイント/Bolt」は、1Bolt（時間〜日単位の反復）内で10〜26回の人間承認が発生することを指す
- PR #156 で「Units Planning」は独立ステージではなくUnits Generation内のsub-stepに整理されたことが確認済み
- 用語の正確な定義は `terminology.md`（`https://raw.githubusercontent.com/awslabs/aidlc-workflows/main/aidlc-rules/aws-aidlc-rule-details/common/terminology.md`）を参照

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
docs/design/DESIGN.md           ← design.md ベースの視覚設計トークン定義
```

存在しない場合は、「存在しない」と明示し、勝手に存在する前提で作業を進めないこと。

特に確認すべき接続性: AIエージェント指示ファイル（AGENTS.md, CLAUDE.md, .github/copilot-instructions.md）に CoDD/Graphify の**役割定義**が含まれているかを検証すること。コマンド実行指示のみで役割定義がない場合、エージェントは出力を機械的報告以上に活用できない。詳細は `references/agent-instructions-coverage-audit.md` を参照。

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
11. AI-DLC の `audit.md` 追記や日本語Markdownの複数行生成では、`terminal` / `execute_code` 経由の shell heredoc・`printf`・入れ子クォートを使わない。新規作成は `write_file`、既存ファイルへの追記は `read_file` で現内容を確認してから `patch` または安全なファイルAPIを使い、必ず `read_file` で作成・追記結果を検証する。

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

### 2.5 既存リポジトリの構造分析・棚卸しを行う場合

ユーザーが「AI-DLCを使って既存リポジトリの構造を分析して」「ラボの構造を確認して」「現状を棚卸しして」のように依頼した場合は、実装変更よりも Brownfield Reverse Engineering / Workspace Detection として扱う。

最低確認コマンド:

```bash
cd /対象リポジトリ
pwd
git status --short --branch
git log --oneline -3
for d in .aidlc/aidlc-rules/aws-aidlc-rule-details .aidlc-rule-details .kiro/aws-aidlc-rule-details .amazonq/aws-aidlc-rule-details; do [ -d "$d" ] && echo "RULE_DIR=$d"; done
git ls-files | sed -n '1,200p'
git ls-files 'docs/**' 'README.md' 'AGENTS.md' 'CLAUDE.md' '.github/**' | sed -n '1,200p'
git ls-files 'sample-app/**' 'scripts/**' 'codd/**' '.codd_version' | sed -n '1,200p'
```

構造分析で見る観点:

| 観点 | 確認内容 |
|---|---|
| AI-DLC配置 | `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.aidlc-rule-details/` の有無 |
| CoDD配置 | `codd/codd.yaml`, `docs/**/*.md` frontmatter, `codd validate/scan/measure` |
| Graphify配置 | `sample-app/graphify-out/graph.json`, `GRAPH_REPORT.md`, coverage check |
| アプリ構造 | `sample-app/src`, `sample-app/tests`, `pyproject.toml` 等 |
| ドリフト制御 | `.github/workflows`, `.pre-commit-config.yaml`, `promptfoo.yaml`, `scripts/check_*.py` |
| Git保全 | サブモジュールの場合は親側 `git status` と `git submodule status --recursive` |

AI-DLC標準の監査ログ要件で `aidlc-docs/audit.md` を作る場合は、対象リポジトリが既に `docs/` をCoDD正本として使っていないか確認する。`aidlc-docs/` が未存在のリポジトリで新規作成すると、Git未追跡差分と親サブモジュールdirty状態を発生させる。

ただし、ユーザーが明示的に「AI-DLCを使用して構造分析して」と依頼した場合、`audit.md` 断片だけを作って止めてはいけない。デフォルトの完了条件は、AI-DLCとして有効な最小成果物を揃えること。

最小成果物:

```text
aidlc-docs/aidlc-state.md
aidlc-docs/audit.md
aidlc-docs/inception/reverse-engineering/business-overview.md
aidlc-docs/inception/reverse-engineering/architecture.md
aidlc-docs/inception/reverse-engineering/code-structure.md
aidlc-docs/inception/reverse-engineering/api-documentation.md
aidlc-docs/inception/reverse-engineering/component-inventory.md
aidlc-docs/inception/reverse-engineering/technology-stack.md
aidlc-docs/inception/reverse-engineering/dependencies.md
aidlc-docs/inception/reverse-engineering/code-quality-assessment.md
aidlc-docs/inception/reverse-engineering/reverse-engineering-timestamp.md
```

完了前に、上記ファイルが存在し空でないことを物理確認し、`aidlc-state.md` に Workspace Detection / Reverse Engineering の完了状態を記録する。既存の `docs/` がCoDD正本である場合は、`docs/` と `aidlc-docs/` の役割分離（例: `docs/` = CoDD正本、`aidlc-docs/` = AI-DLC実行成果物）を明示する。

最終報告では必ずこの副作用を隠さず報告し、Git未コミット状態を残すなら、未追跡ファイル一覧と「コミットは未実行」の事実を明示する。

構造分析の最小検証:

```bash
. .venv/bin/activate 2>/dev/null || true
python -m pytest -v sample-app/tests
codd validate
codd scan
codd measure
python scripts/check_traceability_coverage.py
python scripts/check_graphify_coverage.py
git status --short --branch
git diff --name-status
git diff --cached --name-status
git ls-files --others --exclude-standard
```

報告では、`codd measure` の全体 coverage と、専用スクリプトによる主要対象 coverage を分けて説明する。例: `codd measure` が `5/9` でも、`scripts/check_traceability_coverage.py` が `sample-app/src/**/*.py 5/5` を示す場合は、前者を改善指標、後者を初期ハードゲートとして扱う。

### 2.6 AI-DLC成果物を監査可能な正規成果物へEvidence Hardeningする場合

ユーザーが「監査可能な正規成果物にして」「正規AI-DLC成果物として成立させて」「成果物の製造プロセスと内容を監査可能にして」のように依頼した場合は、単なるファイル配置確認ではなく Evidence Hardening として扱う。

完了条件は次の4点をすべて満たすこと。

1. Raw Outputを先に固定する。
2. 主張とRaw Outputの対応をEvidence Matrixにする。
3. 各成果物本文にEvidence TraceとRaw Output抜粋を埋め込む。
4. 最終検証ログとGit状態を保存し、未追跡・未コミット状態を隠さず報告する。

推奨成果物:

```text
aidlc-docs/evidence/phase0-initial-state.log
aidlc-docs/evidence/phase1-aidlc-rule-resolution.log
aidlc-docs/evidence/phase2-repository-inventory.log
aidlc-docs/evidence/phase3-codd-current-state.log
aidlc-docs/evidence/phase4-application-and-tests.log
aidlc-docs/evidence/phase5-graphify-current-state.log
aidlc-docs/evidence/phase10-final-verification.log
aidlc-docs/inception/reverse-engineering/evidence-matrix.md
```

Evidence Matrixには少なくとも次を含める。

| 列 | 内容 |
|---|---|
| Claim ID | C-001などの安定ID |
| Claim | 成果物で主張する内容 |
| Raw Output Evidence | 根拠となる出力の要約ではなく対応箇所 |
| Evidence File | `aidlc-docs/evidence/*.log` のパス |
| Reflected In | 反映先成果物 |
| Confidence | 高/中/低など |
| Limitations | その根拠で言えないこと |

各Reverse Engineering成果物には `## Evidence Trace` と `## Raw Output Excerpts` を入れる。`evidence-matrix.md` 自体は索引なので、この2見出しを持たないことがあってもよいが、その理由を最終検証ログで明示する。

最終検証では以下を個別に実行し、`phase10-final-verification.log` に保存する。

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
pwd
git status --short --branch
git diff --name-status
git diff --cached --name-status
git ls-files --others --exclude-standard
python -m pytest -v sample-app/tests
codd validate
codd scan
codd measure
python scripts/check_traceability_coverage.py
python scripts/check_graphify_coverage.py
git -C /workspaces/hermes-agent-001 status --short --branch
git -C /workspaces/hermes-agent-001 submodule status --recursive
```

注意: これらを `execute_code` で長大な一括収集にするとタイムアウト時に最終ログが残らないことがある。長い最終検証は直接 `terminal` で分割実行し、結果を `write_file` で保存し、最後に `read_file` または `test -s` / `wc -c` で存在とサイズを検証する。

`aidlc-state.md` には evidence-hardened 状態、Evidence Capture Status、Verification Status、Known Limitations を記録する。特に次は隠さない。

- `aidlc-docs/` が未追跡かどうか。
- コミット・push未実施かどうか。
- 親リポジトリからサブモジュールがdirtyに見えるかどうか。
- `codd measure` の全体 coverage と専用検査の coverage の違い。
- Evidence Hardening が後追い補強の場合は、その事実。

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

### 6. 小さな変更要求で運用する（1循環検証シナリオ）

初回運用では、小さな変更要求を1件流して、運用定義が機能するか確認する。これを**1循環検証シナリオ（段階0）**と呼ぶ。

#### 6.1 題材選定

既存カバレッジ表の `Not Covered` 要件または、promptfoo評価ケースの入力と重なる機能を選ぶ。選定基準:

1. カバレッジ表で `Not Covered` として明示されている機能
2. 業務判断が含まれる（AIが勝手に決められない判断点がある）
3. 変更対象が既存ファイルに限定され、新規ファイルが少ない
4. V字モデルの全レイヤー（事業要求→受入テスト）を通過できる

#### 6.2 観察対象

| 観察対象 | 見るべき挙動 |
|---|---|
| 要求定義 | 業務判断（物理/論理削除等）を人間に質問するか |
| 受入条件 | 受入条件が検証可能か |
| 設計 | 既存コンポーネントへの影響を整理するか |
| CoDD | `req:*`, `design:*`, `source_files`, `test_files` を作るか |
| 実装 | テスト駆動で進めるか |
| Graphify | 影響範囲と構造変化を見るか |
| ゲート | pytest / codd validate / codd scan / カバレッジ確認を行うか |
| 逸脱 | 未決事項があれば停止・質問するか |

#### 6.3 承認品質の評価（Approval Hell 実測）

1循環を通じて、各ステージの「Wait for Explicit Approval」が実質的判断か rubber stamp かを記録する。これが段階0の核心観察。

| 評価 | 定義 |
|---|---|
| **実質的** | 承認なしに進めると品質リスクまたは要件逸脱の危険がある |
| **rubber stamp** | 承認内容が機械的判定や前段の承認で代替可能 |

実測結果をもとに、Wikiの approval hell 対策ページ（段階1〜3）の優先度を決定する。

#### 6.4 定量的成功基準

1循環の完了判定には10項目の定量基準を設ける:

| ID | 成功基準 | 測定方法 | 合格閾値 |
|---|---|---|---|
| S1 | aidlc-state.md に全ステージの判定が記録される | aidlc-state.md の Stage Progress | 全ステージに判定が記録 |
| S2 | audit.md に全承認のタイムスタンプが記録される | audit.md を grep して計数 | 全承認回数分の記録 |
| S3 | 新規要件が CoDD で追跡される | codd scan 出力 | 新規 node_id が存在 |
| S4 | pytest が PASS する | python -m pytest -v | 既存+新規テストが全て PASS |
| S5 | codd validate が OK | codd validate | エラー0件 |
| S6 | 全体 coverage が低下しない | codd measure | 追加前以下に低下しない |
| S7 | Graphify に新エッジが反映される | graphify update 後の graph.json | 新規機能関連のノード/エッジが増加 |
| S8 | カバレッジ表の新規要件が Covered になる | トレース表目視確認 | 新規要件行の全列が埋まる |
| S9 | aidlc-docs/ が Git コミットされる | git log --oneline -5 | 1循環完了コミットが存在 |
| S10 | 重複ファイルが生成されない | find で確認 | *_modified* や *_new* のファイルが0件 |

#### 6.5 進捗管理文書の作成

1循環検証シナリオは、CoDD frontmatter付きのMarkdown文書として作成し、既存文書群に相互参照を追加する:

1. **シナリオ文書**: `docs/process/one-cycle-verification-scenario.md`
   - CoDD frontmatter (`node_id`, `type: design`, `status: draft`, `depends_on`, `confidence`)
   - セクション構成: 目的、題材根拠、開発案件分類、ステージ別評価ポイント、承認回数/評価マトリクス、成功基準(S1-S10)、進捗管理表(チェックボックス付き)、前提確認
2. **相互参照の追加**: シナリオ文書の `depends_on` 参照先に `depended_by` を追加
3. **Wiki概要ページ**: `wiki/concepts/aidlc-one-cycle-verification-scenario.md`
4. **検証**: `codd validate` → `codd scan` → `codd measure` → `pytest` → `check_traceability_coverage` → `graphify update` の全ゲートが通過することを物理的に確認

CoDD frontmatterの `depended_by` 参照先として、`req:task-delete` のような**まだ存在しないnode_id**は書かない。その要件が追加された時点で参照を追加する。

シナリオ文書の `status` は `draft` とする。1循環が完走して初めて実績に基づく値付けが可能になる。

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

## 方法論分析時の誠実性ルール（Methodology Analysis Integrity）

AI-DLC や他の外部手法論を調査・分析し、自プロジェクトへの適用を検討する場合、以下を厳格に区別する。混同は「方法論的幻覚」と呼び、AGENTS.md の誠実性原則に照らして重大な違反とする。

| 区分 | 定義 | 表現の例 |
|---|---|---|
| **物理的事実** | 現環境に存在するファイル・コマンド出力・Git状態 | 「`aidlc-state.md` は存在しない」「CIでpytestがPASSしている」 |
| **外部手法論の仕様** | 公式ドキュメント・論文・ルールファイルに書かれている内容 | 「`units-generation.md` は全ステージで Wait for Explicit Approval を要求している」 |
| **コミュニティの知見** | 実践レポート・批判記事・RFCで提案されている内容 | 「kiakiraki氏は10-26承認/Boltを過剰と指摘している」 |
| **導出仮説** | 上記を組み合わせて「こうすべき」と導出したが、実装・検証されていない内容 | 「Phase境界集約で承認を2回に圧縮できる」 |

**絶対ルール**: 
1. 導出仮説を「このラボでの実践的アプローチ」「適用できている」と事実のように提示してはならない。
2. 導出仮説を提示する場合は、「仮説です。実装されていません。根拠は〇〇の引用のみです」と明記する。
3. 「方法論分析」→「適用提案」→「実装」→「検証」の各段階を飛ばしてはならない。特に「実装」段落階を飛ばして「検証」語ると、Ghost Completion と同一の欺瞞になる。
4. CI決定的ゲートが稼働していることと、AI-DLCステージ承認フローが変更されていることは別問題である。前者は事実でも後者の変更を意味しない。

このルールは、AI-DLC運用スキル自体が「方法論的正しさ」を装って未実装の改善を事実化する危険性に対する防御である。

## AGENTS.md/CLAUDE.md と CI/CoDD/Graphify の接続欠落パターン

### ピットフォール1: 「CI側に手足があるが、AI-DLCルール側に脳がない」

`AGENTS.md` / `CLAUDE.md` は純粋な `aidlc-workflows` のルール展開である。`.github/workflows/drift-control-gates.yml` や `.pre-commit-config.yaml` に pytest/CoDD/Graphify の実行ゲートが定義されていても、**AGENTS.md にこれらを実行する指示がない場合、AIエージェントはそれらを呼び出さない。**

物理的確認方法:

```bash
grep -in 'codd\|graphif\|pytest\|pre-commit\|drift.*control\|traceability.*check' AGENTS.md
```

この結果が「traceability」1語のみ等、ほぼ空であれば、CI/CoDD/Graphify と AI-DLCルールが切断されている。

### ピットフォール2: 「コマンドはあるが、役割と判断基準がない」

実行コマンド（例: `graphify update sample-app`）が AGENTS.md に書いてあっても、**その出力が何を意味し、どう判断に使うべきか（使わざるべきか）が書いていない場合**、AIエージェントは実行結果を機械的に報告するだけで、構造理解や影響分析に活用できない。

**2026-05-01 修正済み**: aidlc-codd-graphify-lab の3ファイル（AGENTS.md, CLAUDE.md, .github/copilot-instructions.md）に `## ツールの役割と使用方法（ラボ固有）` セクションを追加し、以下を明記:
- 役割分担表（AI-DLC / CoDD / pytest / Graphify の合否判定での使い方）
- CoDD frontmatter の必須フィールドとコマンド判定基準
- Graphify のコマンド・生成物・CI合否判定基準（INFERREDエッジは判定根拠にしない）
- Three-Way Coherence Closure の標準実行順序
- Build and Test ゲートで Graphify を "structural verification (supplementary)" に位置づけ直し

**再発検出方法**: 新しいプロジェクトやAI-DLC更新後に、以下のコマンドで役割定義の有無を確認:
```bash
grep -c '役割分担\|合否判定\|INFERRED\|structural verification' AGENTS.md CLAUDE.md .github/copilot-instructions.md
```
結果が0件なら、ツールの役割定義セクションが欠落している。

**AI-DLC更新時の注意**: AI-DLC公式配布物（AGENTS.md の `<!-- LAB-SPECIFIC ADDITIONS BELOW -->` 境界より上）を差し替える際、LAB-SPECIFIC区域（ツール定義・Assumption Surfacing等）は維持する。`.github/copilot-instructions.md` はAI-DLC公式配布物ではないため、丸ごと差し替えのリスクがある場合はツール定義セクションの再挿入が必要。

詳細は `references/agent-instructions-coverage-audit.md` を参照。

### 具体的改善 — 5箇所（実装済み、2026-05-01 更新）

以下の変更は `experiences/aidlc-codd-graphify-lab` で実装済み。AGENTS.md, CLAUDE.md, .github/copilot-instructions.md の3ファイルに適用。

**変更1**: Build and Test ステージに CoDD/Graphify 実行ゲート追加（初回実装: 2025-04-27）

AGENTS.md 等に実装。Build and Test の手順3として決定的ゲートを追加。（初回実装時のコマンドのみ記載版）

**変更2**（2026-05-01 更新）: Build and Test ゲートで Graphify を決定的ゲートから構造確認に再分類

`graphify update sample-app` を "EXECUTE deterministic gates" から分離し、新ステップ "4. EXECUTE structural verification (supplementary — NOT a pass/fail gate)" に移動:
- 決定的ゲート（FAILで停止）: pytest, codd, check_traceability_coverage
- 構造確認（FAILは報告するが停止しない）: graphify update, check_graphify_coverage
- INFERREDエッジは合否判定の根拠にしない旨を明記
- 理由: v-model-development-process.md が「Graphifyは合否判定に使わない」と規定しており、旧配置はこれと矛盾していた

**変更3**（2026-05-01 更新）: Code Generation 検証ステップの codd FAIL ハンドリング追加

```markdown
- Run `codd validate && codd scan`
  - IF FAIL: report in audit.md; fix frontmatter or source references before continuing
  - IF PASS: record coherence state in audit.md
```

**変更4**（2026-05-01 新規）: copilot-instructions.md の欠落補完

GitHub Copilot向け指示ファイルに以下が存在していなかったため補完:
- Code Generation post-generation verification ステップ全体（+8行）
- Build and Test deterministic gates + structural verification ステップ全体（+19行）
- ツール役割定義セクション（+90行）

**変更5**（2026-05-01 新規）: 3ファイル共通のツール役割定義セクション追加

LAB-SPECIFIC区域に `## ツールの役割と使用方法（ラボ固有）` を追加。内容:
- 役割分担表（AI-DLC / CoDD / pytest / Graphify の合否判定での使い方）
- CoDD frontmatter の必須フィールド7項目
- CoDD コマンドと判定基準（4コマンド）
- Graphify コマンドと使用目的（4コマンド）
- Graphify 生成物と扱い（3生成物）
- Graphify の判定における扱い（CI失敗条件にするかしないかの3チェック）
- Three-Way Coherence Closure の標準実行順序

### 変更しないこと（設計判断）

| 項目 | 理由 |
|---|---|
| `.aidlc-rule-details/` 配下の各ステージルール詳細ファイル本体 | アップストリーム正本。ローカル改変すると再追従不可 |
| Inception系ステージの人間承認 | 仕様値の決定は人間の裁量領域。自動化対象ではない |
| `.aidlc-rule-details/construction/build-and-test.md` | アップストリーム正本。パッチは AGENTS.md 側に限る |

### 承認回数への効果

変更1/2 は承認回数自体を劇的に減らさない。しかし「何を承認しているか」が「指示文の有無」から「実行結果のPASS/FAIL」に変わることが本質的な改善である。

### 再適用手順

他のラボやプロジェクトに同じ改善を適用する場合:

1. 3ファイル（AGENTS.md, CLAUDE.md, .github/copilot-instructions.md）の LAB-SPECIFIC ADDITIONS 境界より下に、ツールの役割定義セクションを追加する。セクション内容は `references/agent-instructions-coverage-audit.md` の "Change 1" を参照。
2. Build and Test セクションで、`graphify update` を "deterministic gates" から "structural verification" に分離し、supplementary（合否判定ではない）として位置づける。
3. Code Generation セクションの `codd validate && codd scan` に FAIL時ハンドリングを追加する。
4. `.github/copilot-instructions.md` に Build and Test ゲートと Code Generation verification ステップが存在するか確認し、欠落していれば AGENTS.md と同等の内容を補完する。
5. `diff AGENTS.md CLAUDE.md` で両者が同一であることを検証する。
6. `grep -c 'graphify\|Graphify' AGENTS.md CLAUDE.md .github/copilot-instructions.md` で3ファイルの言及数が等しいことを確認する。
7. `grep -c 'INFERRED' AGENTS.md CLAUDE.md .github/copilot-instructions.md` でINFERRED警告が3ファイル全てに存在することを確認する。

## Assumption Surfacing の組み込み状態

aidlc-codd-graphify-labでは、Assumption Surfacing（前提の顕在化）が以下に組み込まれている:

| 組み込み先 | 形式 | 更新時の注意 |
|---|---|---|
| `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` | 末尾のLAB-SPECIFIC ADDITIONS境界より下 | AI-DLC更新時は境界より上のみ差し替え、下は維持 |
| `docs/process/ai-agent-requirements-prompt-guide.md` | セクション3（開発案件分類ゲートの前） | AI-DLCは管理対象外なので通常の文書更新で対応 |
| `docs/process/ai-agent-v-model-prompt-guide.md` | セクション3（最小開始プロンプトの前） | 同上 |

**ピットフォール**: `.aidlc-rule-details/` 内にAssumption Surfacingを追記してはならない。AI-DLC配布物のバージョン更新で上書きされる。独自追記はAGENTS.md本体の境界セクション、または `docs/process/` に配置する。

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
