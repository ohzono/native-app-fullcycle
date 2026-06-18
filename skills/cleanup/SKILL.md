---
name: cleanup
description: フルサイクル開発完了後のクリーンアップを実行します。状態ファイルの削除、worktreeの削除、ローカルブランチの削除を行います。
allowed-tools: Read, Bash, AskUserQuestion
model: sonnet
user-invocable: true
argument-hint: "[#issue番号]"
---

# クリーンアップ

> 読み取る状態フィールド名（`issue` / `branch` / `worktreeDir`）は `commands/full-cycle-phases/_schema/state-schema.yaml` の `readers.cleanup` を正本とする。

**あなたは今からクリーンアップを実行します。冗長な前置きは省いて手順を進めてください。ただし Step 2 の実行確認（AskUserQuestion）は必須の確認ゲートであり、スキップしてはいけません。** worktree・ブランチの削除は不可逆で、未コミット・未 push の作業を巻き込むと復旧できません。

## Step 1: 状態ファイルの確認

`$ARGUMENTS` で Issue 番号が指定されているか確認する。

**重要**: 状態ファイルは worktree 内 (`${WORKTREE_DIR}/.full-cycle-state.json`) に配置されます。

### 状態ファイルの読み込み

```bash
# Issue指定時: 共通スクリプトで worktree を解決
ISSUE_NUMBER=$1
WORKTREE_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-worktree.sh" "${ISSUE_NUMBER}")
STATE_FILE="${WORKTREE_DIR}/.full-cycle-state.json"
```

`${STATE_FILE}` を Read で読み込む。引数なしの場合はカレントディレクトリの `.full-cycle-state.json` を読む。

- **存在する場合**: `issue`, `branch`, `worktreeDir`, `baseBranch` を取得する
- **存在しない場合**:
  - `$ARGUMENTS` で Issue 番号が指定されていれば、その情報を元に処理を続行する
  - 引数も未指定の場合は **Step 1a** へ進む

### baseBranch のフォールバック解決

状態ファイルが無い、または `baseBranch` フィールドが含まれていない場合は、リポジトリのデフォルトブランチを動的に解決する。`main` を決め打ちしない（デフォルトブランチが `develop` 等のリポジトリで `git checkout main` が失敗するため）:

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null \
  || git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@' \
  || echo main)
```

### 並行実行の状態ファイル

並行実行（`/parallel-full-cycle`）の状態ファイル `.parallel-full-cycle-state.json` は親リポジトリのルートに作成され、中断時には残置される。カレントディレクトリに存在する場合は削除対象に含める:

```bash
ls .parallel-full-cycle-state.json 2>/dev/null
```

### Step 1a: 引数なし + 状態ファイルなしの場合

`git worktree list` を実行して残っている worktree を一覧表示する。

```bash
git worktree list
```

表示結果をユーザーに提示し、AskUserQuestion でどの worktree を削除するか確認する。
ユーザーが選択した worktree のパスとブランチ情報を使って Step 2 以降を実行する。

## Step 2: 安全チェックとクリーンアップ対象の確認

### 2-1. 安全チェック（削除前に必ず実行）

**(a) worktree の未コミット変更**: worktree 内に未コミット変更・未追跡ファイルがないか確認する:

```bash
cd [worktreeDir] && git status --porcelain && cd -
```

出力が空でなければ、変更ファイル一覧を控えて確認表に「⚠️ 未コミット変更あり」と明示する。

**(b) 未 push コミット**: 削除対象ブランチにリモート未反映のコミットがないか確認する:

```bash
git log --oneline "origin/[branch]..[branch]" 2>/dev/null \
  || echo "リモートブランチ origin/[branch] が存在しません"
```

未 push コミットがある場合や、リモートブランチ自体が存在しない場合（PR 作成に失敗したケース等）は、ローカルブランチを削除するとコミットの唯一の実体が失われる。確認表に「⚠️ 未 push コミット N 件」「⚠️ リモートに存在しない」と明示する。

### 2-2. 実行確認（必須ゲート）

クリーンアップ対象と安全チェック結果をユーザーに表示する:

| 対象 | パス | 状態 |
|------|------|------|
| 状態ファイル | `.full-cycle-state.json` | 削除予定 |
| 並行実行状態ファイル | `.parallel-full-cycle-state.json` | 削除予定（存在する場合のみ） |
| Worktree | `[worktreeDir]` | 削除予定 / ⚠️ 未コミット変更あり |
| ローカルブランチ | `[branch]` | 削除予定 / ⚠️ 未 push コミット N 件 |
| リモートブランチ | `origin/[branch]` | 保持（PRがあるため） / ⚠️ 存在しない |

AskUserQuestion で実行確認を行う。**⚠️ が1つでもある場合は、失われる内容（変更ファイル一覧・未 push コミットのログ）を提示したうえで、その対象を削除するか個別に確認する。** ユーザーが承認したら Step 3 へ進む。

## Step 3: 実行

以下の順番でクリーンアップを実行する。各ステップでエラーが発生した場合は、その対象をスキップして次へ進む。

### 3-1. Worktree の削除

Step 2-1(a) で未コミット変更が検出された worktree は、Step 2-2 でユーザーが明示的に承認した場合のみ削除する。承認がなければスキップし、Step 4 で保留として報告する。

```bash
git worktree remove [worktreeDir] --force
```

- `--force` は gitignore 済みの状態ファイル等が worktree 内に残っていても削除するために必要（未コミット変更の保護は Step 2 の確認ゲートで担保する）
- worktree が既に存在しない場合: スキップして次へ

### 3-2. ローカルブランチの削除

現在のブランチを確認する:

```bash
git branch --show-current
```

**現在のブランチが削除対象ブランチと一致する場合のみ**、ブランチ切り替えが必要になる。一致しない場合は切り替えを行わない（ユーザーの現在ブランチを無断で変更しない）。

切り替えが必要な場合は、実行前に AskUserQuestion で「現在のブランチ [branch] から ${BASE_BRANCH} へ切り替えます」と確認したうえで切り替える:

```bash
git checkout "${BASE_BRANCH}"
```

ローカルブランチを削除する（未 push コミットがある場合は Step 2-2 での明示承認が前提）:

```bash
git branch -D [branch]
```

- ブランチが既に存在しない場合: スキップして次へ

### 3-3. 状態ファイルの削除

worktree が 3-1 で削除されている場合、worktree 内の状態ファイルも同時に消えるためこのステップは不要。worktree が存在しない/削除に失敗した場合のみ明示的に削除する:

```bash
rm -f "${WORKTREE_DIR}/.full-cycle-state.json"
```

Step 1 で並行実行の状態ファイルが検出されている場合は削除する:

```bash
rm -f .parallel-full-cycle-state.json
```

- 状態ファイルが存在しない場合: スキップして次へ

## Step 4: 完了報告

クリーンアップ結果を以下の形式で報告する:

| 対象 | 結果 |
|------|------|
| 状態ファイル | ✅ 削除済み / ⏭️ スキップ（存在しなかった） |
| 並行実行状態ファイル | ✅ 削除済み / ⏭️ スキップ（存在しなかった） |
| Worktree | ✅ 削除済み / ⏭️ スキップ（存在しなかった / 未コミット変更のため保留） |
| ローカルブランチ | ✅ 削除済み / ⏭️ スキップ（存在しなかった / 未 push コミットのため保留） |
| リモートブランチ | ⏭️ 保持（PRマージ後に自動削除） |
