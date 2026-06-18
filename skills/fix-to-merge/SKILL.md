---
name: fix-to-merge
description: PRのコードレビューを別コンテキストで実施し、A評価になるまで修正を繰り返します。コンフリクト解消も行い、マージ可能な状態にします。
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, WebSearch, Skill, Task
model: opus
user-invocable: true
argument-hint: "[PR番号 or #issue番号]"
---

# Fix to Merge

PRを「A評価 + コンフリクトなし + CI通過」の状態にするまで、レビューと修正を自動で繰り返します。

## 引数について

- **$ARGUMENTS**: 対象PRの指定
  - **PR番号**: `#123` または `123`
  - **指定なし**: 現在のブランチに紐づくPRを自動検出

## 実行フロー

```
┌─────────────────┐
│ 1. PR特定        │
└────────┬────────┘
         ▼
┌─────────────────┐
│ 2. レビュー方式  │
│    判定          │
└────────┬────────┘
         ▼
┌─────────────────┐
│ 3. コンフリクト  │──── あり ──→ 解消してコミット
│    チェック      │
└────────┬────────┘
         ▼ なし
┌─────────────────┐
│ 4. コードレビュー │◄──────────────────┐
│   （別コンテキスト）│                    │
└────────┬────────┘                    │
         ▼                             │
┌─────────────────┐                    │
│ 5. 評価判定      │                    │
│   A → Step 8     │                    │
│   B/C → Step 6   │                    │
│   D → 中止       │                    │
└────────┬────────┘                    │
         ▼ B/C                         │
┌─────────────────┐                    │
│ 6. 指摘修正      │                    │
│   + コミット＆push │  （最大5回ループ） │
└────────┬────────┘                    │
         ▼                             │
┌─────────────────┐                    │
│ 7. CI結果待機    │────────────────────┘
│  （最大10分）     │  pass→8, fail→修正→4
└─────────────────┘
         
┌─────────────────┐
│ 8. 最終確認      │
│   + マージ準備完了 │
└─────────────────┘
```

## Step 1: PR特定と既存フィードバックの収集

```bash
# 引数からPR番号を取得、なければ現在のブランチから検出
PR_NUMBER=$ARGUMENTS
if [ -z "$PR_NUMBER" ]; then
  PR_NUMBER=$(gh pr view --json number -q '.number')
fi

# PR情報を取得
gh pr view $PR_NUMBER --json title,body,baseRefName,headRefName,additions,deletions,changedFiles,mergeable,mergeStateStatus
```

PR が見つからない場合はエラーメッセージを表示して終了。

### 既存のレビューフィードバックを取得（必須）

**重要**: ローカルで再レビューする前に、PR上に既に投稿されているコメント・レビュースレッドを必ず取得する。人間レビュアーや CodeRabbit / Copilot などが既に指摘している内容を見落として「ユーザーに確認してください」と返すのを防ぐため。

```bash
# Issue風コメント（PR本文へのコメント）
gh pr view $PR_NUMBER --json comments \
  --jq '.comments[] | "[" + .author.login + "] " + .body'

# Review本体（approve/request_changes/comment のサマリーボディ）
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews \
  --jq '.[] | select(.body != "") | "[" + .user.login + ":" + .state + "] " + .body'

# 行単位のレビューコメント（diff上にぶら下がる指摘）
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments \
  --jq '.[] | "[" + .user.login + "] " + .path + ":" + (.line|tostring) + " - " + .body'
```

`{owner}/{repo}` は `gh repo view --json nameWithOwner -q '.nameWithOwner'` で取得できる。

取得したコメントは Step 4 のレビュー前にチェックリスト化し、「未対応の指摘」として後続のレビュー結果とマージする。既に PR 上で指摘済みの内容を見落とさないこと。

## Step 2: レビュー方式の判定

CI に AI PR reviewer が設定されているか確認する:

```bash
gh pr checks $PR_NUMBER 2>/dev/null | grep -iE '(ai.review|code.review|pr.review)' || echo "NOT_FOUND"
```

| 結果 | レビュー方式 |
|------|-------------|
| AI reviewer チェックが存在 | CI の AI reviewer 結果を待ち、その指摘を修正 |
| `NOT_FOUND` | **ローカルで Task を使い `app-reviewer` を別コンテキスト起動**（デフォルト） |

