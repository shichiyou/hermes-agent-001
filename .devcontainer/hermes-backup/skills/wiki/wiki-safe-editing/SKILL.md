---
name: wiki-safe-editing
version: 1.0.0
description: >
  Wiki (Karpathy LLM Wiki pattern) の安全な編集ワークフロー。
  read_file の行番号付き出力から old_string を抽出する際の落とし穴、
  llm-wiki スキルの規約遵守チェックリスト、親リポジトリとのサブモジュール
  不整合防止をカバーする。
tags: [wiki, editing, git, safety]
---

# Wiki Safe Editing Skill

## 問題の背景

`read_file` ツールの出力は以下のような行番号付き形式である：

```
     1|# Wiki Index
     2|
     3|> Content catalog.
```

これを `patch` の `old_string` にそのまま渡すと、ファイルに `1|` のような行番号が混入する（`patch` の fuzzy matching がマッチさせた場合）か、`patch` が失敗する。

## 正しい手順

### Step 1: 既存ファイルを書き換える前

```bash
# read_file の出力から行番号を除去して生の内容を確認
read_file path/to/file | sed 's/^\s*[0-9]*|//'
```

または、直接 `cat` で確認：

```bash
cat path/to/file
```

### Step 2: 正確な old_string を抽出

`read_file` の出力から `LINE_NUM|` を含まない純粋なテキスト行だけを抽出する。

**誤りの例：**
```
old_string: "     1|# Wiki Index"
```

**正しい例：**
```
old_string: "# Wiki Index"
```

### Step 3: patch 適用後の検証

必ず `git diff` で変更内容を確認する。不要な行番号の増減がないか特に注視。

```bash
git diff --stat
git diff -- path/to/file
```

## 編集前チェックリスト（wiki 専用）

Wiki ページを新規作成・更新する前に必ず確認：

- [ ] `SCHEMA.md` を読んだか → タグ taxonomy、frontmatter 規約、ページ閾値（200行以上で分割）
- [ ] `index.md` を読んだか → 重複回避、Total pages 更新（N→N+1）、Last updated 日付更新
- [ ] 新しいタグを使う場合は、SCHEMA.md の Tag Taxonomy に先に追加したか
- [ ] `log.md` にアペンドしたか（append-only）
- [ ] sources フロントマターに存在しない raw/articles/ を指定していないか
- [ ] ページ終了時、cross-reference（最小2本の [[wikilink]]）があるか

## サブモジュール不整合防止

Wiki を git submodule として管理している場合：

1. Wiki 側を先にコミット・プッシュする
2. 親リポジトリで `git submodule update --remote` せずに、自分で正しいコミットハッシュを `git add wiki` する
3. 親と Wiki の両方を push する（順序: Wiki → 親）

## Git Amend のリスク — 透明性原則

**Core Principle: Transparency Over Perfection**

一度共有（push）したコミットを amend や force-push で改変してはいけない。
完璧な履歴を装うより、誤りを含む誠実な履歴の方が価値がある。

### なぜ amend を避けるべきか

1. **サブモジュール参照の不整合**: commit hash が変わると、親リポジトリの `.gitmodules` 参照が無効になる
2. **分岐（diverge）の発生**: origin は旧ハッシュを指したまま、ローカルだけが新ハッシュになる
3. **他の clone への波及**: チームメンバーの環境で `git pull` が失敗する

### 正しいやり方

```
旧コミット（push済み）→ 新コミット（fix）→ merge で統合
```

 amend したくなった時は、代わりに `git revert` または新規コミットで修正し、
 `git merge origin/main` で統合する。

### push 前確認コマンド

```bash
# Wiki（サブモジュール）
cd ~/wiki && git log --oneline origin/main..HEAD
git push origin main

# 親リポジトリ
cd /workspaces/hermes-agent-template && git diff origin/main..HEAD -- wiki
git push origin main
```

## 再発防止スクリプト（オプション）

`read_file` 出力から行番号を除去するユーティリティ：

```bash
# .bashrc または alias
strip_lineno() { sed 's/^\s*[0-9]*|//' "$1"; }
```

---

## Pitfalls

1. **Never trust read_file raw output as patch input** — 行番号付き出力は display-only。
2. **Always verify with `git diff` after patch** — 行番号混入を検出する唯一の方法。
3. **Never amend pushed commits in submodule** — 他の clone に破壊を広める。
4. **Update both index AND log** — 片方だけ更新すると Wiki 構造が劣化する。
5. **Never invent source URLs in sources frontmatter** — `raw/articles/` を指定するには実ファイルが必要。
