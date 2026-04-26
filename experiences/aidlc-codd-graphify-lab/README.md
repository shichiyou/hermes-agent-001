# AI-DLC × CoDD × Graphify 体験ラボ

このディレクトリは、以下の3リポジトリを「概念だけ模倣する」のではなく、公式の導入経路と実CLI出力に基づいて体験するためのラボです。

- AI-DLC: https://github.com/awslabs/aidlc-workflows
- CoDD: https://github.com/yohey-w/codd-dev
- Graphify: https://github.com/safishamsi/graphify

## 結論

実施済みです。

- CoDD は `pip install codd-dev` で導入し、`codd init` / `codd validate` / `codd scan` / `codd extract` を実行しました。
- AI-DLC は `awslabs/aidlc-workflows` の Release ZIP `ai-dlc-rules-v0.1.8.zip` から導入しました。fork・submodule化はしていません。
- AI-DLC のエージェント形式は、Hermes Agent ではなく、ユーザー指定どおり以下の3種類を用意しました。
  - Codex: `AGENTS.md`
  - Claude Code: `CLAUDE.md`
  - GitHub Copilot: `.github/copilot-instructions.md`
- Graphify は `pip install graphifyy` で導入し、CLI名 `graphify` で `sample-app/graphify-out/graph.json`、`sample-app/graphify-out/GRAPH_REPORT.md`、`sample-app/graphify-out/graph.html` を生成しました。
- サンプルアプリは TDD で作成し、pytest で `2 passed` を確認しました。

## 重要な未完了・制約

- `codd plan --init` は、外部AI使用量制限により失敗しました。失敗は `logs/phase5-codd-plan-init.log` に残しています。
- Graphify の出力先は、実CLI仕様上、対象ディレクトリ配下の `sample-app/graphify-out/` でした。ラボ直下の `graphify-out/` には手作業で移動していません。
- Graphify の `claude install` はヘルプ上 `PreToolUse hook` を作成する可能性があるため、AGENTS.md のセキュリティ規則に従い実行・コミットしていません。
- GitHub Copilot のCLI拡張はこの環境では確認できませんでした。ただし、公式のVS Code Copilot形式である `.github/copilot-instructions.md` は作成済みです。

## Phase 0: 事前確認

親リポジトリは `main...origin/main` で、旧 `aidlc-codd-demo` は削除済み、新ラボは未存在の状態から開始しました。

Raw Output は `logs/` 配下に保存しています。

## Phase 1-2: ラボディレクトリとPython仮想環境

作成対象:

- `sample-app/`
- `logs/`
- `.venv/`（Git管理対象外）

Python仮想環境を作成し、以後のCLIは `.venv` 内で実行しました。

## Phase 3-5: CoDD 導入・初期化・検証

公式パッケージ経路:

```bash
python -m pip install codd-dev
```

確認済みの事実:

```text
codd-dev 1.10.0
```

生成・確認した主なファイル:

- `codd/codd.yaml`
- `docs/requirements/requirements.md`
- `codd/extracted/system-context.md`
- `codd/extracted/architecture-overview.md`
- `codd/extracted/modules/taskflow.md`

`sample-app/src/` をCoDDのスキャン対象にするため、`codd/codd.yaml` は以下に修正しました。

```yaml
scan:
  source_dirs:
    - "sample-app/src/"
  test_dirs:
    - "sample-app/tests/"
  doc_dirs:
    - "docs/"
```

検証結果:

```text
codd scan:
  Source: 5 python files in sample-app/src
  Graph: 7 nodes, 4 edges
  Evidence: 4 total (0 human, 4 auto)

codd extract:
  Extracted: 1 modules from 5 files (97 lines)
```

参照ログ:

- `logs/phase3-pip-install-codd-dev.log`
- `logs/phase3-codd-version.log`
- `logs/phase3-codd-help.log`
- `logs/phase4-codd-init.log`
- `logs/phase5-codd-plan-init.log`
- `logs/phase6-codd-scan-after-config.log`
- `logs/phase6-codd-measure-after-config.log`
- `logs/phase6-codd-extract-after-config.log`

## Phase 6: TDDによるサンプルアプリ作成

サンプルアプリは `TaskFlow Mini` です。

主要ファイル:

- `sample-app/src/taskflow/models.py`
- `sample-app/src/taskflow/repository.py`
- `sample-app/src/taskflow/service.py`
- `sample-app/src/taskflow/cli.py`
- `sample-app/tests/test_taskflow.py`

TDDの物理証拠:

```text
RED:
ModuleNotFoundError: No module named 'taskflow'
red-pytest-exit-code=2

GREEN:
2 passed in 0.00s
pytest-after-codd-config-exit-code=0
```

