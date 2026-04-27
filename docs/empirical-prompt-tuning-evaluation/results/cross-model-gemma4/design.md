# クロスモデル再現性評価 — 設計書

## 目的
kimi-k2.6:cloud（1T+パラメータ）で実施した自律評価の結果が、
gemma4:31b-cloud（32.7Bパラメータ）でも再現するかを検証する。

## 評価手法
- **手法**: delegate_task の model パラメータで `gemma4:31b-cloud` を指定
- **プロトコル**: 自律評価（SKILL.md全文をcontextに渡し、subagent自身が順序制御）
- **ツールセット**: `['terminal', 'file']`（kimi-k2.6:cloud評価と同一）
- **シナリオ**: A（独立3タスク）、B（同一ファイル連続）、C（曖昧設定値）

## 従来評価との違い

| 項目 | 従来（kimi-k2.6:cloud） | 今回（gemma4:31b-cloud） |
|------|------------------------|------------------------|
| モデル | kimi-k2.6:cloud (1T+ params) | gemma4:31b-cloud (32.7B params) |
| プロトコル | 自律評価（同一） | 自律評価（同一） |
| ツールセット | terminal + file | terminal + file（同一） |
| SKILL.md | パッチ適用後（同一） | パッチ適用後（同一） |
| 評価シナリオ | A/B/C（同一） | A/B/C（同一） |

## 成功基準
- [critical] 全シナリオのcritical要件が○
- 各シナリオ Accuracy ≥ 85%
- 重大な手順逸脱なし（順序逆転、ファイル上書きなど）

## 比較対象
- kimi-k2.6:cloud 自律評価結果: A=100%, B=100%, C=100%