大半のプロジェクトでは CI に AI reviewer は未設定のため、ローカル Task によるレビューがデフォルト動作です。

## Step 3: コンフリクトチェック＆解消

```bash
# マージ可能性を確認
gh pr view $PR_NUMBER --json mergeable,mergeStateStatus
```

**mergeable が CONFLICTING の場合:**

`Skill` ツールで `pr-conflict-resolution` スキルを読み込み、コンフリクトを解消する。

```bash
# 1. ベースブランチをマージ
BASE_BRANCH=$(gh pr view $PR_NUMBER --json baseRefName -q '.baseRefName')
git fetch origin "$BASE_BRANCH"
git merge "origin/$BASE_BRANCH"

# 2. コンフリクト解消（pr-conflict-resolution スキルの戦略に従う）

# 3. コンフリクトマーカーの残留確認
grep -rn "<<<<<<< " . --include="*.swift" --include="*.kt" --include="*.ts" --include="*.js"

# 4. ビルド確認（プロジェクトに応じたコマンド）

# 5. マージコミット完了（解消したファイルのみを個別 add）
#    ⚠️ git add . / git add -A は使わない。直後に push するため、
#    状態ファイル（.full-cycle-state.json / .parallel-full-cycle-state.json）・
#    .DS_Store・未 ignore の秘匿ファイル（.env 等）を巻き込むと公開事故になる。
git add $(git diff --name-only --diff-filter=U)  # コンフリクト解消済みファイルのみ
git merge --continue

# 6. プッシュ
git push
```

> **git add の対象（#64）**: コンフリクト解消では上記のとおり `git diff --name-only --diff-filter=U`
> で列挙したファイルのみを個別 add する。除外対象（状態ファイル・`.DS_Store` 等）は
> `commands/full-cycle-phases/block-b/phase-10-commit.md` の「git add 除外対象」に揃える。
> `git add .` / `git add -A` は使わない。

**自動解消が困難な場合**: `git merge --abort` してユーザーに報告し、終了。

## Step 4: コードレビュー（別コンテキスト）

**重要**: レビューは必ず Task で別コンテキストのエージェントに委譲する。自分自身でレビューしない。

```yaml
Task:
  description: "PR #[PR番号] のコードレビューを実施"
  subagent_type: mobiledev-fullcycle:app-reviewer
  prompt: |
    ## コンテキスト
    - PR番号: #[PR番号]
    - レビューラウンド: [N]回目（最大5回）

    ## レビュアの構え（必須・出力には漏らさない）
    対象 diff を「別のエンジニアが提出した PR」として三人称で帰属させ、無条件に正しいとは仮定せず欠陥を能動的に探すこと（迎合 = sycophancy 抑制）。中立帰属をデフォルトとし「junior」等の能力 prior は使わない。批判性はコードの欠陥に向け、表現は建設的に保つ。網羅性を上げる構えで評価閾値は下げない（欠陥が nits のみなら A のまま）。
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

    **推奨修正（Should Fix）**:
    1. [ファイルパス:行番号] 問題の説明 → 修正案

    **軽微な指摘（Nice to Have）**:
    1. [ファイルパス:行番号] 指摘

    ファイルパスと行番号は必ず含めてください。修正案は具体的なコード例で示してください。
```

## Step 5: 評価判定

Task の結果から総合評価を確認:

| 評価 | アクション |
|------|-----------|
| **A** | Step 8 へ（修正不要） |
| **B** | Step 6 へ（軽微な修正で対応可能） |
| **C** | Step 6 へ（重要な修正が必要） |
| **D** | **中止** — 根本的な設計見直しが必要。ユーザーに報告して終了 |

## Step 6: 指摘修正

レビューで指摘された項目を修正する。

### 6.1 修正の実施

必須修正（Critical）から順に対応:

1. 指摘されたファイルを Read で読み込む
2. 指摘内容に基づいて Edit で修正
3. 修正が正しいことをビルド/テストで確認

```bash
# プロジェクトに応じたビルド確認
# iOS: xcodebuild build ...
# Android: ./gradlew assembleDebug
# テスト実行
```

