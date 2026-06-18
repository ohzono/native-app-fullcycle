# Phase 19: Fix to Merge（別コンテキストレビュー + 修正ループ）

Phase 12-18 のチーム内レビューが完了した後、**別コンテキスト**の `app-reviewer` で独立レビューを実施し、A評価になるまで修正を繰り返します。

## 目的

チーム内レビュー（Phase 12/18）は同じ Team コンテキストで実行されるため、文脈バイアスがかかりやすい。Phase 19 では **Task で新しいエージェントを起動** し、フレッシュな視点でレビューすることで品質を担保する。

> **実行層の制約（#52）**: `app-reviewer` は `Bash` を持たないため **レビュー（指摘の返却）専用**であり、
> git/gh は実行できない。コンフリクト解消・修正の commit/push・CI 待機などの `git` / `gh` 操作は、
> **`Bash` を保有する呼び出し元（orchestrator / `implementation-lead`）が直接実行**する。
> カテゴリAの修正は `tdd-test-writer`（`Bash` 保有）に委譲してよいが、commit/push は呼び出し元に集約する。
> 事前許可は Phase 1 で検証済み（`Bash(git:*)` / `Bash(gh:*)`）。

## 既存PRコメントの取得（必須・先頭で実行）

レビュー開始前に、PR上に既に投稿されているコメント・レビュースレッドを必ず取得する。人間レビュアーや CI のAIレビュアーが既に指摘済みの内容を見落として「ユーザーに確認してください」と聞き返すのを防ぐため。

```bash
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

# Issueスタイルのコメント（PR本文へのトップレベルコメント）
gh pr view [PR番号] --json comments \
  --jq '.comments[] | "[" + .author.login + "] " + .body'

# Reviewサマリ（approve / request_changes / comment のサマリーボディ）
gh api repos/$REPO/pulls/[PR番号]/reviews \
  --jq '.[] | select(.body != "") | "[" + .user.login + ":" + .state + "] " + .body'

# 行コメント（diff上の指摘）
gh api repos/$REPO/pulls/[PR番号]/comments \
  --jq '.[] | "[" + .user.login + "] " + .path + ":" + (.line|tostring) + " - " + .body'
```

取得したコメントは Task で `app-reviewer` に渡すプロンプトの「## 既存PRコメント」セクションに含めること。レビューラウンド N の評価判定では、ローカル再レビューの指摘 + 既存PRコメントの未対応分の両方を合わせて Critical / Should Fix を判定する。

## レビュー方式の判定

まず CI に AI PR reviewer（GitHub Actions の AI レビューワークフロー等）が設定されているか確認する:

```bash
# CI チェック一覧を取得し、既知の AI reviewer サービスの有無を確認
gh pr checks [PR番号] 2>/dev/null | grep -iE '(coderabbit|copilot.*review|sourcery|codium|ellipsis)' || echo "NOT_FOUND"
```

| 結果 | レビュー方式 |
|------|-------------|
| 既知の AI reviewer チェックが存在する | CI の AI reviewer 結果を待ち（タイムアウト: 10分）、その指摘を修正する |
| 存在しない（`NOT_FOUND`） | **ローカルで Task を使い `app-reviewer` を別コンテキスト起動**（デフォルト） |

**注意**: 大半のプロジェクトでは CI に AI reviewer は未設定のため、ローカル Task によるレビューがデフォルト動作です。

### AI reviewer 待機のタイムアウト

CI の AI reviewer を待つ場合:
- ポーリング間隔: 30秒
- タイムアウト: 10分
- タイムアウト時: ローカル Task レビューにフォールバック（AI reviewer の結果を待たない）

```bash
# タイムアウト付き待機の例
TIMEOUT=600  # 10分
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  STATUS=$(gh pr checks [PR番号] 2>/dev/null | grep -iE '(coderabbit|copilot.*review|sourcery)')
  if echo "$STATUS" | grep -q "pass\|fail"; then
    break
  fi
  sleep 30
  ELAPSED=$((ELAPSED + 30))
done
# タイムアウト時はローカルレビューにフォールバック
```

## コンフリクトチェック

レビュー前にコンフリクトを確認・解消する:

```bash
gh pr view [PR番号] --json mergeable,mergeStateStatus
```

