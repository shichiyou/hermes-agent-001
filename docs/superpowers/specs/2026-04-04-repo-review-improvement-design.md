# リポジトリレビューと改善 デザイン仕様書

## 1. 概要

### 背景

現在のリポジトリは Dev Container ベースラインとして良好に構成されているが、コード品質と保守性の観点から以下の課題を抱えている。

### 課題一覧

| カテゴリ | 課題 |
| ------ | ---- |
| DRY原則の違反 | `normalize_version`、`versions_match`、`find_workspace_root` などの関数が `post-create.sh` と `update-tools.sh` に重複定義 |
| テストの不足 | BATS テストが存在するが、`functions.bash` への関数エクスポートが不完全。未テストのパスが多数存在。 |
| エラーハンドリングの弱さ | 一部のスクリプトは `set -e` のみで、リトライ機構や入力検証が足りない |
| ログ出力の不統一 | スクリプト間でログフォーマットが統一されていない | |

---

## 2. 提案アプローチ

### アプローチ A: 共有関数ライブラリの抽出（推奨）

**概要**: `.devcontainer/scripts/lib/` に共通 shell 関数を抽出し、各スクリプトから source する。

**メリット**:

- DRY原則の徹底
- テスト容易性の向上
- 保守性の大幅改善

**デメリット**:

- リファクタリング期間が必要
- 既存スクリプトへの影響

---

### アプローチ B: テストカバレッジの拡張

**概要**: 既存の関数のテスト強化に加えて、`on-create.sh`、`post-start.sh` へのテスト追加。

**メリット**:

- 回帰バグの早期発見
- リファクタリングの安全性向上

**デメリット**:

- テスト作成の工数

---

### アプローチ C: エラーハンドリングとログの統一

**概要**: 統一されたエラー処理、ログライブラリ、入力検証の追加。

**メリット**:

- 運用時の問題追跡が容易
- スクリプトの堅牢性向上

**デメリット**:

- スクリプトの複雑化

---

## 3. 推奨实施方案

**アプローチ A + B + C を統合実装**することを推奨する。

### ディレクトリ構造

```text
.devcontainer/
├── scripts/
│   ├── lib/
│   │   ├── logging.sh      # 統一ログ関数（timestamp、log level、出力先）
│   │   ├── retry.sh        # リトライユーティリティ（指数バックオフ対応）
│   │   ├── version.sh      # バージョン比較関数（normalize_version、versions_match）
│   │   └── workspace.sh    # ワークスペース検出（find_workspace_root）
│   ├── update-tools.sh     # 共通ライブラリを使用
│   └── ...
├── on-create.sh            # 共通ライブラリを使用
├── post-create.sh          # 共通ライブラリを使用
└── post-start.sh          # 共通ライブラリを使用
```

### 共通ライブラリ設計

#### logging.sh

```shell
# ログレベル定義
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 関数
log_init()           # ログファイルパス設定
log_debug()          # デバッグレベルログ出力
log_info()            # 情報レベルログ出力
log_warn()           # 警告レベルログ出力
log_error()          # エラーレベルログ出力
```

#### retry.sh

```shell
# 関数
retry_init()         # リトライ回数・間隔設定
retry_run()          # コマンド実行、リトライ付き
retry_with_backoff()  # 指数バックオフ付きリトライ
```

#### version.sh

```shell
# 関数（既存関数を統合）
normalize_version()   # バージョン文字列から数値抽出
versions_match()      # バージョン一致判定
skip_if_same_version() # 同一版本ならスキップ判定
```

#### workspace.sh

```shell
# 関数
find_workspace_root()      # ワークスペースルート検出
require_workspace_root()   # ワークスペース必須チェック
workspace_npm_version()    # package.json から npm バージョン取得
```

---

## 4. 主要変更点

| カテゴリ | 変更内容 | 優先度 |
| ------ | -------- | ------ |
| 共通化 | `functions.bash` を正式なライブラリ `lib/` に昇格 | 高 |
| テスト | `on-create.sh`、`post-start.sh` のテスト追加 | 高 |
| ログ | 統一ログフォーマットの実装 | 中 |
| CI/CD | テストカバレッジレポート追加 | 中 |
| ドキュメント | アーキテクチャ図の追加 | 低 |

---

## 5. リスクと対策

| リスク | 対策 |
| ------ | ---- |
| リファクタリング中の回帰 | 先にテストを追加してからリファクタリング実施 |
| 共有ライブラリ変更の影響範囲 | 段階的デプロイ、CIで全テスト実行 |

---

## 6. 実装順序

1. **Phase 1**: 共通ライブラリの作成（logging.sh、retry.sh、version.sh、workspace.sh）
2. **Phase 2**: 既存スクリプトの共通ライブラリへの移行
3. **Phase 3**: `on-create.sh`、`post-start.sh` のテスト追加
4. **Phase 4**: CI/CD カバレッジレポート設定
5. **Phase 5**: ドキュメント更新（アーキテクチャ図追加）

---

## 7. 完了条件

- 全スクリプトが共通ライブラリを使用
- BATS テストのカバレッジが `on-create.sh`、`post-start.sh` を含む
- `npm run test:shells` がすべてパス
- CI が成功
