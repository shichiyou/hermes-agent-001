# シェルスクリプトテスト 実装計画

## 概要

Dev Container Template の `.devcontainer/*.sh` に対して BATS を使った自動テストを導入する。

## タスク一覧

### Phase 1: 基盤構築

- [ ] `tests/` ディレクトリを作成する
- [ ] `package.json` の `devDependencies` に `bats` を追加する
- [ ] `tests/bats_helper.sh` を作成する（共通ヘルパー）
- [ ] `tests/fixtures/` にモックスクリプトを配置する

### Phase 2: update-tools.sh のテスト実装

- [ ] `tests/update-tools.bats` を作成する
- [ ] `normalize_version()` のテストを実装する
- [ ] `versions_match()` のテストを実装する
- [ ] `skip_if_same_version()` のテストを実装する
- [ ] `ollama_architecture()` のテストを実装する
- [ ] `find_workspace_root()` のテストを実装する

### Phase 3: post-start.sh のテスト実装

- [ ] `tests/post-start.bats` を作成する
- [ ] ログディレクトリ作成のテストを実装する
- [ ] Ollama 既起動時のテストを実装する
- [ ] Ollama 起動時のテストを実装する

### Phase 4: on-create.sh / post-create.sh のテスト実装

- [ ] `tests/on-create.bats` を作成する
- [ ] Home 初期化フローのテストを実装する
- [ ] `tests/post-create.bats` を作成する
- [ ] 依存同期のテストを実装する

### Phase 5: CI 統合

- [ ] `.github/workflows/ci.yml` に BATS インストールステップを追加する
- [ ] `bats tests/` 実行ステップを追加する

### Phase 6: ドキュメント

- [ ] CONTRIBUTING.md にテスト実行方法を記載する

---

## 詳細

### Phase 1: 基盤構築

#### 1.1 tests/ ディレクトリ作成

```bash
mkdir -p tests/fixtures
touch tests/fixtures/.gitkeep
```

#### 1.2 bats のインストール

`package.json` の `devDependencies` に追加:

```json
"bats": "^1.11.0"
```

または npm script から実行する場合:

```json
"test:shells": "bats tests/"
```

#### 1.3 bats_helper.sh

```bash
#!/bin/bash
# 共通ヘルパー関数

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export HOME="$TEST_TMPDIR/home"
    mkdir -p "$HOME/.local/state"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}
```

### Phase 2: update-tools.bats

```bats
#!/usr/bin/env bats

load '../bats_helper'
load '../fixtures/mock-functions'

@test "normalize_version: extracts version from string" {
    run normalize_version "ollama version is 0.5.6"
    assert_output "0.5.6"
}

@test "normalize_version: handles version with prefix" {
    run normalize_version "v1.2.3"
    assert_output "1.2.3"
}

@test "versions_match: returns true for matching versions" {
    run versions_match "1.2.3" "1.2.3"
    assert_success
}

@test "versions_match: returns false for different versions" {
    run versions_match "1.2.3" "1.2.4"
    assert_failure
}

@test "ollama_architecture: returns amd64 for x86_64" {
    run ollama_architecture
    assert_output "amd64"
}
```

### Phase 3: post-start.bats

```bats
#!/usr/bin/env bats

load '../bats_helper'

@test "creates log directory" {
    export HOME="$TEST_TMPDIR/home"
    export XDG_STATE_HOME="$TEST_TMPDIR/.local"

    run post-start logic

    assert [ -d "$XDG_STATE_HOME/ollama" ]
}

@test "does not restart if already running" {
    # curl が常に成功返すモック
    mock_curl_available

    run post-start logic

    assert_output --partial "already running"
}
```

### Phase 5: CI 統合

`.github/workflows/ci.yml` に追加:

```yaml
- name: Install BATS
  run: npm install -g bats

- name: Run shell script tests
  run: bats tests/
```

---

## ファイル一覧

```
tests/
├── bats_helper.sh      # 共通セットアップ・ティアダウン
├── fixtures/
│   └── .gitkeep
├── update-tools.bats   # update-tools.sh 用テスト
├── post-start.bats    # post-start.sh 用テスト
├── on-create.bats     # on-create.sh 用テスト
└── post-create.bats   # post-create.sh 用テスト
```

---

## リスクと対策

| リスク | 対策 |
|--------|------|
| 外部API呼び出しがテストを不安定にする | curl をモックする |
| 実際のnpm/uv実行が遅い | `--dry-run` を使う |
| テストがホスト環境に依存する | 隔离されたTMPDIRで実行 |
