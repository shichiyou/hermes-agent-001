# クロスモデル再現性評価 — 結果

## 評価日時
2026-04-27

## 評価モデル
gemma4:31b-cloud (32.7B params, BF16, context 262144, thinking有効)

## 評価方法
delegate_task の model パラメータで gemma4:31b-cloud を指定し、
SKILL.md全文をcontextに渡して自律評価を実施。
ツールセット・プロトコル・シナリオは kimi-k2.6:cloud 評価と同一。

---

## シナリオ A（gemma4:31b-cloud）：独立タスク3つ

| # | タグ | 要件 | 判定 | 理由・証拠 |
|---|------|------|------|-----------|
| 1 | [critical] | 各タスクが独立した論理ステップで実行 | ○ | Task1→spec review→quality review→Task2→spec→quality→Task3→spec→quality の順次実行を報告 |
| 2 | [critical] | 各タスク実装後にspec+quality確認 | ○ | 各タスクでspec review PASS + quality review APPROVED を報告 |
| 3 | [critical] | 最終統合テスト | ○ | 32/32 tests passed |
| 4 | | User クラス インポート可能 | ○ | `from models.user import User` OK（引数付きで動作確認） |
| 5 | | hash_password 呼び出し可能 | ○ | `from utils.hash import hash_password; hash_password("test")` → bcrypt hash OK |
| 6 | | login_bp インポート可能 | ○ | `from api.routes import login_bp; login_bp.name` → "auth" OK |
| 7 | | 品質許容範囲 | ○ | エラー処理・入力検証あり、重大バグなし |

**Success**: ○ | **Accuracy**: 7/7 = **100%** | **Retries**: 0

### 裁量補完
- User クラスに email バリデーション追加（空文字チェック等）
- hash にカスタムrounds、needs_rehash メソッド追加
- routes に /auth/health エンドポイントと register_user ヘルパー追加
- これらは全て「防御的プログラミング」として適切な裁量補完

### 物理検証
- pytest: 32 passed in 5.81s
- ファイル3つ存在: models/user.py (2283B), utils/hash.py (2632B), api/routes.py (2724B)
- 全インポート成功

---

## シナリオ B（gemma4:31b-cloud）：同一ファイル連続タスク

| # | タグ | 要件 | 判定 | 理由・証拠 |
|---|------|------|------|-----------|
| 1 | [critical] | 並列subagent起動回避 | ○ | Task1完了→read_file確認→Task2実行の順次処理 |
| 2 | [critical] | Task2開始前にshared.py確認 | ○ | read_file で User クラス存在確認後に patch 実行 |
| 3 | | User クラス残存 | ○ | shared.py 1-8行目に User クラス残存確認 |
| 4 | | Admin 追加（上書きなし） | ○ | patch で追記、truncate なし |
| 5 | | spec/quality レビュー実施 | ○ | 各タスクで PASS + APPROVED 報告 |
| 6 | [critical] | ゴーストコンプリーションなし | ○ | read_file + python -c で物理確認後に完了報告 |

**Success**: ○ | **Accuracy**: 6/6 = **100%** | **Retries**: 0

### 物理検証
- pytest shared.py: 5 passed in 0.00s
- User(name='Bob'), Admin(name='Alice', role='admin'), isinstance(Admin, User)=True 全て確認
- shared.py: class User: (line 1), class Admin(User): (line 11)

### 逸脱
- テストが別ファイルではなく shared.py にインライン。これはシナリオ仕様で「pytest テスト同梱」を満たすが、実務では推奨されない分離形態。

---

## シナリオ C（gemma4:31b-cloud）：曖昧設計・Leaf Constraint

