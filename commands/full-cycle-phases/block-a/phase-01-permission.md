# Phase 1: 権限チェック

フルサイクル開発では、各フェーズで `git` / `gh` コマンドと状態ファイルへの書き込みが頻繁に発生する。
特に **background / 非対話で spawn された orchestrator（`/parallel-full-cycle`）やその配下の Task は、
対話的な許可プロンプトに応答できない**ため、未許可の `git push` / `gh pr create` が自動拒否されて詰む。

そこで Phase 1 は「認証チェック」に加えて、**コマンド許可（`.claude/settings.json` の事前 allow）が
揃っているかを検証**し、不足していれば background で詰む前に早期停止する。

## 必要な権限

| 種別 | 必要なもの |
|------|-----------|
| Bash コマンド許可 | `git`（add/commit/push/fetch/merge/worktree/rev-parse/status/diff）、`gh`（pr/issue/api/repo/auth） |
| 状態ファイル Write | `.full-cycle-state.json`（並行時は `.parallel-full-cycle-state.json` も） |
| GitHub 認証 | `gh auth status` が通ること |

## チェック処理

### 1. コマンド許可の事前検証（必須）

`check-permissions.sh` で、git/gh と状態ファイル Write が `.claude/settings.json` /
`.claude/settings.local.json` で事前許可されているか検証する（**read-only**。settings は編集しない）。

```bash
# cwd（worktree）と、worktree の場合はメインのワーキングツリーの .claude/ を併せて検証する
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh" --dir "$PWD"
```

| exit code | 意味 | アクション |
|-----------|------|-----------|
| 0 | 必要な許可がすべて揃っている | 次の認証チェックへ進む |
| 1 | 許可が不足している | **停止**。スクリプトが出力する不足項目と推奨 allow をユーザーに提示する |
| 2 | 検証不能（settings 不在 / python3 不在） | 警告のみ。手動確認を促して継続（対話セッションでは実行時に個別許可できるため） |

**停止時のメッセージ例**:

> ❌ フルサイクル開発に必要なコマンド許可が不足しています。
> `.claude/settings.json` の `permissions.allow` に以下を追加してから再実行してください:
> `Bash(git:*)`, `Bash(gh:*)`, `Write(.full-cycle-state.json)`, `Edit(.full-cycle-state.json)`

> **重要**: settings.json / settings.local.json は**自動編集しない**。不足項目をユーザーに提示し、
> ユーザー自身が追記する。これは「Phase 1 は settings を書き換えない」方針を維持しつつ、
> background で詰む前に弾くためのガードである。

> **`--dir "$PWD"` の理由**: 並行実行では cwd が worktree になる。`settings.local.json` は通常
> `.gitignore` され worktree には存在しないため、スクリプトは worktree の cwd に加えて
> メインのワーキングツリーの `.claude/` も自動で参照する。

### 2. GitHub 認証チェック

1. `gh auth status` を実行する
2. 失敗する場合：`gh auth login` を提案して終了
3. 認証が通れば次へ進む

## git / gh の実行層に関する制約（必須）

> **git / gh は `Bash` ツールを保有する層でのみ実行する。`Bash` を持たない agent には git/gh を委譲しない。**

agent の `tools` は**親から継承して広がらない**（agent 定義で固定）。実際の付与状況:

| agent | Bash | git/gh 可否 |
|---|---|---|
| per-sub-issue orchestrator（`general-purpose`） / `implementation-lead` | ✅ | OK（ここで git/gh を実行する） |
| `design-reviewer` / `guideline-checker` / `tdd-test-writer` / `vrt-engineer` | ✅ | OK（ただし commit/push は呼び出し元に集約推奨） |
| `feature-planner` / `spec-analyzer` | ❌ | **git/gh 不可** |
| `app-reviewer` | ❌ | **git/gh 不可** |

→ commit / push / PR 作成 / コンフリクト解消（Phase 10/11/14/19）は **orchestrator または
`implementation-lead` が直接実行**する。`feature-planner` / `spec-analyzer` / `app-reviewer`
（いずれも `Bash` 非保有）には git/gh を委譲できず、これらは分析・レビュー結果を返すだけにする。
`design-reviewer` / `guideline-checker` / `tdd-test-writer` / `vrt-engineer` は `Bash` を持つが、
commit/push は呼び出し元（orchestrator / `implementation-lead`）に集約する
（→ 各フェーズ定義にも同じ制約を明記）。

## cwd 前提（worktree isolation）

worktree isolation 下では git は**その worktree の cwd** で実行する必要がある。状態 I/O / git 操作の前に
必ず worktree へ `cd` 済みであること（#44 の cwd 契約）。`.full-cycle-state.json` は相対パスで扱う。

## 状態ファイルの書き込み確認（重要）

**フルサイクル中に最も頻繁にブロックされるのが `.full-cycle-state.json` への書き込み**です。各フェーズ完了ごとに
更新が必要なため、ここで先行して書き込み権限を確保する（上記検証で allow があれば自動で通る）。

Phase 0 で状態ファイルを初期化した後、**Phase 1 の中で必ず1回テスト書き込みを行う**:

```bash
# 状態ファイルのパス（Phase 0 で worktree 内に作成済み、cwd は worktree）
STATE_FILE=".full-cycle-state.json"  # worktree-local relative path

# テスト書き込み: currentPhase を 1 に更新（実質的に意味のある更新）
# この時点で Write 権限が未許可なら（対話セッションでは）ユーザーに許可を求める
# → 以降の同ファイルへの書き込みはブロックされなくなる
```

Write ツールで `.full-cycle-state.json` を読み込み → `currentPhase` を更新して書き戻す。

## 出力

```markdown
## 権限チェック結果

- **コマンド許可（git/gh）**: ✅ / ❌（不足項目: ...）
- **GitHub CLI認証**: ✅ / ❌
- **状態ファイル書き込み**: ✅ / ❌

→ すべて ✅ なら次のフェーズへ／❌ があれば停止して不足項目を提示
```