参照ログ:

- `logs/phase6-red-pytest.log`
- `logs/phase6-green-pytest.log`
- `logs/phase6-green-pytest-after-codd-config.log`

## Phase 7-8: AI-DLC Release ZIP 導入

公式READMEで確認した導入方針:

- 最新リリースZIP `ai-dlc-rules-v<release-number>.zip` をプロジェクト外にダウンロード
- 展開された `aidlc-rules/` を使う
- エージェント別に以下へ配置

今回の実行結果:

```text
tag_name= v0.1.8
asset= ai-dlc-rules-v0.1.8.zip
zip size= 98130
sha256= 46898f1921381eda440a5edcfd037a04d7ce52b5bc3a67f4dd3d2067c1b7f153
```

エージェント別ファイル:

| エージェント | 公式形式 | このラボのファイル | 検証結果 |
|---|---|---|---|
| Codex | `AGENTS.md` | `AGENTS.md` | 539行 |
| Claude Code | `CLAUDE.md` | `CLAUDE.md` | 539行 |
| GitHub Copilot | `.github/copilot-instructions.md` | `.github/copilot-instructions.md` | 539行 |

詳細ルール:

- `.aidlc-rule-details/` に29ファイル

参照ログ:

- `logs/phase7-aidlc-readme-headings.log`
- `logs/phase7-aidlc-latest-release.log`
- `logs/phase7-aidlc-installed-heads.log`

## Phase 9-11: Graphify 導入・生成・照会

公式READMEで確認した導入方針:

```bash
pip install graphifyy && graphify install
```

今回の実行では、hookを作成し得る agent install 系は避け、CLI生成系を実行しました。

確認済みの事実:

```text
Name: graphifyy
Version: 0.4.23
CLI: graphify
```

生成コマンド:

```bash
graphify update sample-app
```

Raw Output:

```text
Re-extracting code files in sample-app (no LLM needed)...
[graphify watch] Rebuilt: 23 nodes, 45 edges, 6 communities
[graphify watch] graph.json, graph.html and GRAPH_REPORT.md updated in .../sample-app/graphify-out
Code graph updated. For doc/paper/image changes run /graphify --update in your AI assistant.
graphify-update-exit-code=0
```

生成ファイル:

- `sample-app/graphify-out/graph.json`
- `sample-app/graphify-out/GRAPH_REPORT.md`
- `sample-app/graphify-out/graph.html`
- `sample-app/graphify-out/cache/*.json`

Graphify照会:

```text
graphify explain "TaskService" -> graphify-explain-exit-code=0
graphify query "How does a task move from todo to done?" -> graphify-query-exit-code=0
graphify benchmark graphify-out/graph.json -> graphify-benchmark-exit-code=0
```

参照ログ:

- `logs/phase9-graphify-README.md`
- `logs/phase9-pip-install-graphifyy.log`
- `logs/phase9-pip-show-graphifyy.log`
- `logs/phase9-graphify-help.log`
- `logs/phase10-graphify-update-sample-app.log`
- `logs/phase10-actual-graphify-output-files.log`
- `logs/phase10-actual-graphify-json-summary.log`
- `logs/phase10-actual-graphify-report-head.log`
- `logs/phase11-graphify-explain-taskservice.log`
- `logs/phase11-graphify-query-status-transition.log`
- `logs/phase11-graphify-benchmark.log`

## 再現手順

```bash
cd experiences/aidlc-codd-graphify-lab
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install codd-dev pytest graphifyy

# CoDD
codd validate
codd scan
codd extract

# サンプルアプリテスト
cd sample-app
python -m pytest -v

# Graphify
cd ..
graphify update sample-app
cd sample-app
graphify explain "TaskService"
graphify query "How does a task move from todo to done?"
graphify benchmark graphify-out/graph.json
```

## 旧 aidlc-codd-demo との違い

| 項目 | 旧 `aidlc-codd-demo` | このラボ |
|---|---|---|
| AI-DLC | `awslabs/aidlc-workflows` をサブモジュール的に扱い、親 `.gitmodules` と実体URLがねじれていた | 公式Release ZIPから取得。fork/submodule化なし |
| エージェント形式 | Hermes向けでも公式3エージェント向けでもない手書き説明が中心 | Codex/Claude Code/GitHub Copilot の公式ファイルを配置 |
| CoDD | `codd.yaml` や `codd/` 成果物なし | `codd init` / `scan` / `extract` の成果物あり |
| Graphify | `graphify-out/` なし | 実CLIで `sample-app/graphify-out/` を生成 |
| サンプルアプリ | 手書きデモ | pytestによるRED/GREEN確認済み |
| 証拠 | 実行ログ不足 | `logs/` にRaw Outputを保存 |
