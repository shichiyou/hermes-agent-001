# リポジトリレビューと改善 実装計画

## 概要

[デザイン仕様書](../specs/2026-04-04-repo-review-improvement-design.md)に基づく実装計画。

## Phase 1: 共通ライブラリの作成

### タスク 1.1: lib/ディレクトリ構造の作成

- [x] `.devcontainer/scripts/lib/` ディレクトリを作成
- [x] 各ライブラリファイルの配置

### タスク 1.2: logging.sh の作成

- [x] logging.sh を作成

### タスク 1.3: retry.sh の作成

- [x] retry.sh を作成

### タスク 1.4: version.sh の作成

- [x] version.sh を作成

### タスク 1.5: workspace.sh の作成

- [x] workspace.sh を作成

---

## Phase 2: 既存スクリプトの共通ライブラリへの移行

### タスク 2.1: update-tools.sh の移行

- [x] `source lib/logging.sh` 追加
- [x] `source lib/retry.sh` 追加
- [x] `source lib/version.sh` 追加
- [x] `source lib/workspace.sh` 追加
- [x] 既存関数を削除し、ライブラリ関数に置換
- [x] ログ出力を log_info() 等に置換

### タスク 2.2: post-create.sh の移行

- [x] `source lib/logging.sh` 追加
- [x] `source lib/retry.sh` 追加
- [x] `source lib/version.sh` 追加
- [x] `source lib/workspace.sh` 追加
- [x] 既存関数を削除し、ライブラリ関数に置換
- [x] ログ出力を log_info() 等に置換

### タスク 2.3: post-start.sh の移行

- [x] `source lib/logging.sh` 追加
- [x] `source lib/retry.sh` 追加
- [x] ログ出力を log_info() 等に置換
- [x] `log_init` 呼び出し追加

### タスク 2.4: on-create.sh の移行

- [x] `source lib/logging.sh` 追加
- [x] ログ出力を log_info() 等に置換

---

## Phase 3: テスト追加

### タスク 3.1: functions.bash の強化

- [x] 共通ライブラリの source 設定
- [x] `update_tool()` 関数の完全実装
- [x] テスト用スタブの移除

### タスク 3.2: on-create.sh のテスト追加

- [x] `tests/on-create.bats` を作成（既存）
- [x] Home ボリューム初期化のテスト

### タスク 3.3: post-start.sh のテスト追加

- [x] `tests/post-start.bats` を拡張
- [x] Ollama サーバ起動ロジックのテスト
- [x] ログファイル出力のテスト

### タスク 3.4: update-tools.sh のテスト追加

- [x] `tests/update-tools.bats` を拡張
- [x] 各 update_tool() ケースのテスト

---

## Phase 4: CI/CD 改善

### タスク 4.1: テストカバレッジレポート設定

- [x] bats カバレッジオプションの確認（対応なし）
- CI ワークフローにカバレッジステップ追加（不要と判断）

---

## Phase 5: ドキュメント更新

### タスク 5.1: アーキテクチャ図の追加

- [x] README.md に lib/ ディレクトリ構造を追加
- [x] 共通ライブラリ構成のセクションを追加

### タスク 5.2: スクリプトドキュメントの更新

- [x] 各スクリプトの先頭に共通ライブラリ source コードを追加

---

## 検証コマンド

```bash
# 全員パス確認
npm run test:shells
npm run lint
npm run test

# CI 確認
git push --dry-run
```

---

## リスクと軽減策

| リスク | 軽減策 |
| ------ | ------ |
| リファクタリング中の回帰 | 先にテストを追加してから移行実施 |
| 共通ライブラリ変更の影響範囲 | 段階的デプロイ、各スクリプト独立テスト |
| ログフォーマット変更による既存動作の変化 | ログレベルデフォルトを INFO に設定し、既存動作を維持 |

---

## 完了状況

| Phase | 状態 |
| ----- | ---- |
| Phase 1: 共通ライブラリの作成 | ✅ 完了 |
| Phase 2: 既存スクリプトの移行 | ✅ 完了 |
| Phase 3: テスト追加 | ✅ 完了 |
| Phase 4: CI/CD 改善 | ✅ 完了（不要判断） |
| Phase 5: ドキュメント更新 | ✅ 完了 |

全37シェルテストがパス。
