---
description: 仕様チェックからPR作成・レビューまでのフルサイクル開発を実行します
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, WebSearch, WebFetch, Skill, Task, AskUserQuestion
argument-hint: "#issue番号 [仕様ファイルパス]"
user-invocable: true
---

# フルサイクル開発（ディスパッチャ）

3つのブロックに分割して実行する統合コマンドです。

## 実行手順

### 1. Worktree解決 + 状態ファイル確認

**重要**: 状態ファイルは worktree 内 (`${WORKTREE_DIR}/.full-cycle-state.json`) に配置されます。並行実行時の衝突を防ぐため、dispatcher はまず Issue 番号から worktree を解決し、その worktree に `cd` してから状態ファイルを読みます。

```bash
ISSUE_NUMBER=[引数のIssue番号]

# 共通スクリプトで既存worktreeを解決（branch名が {feat|fix}/issue-N のもの）
WORKTREE_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-worktree.sh" "${ISSUE_NUMBER}")

if [ -n "${WORKTREE_DIR}" ] && [ -d "${WORKTREE_DIR}" ]; then
  cd "${WORKTREE_DIR}"
fi
```

- 既存worktreeが見つかり `.full-cycle-state.json` が存在する場合: `currentPhase` から自動再開
- 既存worktreeが見つからない場合: Block A (Phase 0) から開始（Phase 0 が worktree を作成し cd する）
- worktree内のすべての状態操作は相対パス `.full-cycle-state.json` で行う（cwd固定済みのため）

### 2. ブロック判定とSkill呼び出し

| currentPhase | Skill呼び出し |
|-------------|--------------|
| 0-7 | `Skill(skill="mobiledev-fullcycle:full-cycle-plan", args="#issue番号 [仕様ファイルパス]")` |
| 8-11 | `Skill(skill="mobiledev-fullcycle:full-cycle-impl", args="#issue番号")` |
| 12-20 | `Skill(skill="mobiledev-fullcycle:full-cycle-review", args="#issue番号")` |

### 3. ブロック完了後

状態ファイルの `currentPhase` を確認し、次のブロックが必要なら自動的に呼び出す。

## 状態ファイル構造

状態ファイル `.full-cycle-state.json` の構造（フィールド名・型・デフォルト・終局フィールド `terminalState`）は **`${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/state-schema.yaml` を正本とする**。ここで再定義しない。フェーズ遷移・ループ上限・終局条件は `_schema/phase-flow.yaml` を参照。

**パス契約（重要）**: すべての状態 I/O は worktree 内 cwd を前提に相対パス `.full-cycle-state.json` で行う。dispatcher は状態を読む前に必ず対象 worktree へ `cd` 済みであること（上記「1. Worktree解決」を参照）。

**終局状態の扱い**: `terminalState` が null でない場合、自動再開してはならない。`status` で終局種別・理由を表示し、ユーザー確認を得てから再開・クローズを判断する（`_schema/phase-flow.yaml` の `resumeContract`）。

## 権限に関する推奨設定

フルサイクル中は各フェーズで `git` / `gh` コマンドと `.full-cycle-state.json` への書き込みが発生します。
対話セッションでは初回に個別許可できますが、**`/parallel-full-cycle` のように background / 非対話で
spawn された orchestrator は対話的な許可プロンプトに応答できず、未許可の `git push` / `gh pr create` が
自動拒否されて詰みます**。以下をプロジェクトの `.claude/settings.json` に追加しておくと安定します:

**推奨はプラグイン同梱の `.claude/settings.example.json` 全体をコピーすることです**（allow と deny がセットになっています）。allow だけを個別追記する場合も、**必ず deny セットを対で設定してください**:

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(gh:*)",
      "Write(.full-cycle-state.json)",
      "Edit(.full-cycle-state.json)",
      "Write(.parallel-full-cycle-state.json)",
      "Edit(.parallel-full-cycle-state.json)"
    ],
    "deny": [
      "Bash(git push --force*)",
      "Bash(git push -f*)",
      "Bash(git push --delete*)",
      "Bash(git push * --delete*)",
      "Bash(git push -d*)",
      "Bash(git reset --hard*)",
      "Bash(git clean -f*)",
      "Bash(rm -rf *)",
      "Bash(bash *)",
      "Bash(sh *)",
      "Bash(eval *)",
      "Bash(xargs *)"
    ]
  }
}
```

> ⚠️ **`Bash(git:*)` / `Bash(gh:*)` は包括許可であり、deny がなければ `git push --force` / `git reset --hard` /
> `gh pr merge` / `gh api -X DELETE` などの破壊的コマンドも無確認で実行可能になります。**
> `Bash(git push*)` / `Bash(gh pr *)` のように必要なサブコマンドを個別列挙しても構いません
> （`.claude/settings.example.json` 参照）。なお deny は文字列の構文マッチであり完全な防御ではありません（README の注意書き参照）。

Phase 1（権限チェック）が `scripts/check-permissions.sh` でこれらの allow を検証し、不足していれば
**background で詰む前に早期停止**して不足項目を提示します（settings の自動編集は行いません）。

## 使用例

```bash
/full-cycle-dev #123
/full-cycle-dev #123 docs/specs/feature-x.md
```
