# Hermes Agent Lab

このディレクトリは [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) を
本リポジトリ上で評価・実験するためのラボ運用ドキュメントをまとめる。

## 位置づけ

- upstream を改造せず「そのまま動かして評価する」ための最小構成。
- インストールは公式 `install.sh` を使用する（clone 先: `~/.hermes/hermes-agent/`）。
- hermes-agent の状態ディレクトリは `~/.hermes/`（devcontainer の Home volume に永続化）。

## ドキュメント構成

| ファイル | 内容 |
| -------- | ---- |
| [setup.md](setup.md) | 導入手順書（再現可能なコマンド列） |
| [progress.md](progress.md) | 時系列の進捗ログ（日付エントリ） |
| [findings.md](findings.md) | トピック別の知見・ハマりどころ・設定メモ |

## 運用ルール

本リポジトリの [`AGENTS.md`](../../AGENTS.md) にある Mandatory Cycle
（仮説→証拠→実行→観測検証）と Hard Gates（観測検証なしに完了を宣言しない）を、ラボ活動にも
そのまま適用する。

- 実行したコマンドは `progress.md` に残し、**実際の出力**（抜粋でよい）を併記する。
- 期待動作と実観測が食い違った場合は、隠さず「未解決」として記録する。
- 再利用可能な知見（バージョン整合・依存のハマりどころ・設定例）は `findings.md` にトピック別
  で集約する。

## Claude Code 設定（`.claude/settings.json`）

`superpowers@claude-plugins-official` プラグインをプロジェクト設定で有効化している。

- **目的**: ラボ作業中の Claude Code に `superpowers` スキル群（体系的デバッグ・TDD・レビュー等）を提供し、観測駆動の作業サイクルを補助するため
- **影響範囲**: このリポジトリを開く全ユーザーの Claude Code に適用される
- **代替**: 個人設定（`~/.claude/settings.json`）で有効化する場合はプロジェクト設定から削除して構わない

## upstream 情報（2026-04-17 確認時点）

- ライセンス: MIT
- バージョン: `0.10.0`
- Python: `>=3.11`
- 主要エントリポイント: `hermes` / `hermes-agent` / `hermes-acp`

バージョンや挙動は upstream 側で変わりうるため、実際の導入時は upstream の README と
`pyproject.toml` を都度確認する。
