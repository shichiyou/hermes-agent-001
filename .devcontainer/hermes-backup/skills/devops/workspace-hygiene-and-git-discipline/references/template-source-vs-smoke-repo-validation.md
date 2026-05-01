# Template source repo と generated smoke repo の検証責務分離

## いつ参照するか
- 実験用ラボから GitHub Template Repository を抽出するとき
- template root に sample app / starter app / fixture app を同梱するか迷ったとき
- `scripts/verify_template.py` の対象を source template repo にするか、generated repo にするか整理したいとき

## 判断基準

### source template repo で検証するもの
- root 骨格が揃っているか
- agent instruction files が存在するか
- AI-DLC rule details が解決できるか
- CoDD 文書の frontmatter / scan / measure が通るか
- cleanup 後に clean git status を保てるか

### generated smoke repo で検証するもの
- `Use this template` 後の root が starter として成立するか
- AI エージェントを root から起動できるか
- Requirements Analysis を開始できるか
- 実案件コード追加後、その repo 固有の pytest / CoDD / Graphify gate を定義・実行できるか

## 避けるべき悪手
- source template repo の verifier を成立させるためだけに固定 sample app を同梱すること
- `sample-app/` のような名前で、利用者が「これが正本アプリの雛形だ」と誤認しやすい構造を置くこと
- source template repo の integrity check と generated smoke repo の app-specific validation を混同すること

## 推奨代替
- template source repo には運用骨格だけを置く
- app-specific validation は generated smoke repo で行う
- 体験評価を残したい場合は `docs/hands-on/` にハンズオン文書として置く

## この判断を採った実例
- `aidlc-codd-graphify-template` では `sample-app/` を完全削除した
- `scripts/verify_template.py` は required paths + `py_compile` + `codd validate/scan/measure` + cleanup + clean git status に縮退した
- `docs/design/template-smoke-validation-design.md` を追加し、source template と smoke repo の責務を分離した
- clean-state verification evidence:
  - `template_integrity=PASS`
  - `OK: validated 16 Markdown files under configured doc_dirs`
  - `Graph: 17 nodes, 49 edges`
  - `Health Score: 100/100`
  - `clean_git_status=PASS`
