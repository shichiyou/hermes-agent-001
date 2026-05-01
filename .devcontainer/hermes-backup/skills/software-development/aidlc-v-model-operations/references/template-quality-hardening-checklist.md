# Template Quality Hardening Checklist

`aidlc-codd-graphify-template` の root starter 化後に有効だった、次段の品質改善チェックリスト。

## 目的

テンプレートを「壊れていない」から「再現しやすい・検証しやすい・CIとローカルでズレにくい」状態へ引き上げる。

## 優先順

1. 総合 verifier を作る
2. dependency pinning file を追加する
3. CI を pinned install に切り替える
4. README / manifest / usage docs を verifier 導線に寄せる
5. sample app 教育強化、導線詳細化はその後

## 推奨ファイル

- `requirements-dev.txt`
- `scripts/verify_template.py`
- `.github/workflows/template-integrity.yml`
- `.github/workflows/drift-control-gates.yml`
- `template-manifest.yaml`
- `README.md`
- `docs/template-usage.md`

## verifier の推奨責務

- 必須パス存在確認
- `py_compile`
- `pytest`
- `codd validate`
- `codd scan`
- `codd measure`
- `python scripts/check_traceability_coverage.py`
- `graphify update sample-app`
- `python scripts/check_graphify_coverage.py`
- generated / cache cleanup
- `git status --short --branch` の clean check

## clean check の運用注意

`clean_git_status=PASS` は、template source repo の実装中には評価しにくい。

理由:
- verifier に cleanup と clean check を入れると、source repo が未コミット変更を持つ時点で FAIL する
- これは verifier の欠陥ではなく、評価タイミングの問題

推奨:
- 実装中は局所 gate を回す
- 最終品質判定は commit 後の clean state で verifier を再実行する

## README の最小導線

```bash
python -m pip install -r requirements-dev.txt
python scripts/verify_template.py --check-repository
```

README では個別コマンドを長く並べるより、この 2 コマンドを正本にし、必要なら個別ゲートを補助的に紹介する。

## 依存 pinning の例

```text
pytest==9.0.3
codd-dev==1.10.0
graphifyy==0.5.7
```

## 実観測で有効だった理由

- local / CI / smoke validation の install source を一本化できる
- `python scripts/verify_template.py --check-repository` を正本コマンドにできる
- generated files cleanup 後の clean state を機械的に確認できる
- "昨日は通ったが今日は通らない" 型の再現性劣化を減らせる

## 関連ピットフォール

- plan 文書や新規 docs も CoDD 管理対象に入るなら frontmatter が必要
- `missing_depended_by` warning は reciprocal reference を追加して warning 0 にする
- Graphify coverage script は graphifyy の path 形式差異に注意する
- submodule 内変更を done と報告する前に、親 repo の submodule pointer 更新有無を必ず確認する