### 6.2 修正のコミット

```bash
git add [修正したファイル]
git commit -m "fix: address code review feedback (round [N])

- [修正内容1]
- [修正内容2]

Refs #[Issue番号]"

git push
```

push失敗時: `git pull --rebase origin [branch]` してから再push。

### 6.3 PR body に修正サマリーを追記

```bash
# <!-- fix-to-merge-summary --> マーカーで管理
# マーカーが既にあれば置換、なければ末尾に追加
gh pr edit $PR_NUMBER --body "..."
```

追記内容:
```markdown
<!-- fix-to-merge-summary -->
## Fix to Merge 修正ログ
| ラウンド | 修正内容 |
|---------|---------|
| 1 | [修正内容サマリー] |
<!-- /fix-to-merge-summary -->
```

## Step 7: CI結果待機（必須）

**重要**: push 後は必ず CI の完了を待ってから次のステップに進むこと。CI 結果を確認せずにレビューに戻ってはならない。

### 待機ロジック

最大10分間、30秒間隔でポーリングする:

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

### CI結果に基づく分岐

| CI 結果 | アクション |
|---------|-----------|
| `success` | Step 8 へ（A評価の場合）/ Step 4 に戻る（B/C評価でループ継続の場合） |
| `failure` | CI失敗ログを取得して原因を分析・修正し、再度コミット＆push → Step 7 を再実行 |
| `no_checks` | CIが設定されていないため Step 8 へ進む |
| 10分経過しても `pending` | 「CI がタイムアウトしました。`/status` で後から確認してください」と報告して終了 |

```bash
# CI 失敗時のログ取得
gh api repos/$REPO/commits/$LATEST_SHA/check-runs \
  --jq '.check_runs[] | select(.conclusion == "failure") | {name: .name, output: .output.summary}'

# 詳細ログ
gh run list --commit $LATEST_SHA --json databaseId,name,conclusion
gh run view [RUN_ID] --log-failed
```

**CI失敗の修正もループ回数にカウントする。**

### ループ制御

- **ループ回数**: 最大5回（レビュー修正 + CI修正の合計）
- 5回目でもA評価 + CI通過に達しない場合:
  - 現在の評価と残りの指摘をユーザーに報告
  - 手動対応を促して終了

→ Step 4 に戻る（次のラウンドのレビュー）

## Step 8: 最終確認・マージ準備完了

最終的なCI確認を行う。Step 7 で既にCI通過済みの場合も、最新状態を再確認する:

```bash
# 最終CI ステータス確認
gh pr checks $PR_NUMBER --watch --fail-fast
```

| CI 結果 | アクション |
|---------|-----------|
| 全て ✅ + A評価 | マージ準備完了を報告 |
| ❌ failure | Step 7 の CI修正フローに戻る（ループ上限内なら） |

### 完了レポート

```markdown
# Fix to Merge 完了レポート

**PR**: #[PR番号] [PRタイトル]
**レビューラウンド**: [N]回
**最終評価**: A
**CI**: ✅ 全チェック通過

## レビュー履歴
| ラウンド | 評価 | 修正件数 | CI結果 |
|---------|------|---------|--------|
| 1 | [B/C] | [N]件 | ✅ / ❌ |
| 2 | [A] | - | ✅ |

## コンフリクト
- [解消した / なかった]

## CI
- ✅ 全チェック通過（最終確認済み）

## ステータス
- ✅ マージ可能
```

## 実行例

```
/fix-to-merge #42
/fix-to-merge 42
/fix-to-merge        # 現在のブランチのPRを自動検出
```

## トラブルシューティング

### PR が見つからない場合
1. `gh auth status` で認証状態を確認
2. リポジトリのルートまたはworktreeで実行しているか確認
3. PR番号を明示的に指定

### レビューが5回でもA評価にならない場合
- 根本的な設計の問題の可能性
- `/check-spec` で仕様を再確認
- `/dev-plan` で実装計画を見直し

### CIが失敗する場合
- `gh pr checks` で失敗しているジョブを確認
- ログを読んで原因を特定
- 修正してプッシュ → `/fix-to-merge` を再実行
