# Phase 0: Worktree準備

## 目的

メインブランチを汚さずに専用の作業環境を作成します。

## 処理内容

```bash
# リポジトリ名とIssue番号からブランチ名・ディレクトリ名を生成
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
ISSUE_NUMBER=[issue番号]

# ベースブランチ（リポジトリのデフォルトブランチを動的取得）
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || echo "main")

# Issueのラベルからtypeを決定
# "bug" ラベル → fix / その他 → feat
TYPE="feat"  # or "fix"

# ブランチ名とworktreeディレクトリ（implementation-leadと同じ命名規則）
BRANCH_NAME="${TYPE}/issue-${ISSUE_NUMBER}"
WORKTREE_DIR="../${REPO_NAME}-worktrees/${TYPE}/issue-${ISSUE_NUMBER}"

# worktree作成（ベースブランチから新しいブランチを作成）
git worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" "${BASE_BRANCH}"

# 作業ディレクトリに移動
cd "${WORKTREE_DIR}"
```

## テンプレート展開（空リポジトリ向け）

**テンプレート展開は「本当に空のリポジトリ」（`git ls-files` が 0 件）に限定する。** テンプレートには `README.md` / `gradlew` / `build.gradle.kts` / `settings.gradle.kts` / `gradle/` が含まれ、`cp -R` は同名ファイルを無確認で上書きする。特定ファイルの不在（`settings.gradle.kts` 等）だけで「空」と判定してはならない（素の iOS プロジェクト・Groovy DSL の Android プロジェクト・Flutter 等、既存リポジトリの大半が誤って「空」と判定され、ユーザーの README・ビルド設定を破壊して自動コミット・PR まで流れてしまう）。

```bash
# 真に空のリポジトリか判定（tracked ファイルが 0 件）
cd "${WORKTREE_DIR}"
TRACKED_COUNT=$(git ls-files | wc -l | tr -d ' ')

if [ "${TRACKED_COUNT}" -eq 0 ]; then
  cp -R "${CLAUDE_PLUGIN_ROOT}/templates/kmp-ios-android/." "${WORKTREE_DIR}/"

  # 状態ファイルをテンプレートから初期化（ISSUE_NUMBER等を埋め込む）
  jq \
    --arg issue "${ISSUE_NUMBER}" \
    --arg branch "${BRANCH_NAME}" \
    --arg base "${BASE_BRANCH}" \
    --arg wt "${WORKTREE_DIR}" \
    '.issue = ($issue|tonumber) | .branch = $branch | .baseBranch = $base | .worktreeDir = $wt' \
    "${WORKTREE_DIR}/.full-cycle-state.template.json" \
    > "${WORKTREE_DIR}/.full-cycle-state.json"
  rm "${WORKTREE_DIR}/.full-cycle-state.template.json"

  # ビルドチェック（共有モジュールのみ、iOS は Tuist 必要なのでスキップ）
  # Android SDK が必要（ANDROID_HOME 未設定なら ~/Library/Android/sdk を試行）
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  cd "${WORKTREE_DIR}" && ./gradlew :shared:build --no-daemon
fi
```

**既存ファイルがあるリポジトリ（`TRACKED_COUNT` > 0）の場合**:

- テンプレートは展開せず、既存プロジェクトの構成をそのまま使って次フェーズへ進む。
- ユーザーが明示的にテンプレート展開を要求している場合（コマンド引数や Issue 本文での指示）に限り、上書きされるファイルの一覧（テンプレート内容と worktree の衝突）を提示し、AskUserQuestion で承認を得てから展開する。承認が得られない場合は展開しない。
- 自律実行（`/parallel-full-cycle` の background orchestrator）では AskUserQuestion が使えないため、既存ファイルがある場合は展開しない（無人での上書きは行わない）。

- `CLAUDE_PLUGIN_ROOT` はプラグイン実行時に Claude Code が設定する環境変数
- iOS アプリの Xcode プロジェクト生成は Phase 4 以降で `tuist generate` を使用

## Phase 2（仕様チェック）の先行起動

**重要**: Worktree作成待ち時間を吸収するため、Phase 0実行時に
spec-analyzer を同時起動すること。

- 1メッセージ内で以下を同時発行すること
  - `Bash`: `git worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" "${BASE_BRANCH}"`
  - `Task`（`mobiledev-fullcycle:spec-analyzer`）: Issue仕様の分析
- 順次実行は禁止（Worktree作成完了を待ってからTask起動しない）

```yaml
# 1メッセージで同時発行
Bash: git worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" "${BASE_BRANCH}"

Task:
  description: 仕様チェックを先行実行
  subagent_type: mobiledev-fullcycle:spec-analyzer
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様ファイル: {仕様ファイルパス}（ない場合はIssue本文を参照）

    ## 実行指示
    Issue #{issue番号} の仕様を分析してください。
```

### 前提条件

- spec-analyzer は Issue本文を主対象に分析するため、worktree未作成でも実行可能
- 仕様ファイルパスが指定される場合、`main` に同ファイルがあること

## 状態ファイル初期化

**重要**: 状態ファイルは必ず worktree 内 (`${WORKTREE_DIR}/.full-cycle-state.json`) に作成すること。プロジェクトルートには作成しない（並行実行時に他Issueの状態を上書きするため）。

```bash
# worktree に cd 済みであること
cat > "${WORKTREE_DIR}/.full-cycle-state.json" <<EOF
{
  "issue": ${ISSUE_NUMBER},
  "branch": "${BRANCH_NAME}",
  "baseBranch": "${BASE_BRANCH}",
  "worktreeDir": "${WORKTREE_DIR}",
  "specFiles": [],
  "currentPhase": 1,
  "completedPhases": [0],
  "decisions": {
    "spec": null, "pmUx": null, "plan": null, "techAssess": null,
    "reviewHistory": [], "codeReview": null, "guidelineCheck": null, "securityReview": null,
    "fixToMerge": { "rounds": 0, "finalGrade": null, "history": [] }
  },
  "testFiles": [], "snapshots": [], "snapshotComment": false,
  "prNumber": null,
  "reviewLoopCount": 0, "designReviewLoopCount": 0, "techAssessLoopCount": 0,
  "skippedPhases": [],
  "terminalState": null
}
EOF
```

この初期化値の各フィールドの意味・型・デフォルトは **`${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/state-schema.yaml` を正本とする**。

以降の全フェーズは worktree 内 (`cd "${WORKTREE_DIR}"` 済み) で実行され、相対パス `.full-cycle-state.json` で参照する（パス契約は state-schema.yaml を参照）。

**状態スキーマの正本**: フィールド名・型・デフォルト・各フィールドの書き込みフェーズ（`writtenBy`）・終局フィールド `terminalState` は `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/state-schema.yaml` に定義されている。ここでは再定義しない。

## 出力

```markdown
## Worktree準備完了

- **作業ディレクトリ**: ../[repo-name]-worktrees/[type]/issue-[issue番号]
- **ブランチ名**: [type]/issue-[issue番号]
- **ベースブランチ**: [baseBranch]

→ 以降の作業はこのworktree内で実行されます
```

## エラー時の対応

- ブランチが既に存在する場合: `git worktree add "${WORKTREE_DIR}" "${BRANCH_NAME}"` で既存ブランチを使用
- worktreeが既に存在する場合: 既存worktreeを自動的に再利用する
