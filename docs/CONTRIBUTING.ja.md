# コントリビュートガイド

## クイックスタート

1. このリポジトリをクローンします。
2. VS Code で開きます。
3. 「Dev Containers: Reopen in Container」を実行します。
4. `.devcontainer/post-create.sh` が `package.json`、`pyproject.toml`、`.devcontainer/devcontainer.json` の pin を更新し、プロジェクト依存と AI CLI ツールの導入を終えるまで待ちます。
5. ローカルでベースラインを確認します：

```bash
npm ci
uv sync --dev
npm run lint
npm run test:shells
npm run test
```

これらのコマンドは [.github/workflows/ci.yml](.github/workflows/ci.yml) の smoke CI ワークフローと同一です。

ベースラインのデフォルトは `en_US.UTF-8` と `Etc/UTC` です。これらの値はすべての派生テンプレートに対する普遍的な要件ではなく、ベースラインのデフォルトとして扱ってください。

## ワークツリーワークフロー

このリポジトリは `.worktree/` 以下に複数のワークツリーを保持し、`/home/vscode` を共有する設計です。

新しいワークツリーを追加した後は、そのワークツリー内で依存関係同期コマンドを実行してください。`postCreateCommand` は Dev Container が作成されたときにのみ実行されるためです：

```bash
./.devcontainer/scripts/update-tools.sh node-deps
./.devcontainer/scripts/update-tools.sh python-deps
```

リポジトリルートから始める場合、典型的なフローは以下の通りです：

```bash
mkdir -p .worktree
git worktree add .worktree/feature-a -b feature-a
cd .worktree/feature-a
./.devcontainer/scripts/update-tools.sh node-deps python-deps
```

## ツールとアップデート

サポートされているアップデート対象を確認するには `./.devcontainer/scripts/update-tools.sh --list` を使います。

よく使うコマンド：

```bash
./.devcontainer/scripts/update-tools.sh node-deps
./.devcontainer/scripts/update-tools.sh node-deps-check
./.devcontainer/scripts/update-tools.sh python-deps
./.devcontainer/scripts/update-tools.sh python-deps-check
./.devcontainer/scripts/update-tools.sh uv claude-code
./.devcontainer/scripts/check-package-updates.sh
./.devcontainer/scripts/check-python-package-updates.sh
./.devcontainer/scripts/update-tools.sh --versions
```

`check-package-updates.sh` は、package.json のレンジ更新、依存の同期ずれ、`npm audit` の検出結果を
分けて報告します。何らかの対応が必要なら終了コード `1`、使用法または実行時エラーなら `2` を返します。

`check-python-package-updates.sh` は、Python 依存の specifier 更新、`uv.lock` の更新候補、環境同期ずれ、
`uv audit` の検出結果を分けて報告します。何らかの対応が必要なら終了コード `1`、使用法または実行時エラーなら `2` を返します。

`node-deps` は `package.json` の依存 pin を更新し、`package-lock.json` を更新してから `npm ci` を実行します。

`python-deps` は `pyproject.toml` の依存 pin を更新し、`uv.lock` を更新してから `uv sync --dev` を実行します。

`update-tools.sh` と `update-tools.sh --all` は、既定のツール更新だけを実行します。workspace 依存を更新したい場合は、
`node-deps` と `python-deps` を明示的に指定してください。

manifest pin 更新は、既定で現在のメジャーバージョン内にとどまります。Python 要件により厳しい上限が既にある場合は、
その上限も維持します。

`node`、`npm`、`python` は、次回 rebuild 用の runtime pin も `.devcontainer/devcontainer.json` や `package.json` に反映します。

これらのコマンドは pin と lockfile を書き換えるため、rebuild や手動同期のあとに CI や他の開発者と同じ状態を共有したい場合は、
生成された `package.json`、`pyproject.toml`、`.devcontainer/devcontainer.json`、`package-lock.json`、`uv.lock` の差分を確認して commit してください。

`.devcontainer/` 以下のすべてのシェルスクリプトは、shebang と実行権限の両方を持つことが期待されます。

## AI 生成コード

このリポジトリは AI コーディングエージェント CLI をオプションツールとしてインストールします。AI エージェントが生成したコードは、人間が書いたコードと同等の品質基準を満たす必要があります：

- 作者がだれであっても、すべての CI チェック（`npm run lint`、`npm run test:shells`、`npm run test`）がパスすること。
- AI が生成した変更も、通常のプルリクエストと同様に人間のレビューが必要です。
- AI の出力からサードパーティのコードをそのままコピーする場合は、本リポジトリの MIT ライセンスと互換性があることを確認してください。
- `.github/pull_request_template.md` のチェックリストには、これらの要件に関する明示的な項目が含まれています。

## VS Code 拡張機能

このリポジトリは拡張機能を2層で管理しています：

- `.devcontainer/devcontainer.json` には、コンテナベースライン内で自動的に利用可能であるべき拡張機能が含まれています。
- `.vscode/extensions.json` には、コントリビューター向けのより広範な推奨セットが含まれています。

新しい拡張機能を追加する際のルール：

- コンテナ体験がその拡張機能がデフォルトで存在することを必要とする場合にのみ、`.devcontainer/devcontainer.json` に追加してください。
- ベースラインの機能に必須ではないがコントリビューターにとって有用な場合は、`.vscode/extensions.json` に追加してください。

## Home ボリューム

`/home/vscode` は固定の Docker ボリューム `devcontainer-home` からマウントされます。

つまり：

- CLI のログイン状態とキャッシュは再ビルド後も保持されます。
- このリポジトリに対する複数のワークツリーが同じ Home 状態を共有します。
- 同じボリューム名を再利用した場合、同じホスト上の別々のクローンや別リポジトリも衝突する可能性があります。

Home 状態が矛盾している場合は、ボリュームを削除してコンテナを開き直してください：

```bash
docker volume rm devcontainer-home
```

## トラブルシューティング

ワークツリーが依存関係缺失場合は、ローカル同期コマンドを再実行してください：

```bash
./.devcontainer/scripts/update-tools.sh node-deps python-deps
```

シェルスクリプトが `Permission denied` で失敗する場合は、実行権限を確認してください：

```bash
find .devcontainer -type f -name '*.sh' -exec test -x {} \; -print
```

コンテナ開始後に Ollama が応答しない場合は、ログを調査してください：

```bash
printf 'OLLAMA_HOST=%s\n' "${OLLAMA_HOST:-<unset>}"
tail -n 20 ~/.local/state/ollama/post-start.log
tail -n 20 ~/.local/state/ollama/server.log
```

local モードの既定値では `OLLAMA_HOST` は `127.0.0.1:11434` であるべきです。もし
`host.docker.internal:11434` のままなら、現在のシェルが古い環境変数を引き継いでいます。まず新しいターミナルを
開くか、コンテナを再度リビルドしてから調査を続けてください。
