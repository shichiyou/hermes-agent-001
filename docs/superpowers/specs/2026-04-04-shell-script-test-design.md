# シェルスクリプトテスト設計

## 目的

Dev Container Template内のシェルスクリプト（`.devcontainer/*.sh`）に対してBATSを使った自動テストを導入し、テンプレートとしての品質と保守性を向上させる。

## 対象ファイル

| スクリプト | パス | 主な機能 |
|-----------|------|---------|
| update-tools.sh | `.devcontainer/scripts/update-tools.sh` | ツール更新（15種） |
| on-create.sh | `.devcontainer/on-create.sh` | Home初期化 |
| post-create.sh | `.devcontainer/post-create.sh` | 依存同期・CLI導入 |
| post-start.sh | `.devcontainer/post-start.sh` | Ollama起動 |

## テスト構成

```
tests/
├── update-tools.bats   # update-tools.sh のテスト
├── post-start.bats     # post-start.sh のテスト
├── on-create.bats      # on-create.sh のテスト
├── fixtures/           # テスト用モック・スタブ
│   ├── mock-curl.sh
│   └── mock-npm.sh
└── bats_helper.sh      # 共通ヘルパー（オプション）
```

## テストレベル

### ユニットテスト

`update-tools.sh`の関数を直接テストする。

#### テスト対象関数

| 関数 | テスト内容 |
|------|----------|
| `normalize_version()` | バージョン文字列から数値抽出 |
| `versions_match()` | バージョン比較ロジック |
| `skip_if_same_version()` | 同一バージョン時のスキップ判定 |
| `ollama_architecture()` | アーキテクチャ判定 |
| `find_workspace_root()` | ワークスペースルート探索 |
| `apt_installed_version()` | aptバージョン取得 |
| `github_latest_release_tag()` | GitHub API呼び出し |

### インテグレーションテスト

スクリプト全体を外部依存をモックして実行する。

#### post-start.sh

```bats
@test "post-start: creates log directory" {
    export HOME="$BATS_TMPDIR/home"
    mkdir -p "$HOME/.local/state"

    run ./tests/fixtures/mock-ollama.sh &
    # post-start.shを実行し、ログディレクトリが作成されることを検証
}
```

## モック戦略

### curl

外部HTTP呼び出しをローカルファイルで代用する。

```bash
# tests/fixtures/mock-curl.sh
#!/bin/bash
if [[ "$1" == *"github.com"* ]]; then
    echo "v1.0.0"
else
    curl "$@"
fi
```

### npm / uv

`--dry-run` モードを活用し、実際には実行しない。

### Ollama

`command -v ollama` の結果で分岐させる。

## CIへの組み込み

`.github/workflows/ci.yml` に以下のステップを追加する。

```yaml
- name: Install BATS
  run: npm install -g bats

- name: Run shell script tests
  run: bats tests/
```

## 実装手順

1. `tests/` ディレクトリ作成
2. `package.json` の `devDependencies` に `bats` を追加
3. `update-tools.bats` から実装（関数が独立しているため）
4. `post-start.bats` を実装
5. `on-create.bats` と `post-create.bats` を実装
6. CIにテストステップを追加
7. CONTRIBUTING.md にテスト実行方法を記載

## 期待成果

- シェルスクリプト修正時のデグレ防止
- 新機能追加時の振る舞い検証
- テンプレートとしての信頼性向上