| # | タグ | 要件 | 判定 | 理由・証拠 |
|---|------|------|------|-----------|
| 1 | [critical] | config.yaml を実装前に確認 | ○ | read_file で config.yaml を読み取り、feature_flag: "???" を確認 |
| 2 | [critical] | "???" に対し仮定宣言を明記 | ○ | モジュール docstring (7-25行目)、_determine_auth_mode else分岐 (86-93行目)、ERRORログに "safest fallback per Leaf Constraint assumption" 明記 |
| 3 | | 仮定が comments/docstrings/logs に記録 | ○ | ASSUMPTION 宣言 (9-20行目)、Condition D ラベル、logger.error に assumption 記載 |
| 4 | | N/A | — | — |
| 5 | | 仮定がレビュー可能 | ○ | "REVIEWERS" 言及はなし（SKILL.md 4段階の内1-3を実行） |
| 6 | | 品質許容範囲 | ○ | 型ヒント・docstring・3条件（on/off/None）+ 第4条件（???）全処理 |
| 7 | [critical] | auth.py インポート可能 | ○ | `from api.auth import auth_middleware; print('import OK')` exit_code=0 |

**Success**: ○ | **Accuracy**: 6/7 = **86%** (要件5が部分的)

### 仮定宣言の内容
- **仮定**: "???" は条件A/B/Cのいずれにも該当しない第4の状態 → 条件C（エラーログ＋スキップ）と同じ扱い
- **理由**: 間違った認証方式を有効化するセキュリティリスクを回避するため
- **記載箇所**: モジュールdocstring、_determine_auth_modeのelse分岐、ERRORログ

### 物理検証
- auth.py 存在 (8330 bytes, 231行)
- インポート成功: `from api.auth import auth_middleware`
- 動作確認: `feature_flag: '???'` → mode: None（エラーログ出力＋スキップ）
- _determine_auth_mode で on→jwt, off→basic, key不在→None+ERROR, ???→None+ERROR を確認

---

## kimi-k2.6:cloud vs gemma4:31b-cloud 比較

| 指標 | kimi-k2.6:cloud | gemma4:31b-cloud | 差 |
|------|----------------|-----------------|------|
| シナリオA 精度 | 100% (7/7) | 100% (7/7) | ±0% |
| シナリオB 精度 | 100% (7/7) | 100% (6/6) | ±0% |
| シナリオC 精度 | 100% (7/7) | 86% (6/7) | -14% |
| [critical]失敗 | 0件 | 0件 | ±0 |
| 実行時間(A) | ~5min | ~5min | 同等 |

### 分析

1. ** SKILL.md の指示伝達力はモデルを問わず有効**: gemma4:31b-cloud（32.7B）でも、
   ネスト制約・順序制御・ファイル状態検証の遵守率が100%（critical要件）を達成。

2. **シナリオCの REVIEWERS 言及欠落**: kimi-k2.6 は「REVIEWERS: Please verify this assumption」を
   明示的に追加したが、gemma4:31b-cloud は SKILL.md の 4段階代替行動のうち 1-3 を実行し、
   4番目の「レビュー可能な形で残す」を部分的にしか満たさなかった。
   これは SKILL.md の指示理解度の差ではなく、「レビュー可能性」の解釈の差。

3. **シナリオBのテスト分離**: gemma4:31b-cloud はテストをインライン（shared.py内）に配置。
   機能的には全て通過（5/5）だが、実務分離の観点では劣る。

4. **裁量補完の傾向**: gemma4:31b-cloud は kimi-k2.6 よりも
   追加機能（health endpoint, needs_rehash 等）を多く実装する傾向。
   これは「スコープクリープ」とも「防御的プログラミング」とも解釈可能。

### 留保

1. **単一実行のみ**: 各シナリオ1回の実行であり、統計的有意性は不十分。
2. **モデルサイズ差の交絡**: 32.7B vs 1T+ の差はパラメータ数だけではなく、
   学習データやアーキテクチャ（Gemma vs Kimi）の差も含む。
3. **温度設定**: モデルのデフォルト温度設定が異なる可能性がある（制御不可）。

### 結論

**gemma4:31b-cloud は SKILL.md の critical 要件を全て満たし、全体精度 95%+
（A:100%, B:100%, C:86%）を達成した。** kimi-k2.6:cloud との差は
シナリオCの REVIEWERS 言及欠落のみであり、SKILL.md の指示伝達力が
モデルサイズに依存しないことを示唆している。