**mergeable が CONFLICTING の場合:**

`Skill` ツールで `pr-conflict-resolution` スキルを読み込み、コンフリクトを解消する。

```bash
BASE_BRANCH=$(gh pr view [PR番号] --json baseRefName -q '.baseRefName')
git fetch origin "$BASE_BRANCH"
git merge "origin/$BASE_BRANCH"
# コンフリクト解消 → git add → git merge --continue → git push
```

自動解消が困難な場合: `git merge --abort` してユーザーに報告。

## レビュー → 修正ループ（上限は `_schema/phase-flow.yaml` の `loops.fixToMerge`）

### ラウンド N: レビュー実行

**重要**: 必ず Task で別コンテキストのエージェントに委譲する。Team 内の code-reviewer は使わない。

```yaml
Task:
  description: "PR #[PR番号] の独立コードレビュー（ラウンド[N]）"
  subagent_type: mobiledev-fullcycle:app-reviewer
  prompt: |
    ## コンテキスト
    - PR番号: #[PR番号]
    - レビューラウンド: [N]回目（上限は loops.fixToMerge を参照）
    - これはチーム内レビューとは独立した最終品質チェックです

    ## 既存PRコメント（先に取得済み）
    {上記「既存PRコメントの取得」で収集したコメント・レビュー・行コメントを貼り付け}

    上記のうち、最新コミットで対応済みのものと未対応のものを分類してください。
    未対応の指摘は本ラウンドの Critical / Should Fix に必ず含めること。

    ## レビュアの構え（必須・出力には漏らさない）
    これはチーム内レビュー（Phase 12/18）とは独立した最終品質チェックであり、文脈バイアス（自分側の成果物への迎合 = sycophancy）を外すことが目的。対象 diff を「別のエンジニアが提出した PR」として三人称で帰属させ、無条件に正しいとは仮定せず欠陥を能動的に探すこと。中立帰属をデフォルトとし「junior」等の能力 prior は使わない。批判性はコードの欠陥に向け、表現は建設的に保つ。網羅性を上げる構えで評価閾値は下げない（欠陥が nits のみなら A のまま）。
    **リークガード**: 出力（レポート / PR コメント / 確認質問）に作者帰属・人格言及（「別のエンジニアが書いた」「ジュニア」「junior」等）を含めないこと。詳細は `code-review` skill の「Phase 0」を参照。

    ## 実行指示
    PR #[PR番号] の全変更に対してコードレビューを実施してください。

    以下の観点でレビュー:
    - コード品質（可読性、保守性、DRY原則）
    - アーキテクチャ整合性（既存設計との整合）
    - セキュリティ（OWASP Top 10、入力検証）
    - パフォーマンス（メモリ効率、不要な再計算）
    - テスト品質（網羅性、保守性）
    - UX一貫性（既存UIとの統一性）

    ## 出力要件
    以下の形式で必ず出力してください:

    **総合評価**: A / B / C / D

    **必須修正（Critical）**:
    1. [ファイルパス:行番号] 問題の説明 → 修正案
       （既存PRコメント由来の場合は末尾に「(from PR comment by @user)」を付記）

    **推奨修正（Should Fix）**:
    1. [ファイルパス:行番号] 問題の説明 → 修正案

    **軽微な指摘（Nice to Have）**:
    1. [ファイルパス:行番号] 指摘

    **既存PRコメントの対応状況**:
    - 対応済み: [リスト]
    - 未対応 → Critical/ShouldFix に編入: [リスト]

    ファイルパスと行番号は必ず含めてください。修正案は具体的なコード例で示してください。
```

### 評価判定

| 評価 | アクション |
|------|-----------|
| **A** | ループ終了 → Phase 20 へ |
| **B** | 修正を実施 → 次のラウンドへ |
| **C** | 修正を実施 → 次のラウンドへ |
| **D** | **中止** — `decisions.fixToMerge.finalGrade=D` と `terminalState.kind=grade-d`（phase: 19）を記録し、ユーザーに報告して終了（根本的な設計見直しが必要） |

### 修正の実施（B/C の場合）

**重要**: パッチ修正は禁止。Phase 14 と同じ分類フローに従い、TDDサイクルで修正する。

1. 指摘ごとにカテゴリ分類（A: ロジック変更/バグ修正、B: リファクタリング、C: ドキュメント・スタイル）
2. **カテゴリAは `tdd-test-writer` に委譲してRed→Green→Refactor**

```yaml
SendMessage:
  to: test-writer
  message: |
    ## コンテキスト
    - PR番号: #[PR番号]
    - 独立レビュー（Phase 19, ラウンド[N]）の指摘事項
    - 指摘内容（カテゴリA）:
      [指摘1: ファイルパス:行番号 - 内容]

    ## 実行指示
    各指摘を再現する失敗テストを書き、最小実装で通し、リファクタリングしてください。
    パッチ修正（テストなしの直接 Edit）は禁止です。

    ## テストの声を聴く
    指摘内容をテストで再現しようとしたとき、**テストが書きにくければそれは設計問題のシグナル**です。
    - 修正すべきは「指摘箇所」ではなく「より深い設計」かもしれません
    - 独立レビューで指摘されるということは、チーム内レビュー（Phase 12/18）で見落とされた本質的な問題の可能性があります
    - テストが書きにくい理由をレポートし、必要なら Phase 5（計画見直し）or Phase 8（TDDサイクル再開）まで戻る選択肢を提示してください
```

3. カテゴリBは既存テストを維持したまま Edit、カテゴリCは Edit のみ
4. ビルド・テスト確認（既存テスト + 追加したテスト全て）
5. コミット＆プッシュ:

```bash
git add [修正したファイル]
git commit -m "fix: address independent review feedback (round [N])

- [修正内容1]
- [修正内容2]

Refs #[Issue番号]"

git push
```

6. **CI結果を待機してから次のラウンドに進む（必須）**

push 後は必ず CI の完了を待つ。CI 結果を確認せずにレビューに戻ってはならない。

```bash
LATEST_SHA=$(git rev-parse HEAD)
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

# 最大20回（30秒 × 20 = 10分）ポーリング
for i in $(seq 1 20); do
  RESULT=$(gh api repos/$REPO/commits/$LATEST_SHA/check-runs \
    --jq '[.check_runs[] | .conclusion] | if length == 0 then "no_checks" elif all(. == "success") then "success" elif any(. == null) then "pending" elif any(. == "failure") then "failure" else "other" end')
  
  case "$RESULT" in
    "success") echo "CI passed"; break ;;
    "failure") echo "CI failed"; break ;;
    "no_checks") echo "No CI checks configured"; break ;;
    "pending") echo "CI running... ($i/20)"; sleep 30 ;;
  esac
done
```

| CI 結果 | アクション |
|---------|-----------|
| `success` | 次のラウンドのレビューへ戻る |
| `failure` | CI失敗ログを取得して修正 → 再コミット＆push → CI待機を再実行 |
| `no_checks` | CIが未設定のため、次のラウンドのレビューへ進む |
| 10分経過しても `pending` | タイムアウト報告して終了 |

```bash
# CI 失敗時のログ取得
gh run list --commit $LATEST_SHA --json databaseId,name,conclusion
gh run view [RUN_ID] --log-failed
```

**CI失敗の修正もループ回数にカウントする。**

7. 次のラウンドのレビューへ戻る

### ループ上限

上限（`_schema/phase-flow.yaml` の `loops.fixToMerge.max` を正本とする。数値をハードコードしない）のレビュー/CI修正でA評価 + CI通過に達しない場合:
- `decisions.fixToMerge.finalGrade` に到達時点の評価（B/C）を記録
- `terminalState.kind=loop-exhausted`（phase: 19, reason, recordedAt）を記録（#29: 再開時の無確認再走を防ぐ）
- 現在の評価と残りの指摘をユーザーに報告
- 手動対応を促して終了（Phase 20 には進まない）

## 状態ファイルへの書き込み

```bash
# .full-cycle-state.json の decisions.fixToMerge を更新
# "decisions": {
#   ...,
#   "fixToMerge": {
#     "rounds": 2,
#     "finalGrade": "A",
#     "history": [
#       { "round": 1, "grade": "B", "fixes": 3 },
#       { "round": 2, "grade": "A", "fixes": 0 }
#     ]
#   }
# }
```

**出力**: Fix to Merge レポート（ラウンド数、最終評価、修正履歴）
