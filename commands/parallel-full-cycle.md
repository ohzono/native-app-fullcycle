---
description: 親Issueのsub-issueすべてに対してフルサイクル開発を並行実行します
allowed-tools: Read, Glob, Grep, Bash, Task, TeamCreate, SendMessage, Write
argument-hint: "#親Issue番号"
user-invocable: true
---

# 並行フルサイクル開発コマンド

親Issueを指定し、そのsub-issue（子Issue）すべてに対して `/full-cycle-dev` を並行実行する統合コマンドです。

## 引数

- `#親Issue番号`: 親IssueのGitHub Issue番号（必須）

---

## 前提条件: コマンド許可の事前検証（必須・#52）

並行実行では各 sub-issue の orchestrator を **background** で spawn する。background / 非対話の Task は
対話的な許可プロンプトに応答できないため、未許可の `git push` / `gh pr create` は自動拒否されて詰む。
さらに許可コンテキストは sub-agent ごとに別であり、メインで1回 git を許可しても各 orchestrator には
引き継がれない。

そこで Phase 0 を始める前に、メインセッションで `check-permissions.sh` を実行し、git/gh と状態ファイル
Write が事前許可されているか検証する（**read-only**。settings は編集しない）:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh" --dir "$PWD" --parallel
```

| exit code | アクション |
|-----------|-----------|
| 0 | 事前許可OK。Phase 0 へ進む |
| 1 | **停止**。不足項目（`Bash(git:*)` / `Bash(gh:*)` / `Write(.full-cycle-state.json)` / `Write(.parallel-full-cycle-state.json)`）をユーザーに提示し、`.claude/settings.json` への追記を促す |
| 2 | settings 不在等で検証不能。background で詰むリスクをユーザーに伝えた上で続行可否を判断 |

> 各 orchestrator も Phase 1 で同じ検証を行う（二重ガード）。詳細は
> `commands/full-cycle-phases/block-a/phase-01-permission.md` を参照。

---

## 実行フロー概要

```
Phase 0:   親Issueからsub-issue一覧を取得
Phase 0.5: 依存グラフ構築（depends-on解析・トポロジカルソート）
Phase 1:   対象sub-issueの選定（自動決定）
Phase 2:   並行フルサイクル起動（バックグラウンド実行）
Phase 3:   進捗モニタリング & 完了待ち
Phase 4:   最終レポート作成
```

---

## Phase 0: Sub-Issue一覧の取得

### 処理内容

```bash
# 1. リポジトリ情報を取得
REPO_OWNER=$(gh repo view --json owner -q '.owner.login')
REPO_NAME=$(gh repo view --json name -q '.name')

# 2. 親IssueのNode IDを取得
PARENT_NODE_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        id
        title
        state
      }
    }
  }
' -f owner="$REPO_OWNER" -f repo="$REPO_NAME" -F number=[親Issue番号] \
  --jq '.data.repository.issue.id')

# 3. Sub-Issue一覧を取得
gh api graphql \
  -H "GraphQL-Features: sub_issues" \
  -f query='
    query($nodeId: ID!) {
      node(id: $nodeId) {
        ... on Issue {
          title
          number
          state
          subIssues(first: 50) {
            nodes {
              number
              title
              state
              body
              labels(first: 10) {
                nodes { name }
              }
            }
          }
          subIssuesSummary {
            total
            completed
            percentCompleted
          }
        }
      }
    }
  ' -f nodeId="$PARENT_NODE_ID"
```

### 出力

```markdown
## 親Issue
- **#[番号]**: [タイトル]
- **状態**: [OPEN/CLOSED]

## Sub-Issue一覧 ([合計]件 / 完了[完了数]件)

| # | タイトル | 状態 | ラベル |
|---|---------|------|--------|
| [番号] | [タイトル] | OPEN | [ラベル] |
| [番号] | [タイトル] | CLOSED | [ラベル] |
```

### エラーハンドリング

- 親Issueが存在しない場合: エラーメッセージを表示して終了
- Sub-Issueが0件の場合: 「sub-issueが見つかりません」と報告して終了
- OPENのsub-issueが0件の場合: 「すべてのsub-issueが完了済みです」と報告して終了

---

## Phase 0.5: 依存グラフ構築

### 処理内容

1. 各sub-issueの `body` からすべての `depends-on:` 行をパースしてマージする
   - Step 1: `depends-on:` 行を検出する（大文字小文字を区別しない）
   - Step 2: 検出した各行から `#(\d+)` で全issue番号を個別抽出する
   - Step 3: 複数行の結果をマージし、重複を除去する
   - 例: `depends-on: #101, #102` → [101, 102]
   - 例: `depends-on: #101` + `Depends-On: #104` → [101, 104]

2. 依存グラフを構築する
   ```json
   {
     "102": [101],
     "103": [102]
   }
   ```

3. 循環依存チェック
   - 循環が検出された場合: エラーメッセージを表示して終了
   - 例: 「循環依存が検出されました: #101 → #102 → #101」

4. トポロジカルソートで実行レイヤーに分割
   ```
   Layer 0: [#101, #104]  (依存なし → main からブランチ)
   Layer 1: [#102]         (depends-on: #101 → feat/issue-101 からブランチ)
   Layer 2: [#103]         (depends-on: #102 → feat/issue-102 からブランチ)
   ```

### 出力

依存グラフが存在する場合:
```markdown
## 依存関係分析

### 依存グラフ
- #102 → depends-on: #101
- #103 → depends-on: #102

### 実行レイヤー
| Layer | Issues | Base Branch |
|-------|--------|-------------|
| 0 | #101, #104 | main |
| 1 | #102 | feat/issue-101 |
| 2 | #103 | feat/issue-102 |

### 実行方式
- Stacked PR モード（依存関係あり）
- 各レイヤーを順次実行、レイヤー内は並列実行
```

依存グラフが存在しない場合:
```markdown
## 依存関係分析

依存関係なし → 従来の並列実行モードで実行します。
```

---

## Phase 1: 対象Sub-Issueの選定

### 処理内容

OPENステータスのsub-issueすべてを対象とする。

### 実行方式の決定

Phase 0.5の依存グラフ結果と対象sub-issue数に応じて実行方式を自動決定する:

- **依存グラフあり**: レイヤー単位の段階実行（Stacked PRモード）
- **依存グラフなし**:
  - **4件以下**: すべて並行実行
  - **5件以上**: 最大3件ずつバッチ実行（システムリソース保護のため）

---

## Phase 2: 並行フルサイクル起動

### 状態管理ファイルの作成

並行実行全体の進捗を `.parallel-full-cycle-state.json` で管理する。フィールド名・型・`subIssues[]` の itemFields・`status` の enum は **`${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/state-schema.yaml` の `parallelFields` を正本とする**。以下は初期化の具体例:

```json
{
  "parentIssue": 100,
  "startedAt": "2025-01-01T00:00:00Z",
  "mode": "parallel",
  "batchSize": null,
  "dependencyGraph": {},
  "executionLayers": [],
  "stackedPRs": {},
  "failedDependencies": [],
  "skippedDependencies": [],
  "subIssues": [
    {
      "number": 101,
      "title": "sub-issue A",
      "status": "running",
      "baseBranch": "main",
      "teamName": "fullcycle-issue-101",
      "taskId": "task_abc123",
      "isolation": "worktree",
      "isolationKey": "worktree_abc123",
      "worktreeDir": "../repo-worktrees/feat/issue-101",
      "branch": "feat/issue-101",
      "outputFile": "/path/to/output",
      "spawnRetries": 0,
      "spawnVerifiedAt": null,
      "currentPhase": 2,
      "completedPhases": [0, 1],
      "resumeState": {
        "specFiles": [],
        "decisions": {},
        "testFiles": [],
        "snapshots": [],
        "prNumber": null,
        "snapshotComment": false
      },
      "lastHeartbeatAt": "2025-01-01T00:03:00Z",
      "startedAt": "2025-01-01T00:00:00Z",
      "completedAt": null,
      "result": null,
      "prNumber": null,
      "skipReason": null,
      "error": null
    }
  ]
}
```

**`status` の取りうる値**:
- `running`: 実行中
- `respawning`: Phase 2.5 で spawn 失敗を検知し再 invoke 中（中間状態）
- `success`: 正常完了
- `stopped`: 判定により停止
- `error`: heartbeat timeout 等でエラー停止
- `spawn_failed`: Phase 2.5 でリトライ上限に達し spawn 諦め
- `skipped`: 依存先失敗による連鎖スキップ

**後方互換**: 既存 state file に `spawnRetries` が無い場合は 0 として扱う。

### Task 同期エラー捕捉（必須）

各 `Task(...)` 発行時、戻り値を確認する:

- 戻り値が無い、または `taskId` が空の場合 → 即座に state file に以下を記録:
  - `status: "spawn_failed"`
  - `error: "Task tool returned sync error: <message>"`
- これらは Phase 2.5 の検査対象から除外（既に確定）
- Phase 4 のレポートで `❌ エラー（同期エラー）` 区分として集計

### Teamベースのバックグラウンドタスク起動

対象の各sub-issueに対して、Task ツールを `run_in_background: true` +
`isolation: worktree` で並行起動する。

**重要**: 複数のTaskツール呼び出しを **1つのメッセージ** で同時に発行して並行実行を実現すること。

各orchestratorは sub-issue 専用 Team を作成し、Phase 1-20 を **直接** 実行する。
`mobiledev-fullcycle:full-cycle-dev` に再委譲してはいけない。

#### sub-issueごとのFull-Cycle Team定義

> **重要**: `TeamCreate` は team の枠（と task list）を作るだけで、**member は spawn しない**。
> SendMessage を送れるようにするには、`Agent` ツールに `team_name` + `name` パラメータを渡して
> 各 member を明示的に spawn する必要がある。orchestrator は以下の **2 段階** を順に実行すること。

**Step 1: Team の枠を作成**

```yaml
TeamCreate:
  team_name: "fullcycle-issue-[sub-issue番号]"
  description: "Full-cycle development for sub-issue #[sub-issue番号]"
```

**Step 2: 必要な member を Team に join させる（Agent tool で個別 spawn）**

各 phase で使う member を、使う直前または初期化時に Agent tool で spawn する。
`team_name` を渡すことで、その agent は Team に join し、以後 SendMessage で名前指定の通信が可能になる。

```yaml
# 例: spec-analyzer を Team に join
Agent:
  team_name: "fullcycle-issue-[sub-issue番号]"
  name: "spec-analyzer"
  subagent_type: "mobiledev-fullcycle:spec-analyzer"
  prompt: "(初期化メッセージ or 最初のタスク)"
```

| member 名 | subagent_type | 使用 phase |
|---|---|---|
| `spec-analyzer` | `mobiledev-fullcycle:spec-analyzer` | Phase 2 |
| `feature-planner` | `mobiledev-fullcycle:feature-planner` | Phase 3, 6 |
| `design-reviewer` | `mobiledev-fullcycle:design-reviewer` | Phase 3, 16 |
| `test-writer` | `mobiledev-fullcycle:tdd-test-writer` | Phase 8 |
| `implementer` | `mobiledev-fullcycle:implementation-lead` | Phase 9 |
| `code-reviewer` | `mobiledev-fullcycle:app-reviewer` | Phase 12 |
| `vrt-engineer` | `mobiledev-fullcycle:vrt-engineer` | Phase 12, 15 |
| `guideline-checker` | `mobiledev-fullcycle:guideline-checker` | Phase 12, 18 |

**Spawn 戦略**: lazy spawn 推奨（Phase 進行に応じて初回利用時に spawn）。一括 spawn より資源使用が抑えられる。

#### orchestratorの自律判断ルール

- `AskUserQuestion` は使用しない
- Phase 3 は `feature-planner` と `design-reviewer` を **1メッセージで同時発行** し、両方の結果が揃うまで待つ
- Phase 5 は計画案を自動承認して進行する
- Phase 6 (技術意思決定): `feature-planner` に SendMessage で技術アセスメント実施。
  - 「判定:」行を確認：`✅ 承認` / `⚠️ 修正提案` / `❌ 却下`
  - `✅ 承認` → Phase 7 へ進む
  - `⚠️ 修正提案` → 計画修正して再実行（`techAssessLoopCount` をインクリメント。上限は `_schema/phase-flow.yaml` の `loops.techAssess` を正本とする。数値をハードコードしない）
  - `❌ 却下` → 即座に停止（Phase 1 差し戻し / `terminalState.kind=rejected` を記録）
  - 上限到達で `✅ 承認` 未達 → 停止（`terminalState.kind=loop-exhausted` を理由に記録）
- Phase 10 は論理単位で自動コミットする
- Phase 11 は `baseBranch` を使ってPRを自動作成する
- Phase 12 は `code-reviewer`・`vrt-engineer`・`guideline-checker` を **1メッセージで同時発行** する
- Phase 16 は承認なら進行、修正提案は自動対応する
- Phase 16 でスナップショット不足なら、UI変更がない場合は Phase 18 へ進み、UI変更がある場合のみ Phase 15 を1回再実行する
- Phase 16 で大幅な設計見直しが必要になった場合は停止し、Phase 3 差し戻しを理由として記録する
- Phase 19 (Fix to Merge): `app-reviewer` に Task で別コンテキスト起動（Team の code-reviewer は禁止）。
  - 「総合評価:」行を確認：`A` / `B` / `C` / `D`
  - `A` かつ CI 通過 → Phase 20 へ進む
  - `B` / `C` → 修正実施して次ラウンド（上限は `_schema/phase-flow.yaml` の `loops.fixToMerge` を正本とする。数値をハードコードしない）
  - `D` → 即座に停止（根本的な設計見直し必要 / `decisions.fixToMerge.finalGrade=D` と `terminalState.kind=grade-d` を記録）
  - 上限到達で A + CI 未達 → 停止（`decisions.fixToMerge.finalGrade` に到達評価を記録し `terminalState.kind=loop-exhausted` を理由に記録）
- Phase 20 のマージ（`gh pr merge`）は**実行しない**。最終レビューコメントの投稿と CI 確認まで行い、「マージ準備完了」として PR 一覧の報告で終了する（マージの実行はユーザーに委ねる）

各Taskの設定:

```yaml
Task:
  description: "orchestrate full-cycle #[sub-issue番号]"
  subagent_type: general-purpose
  run_in_background: true
  isolation: worktree
  prompt: |
    あなたは sub-issue 専用フルサイクル orchestrator です。

    ## 対象
    - Issue: #[sub-issue番号]
    - 親Issue: #[親Issue番号]
    - Team名: fullcycle-issue-[sub-issue番号]
    - baseBranch: [依存先ブランチ名 or "main"]
    - isolation: worktree

    ## 必須手順
    1. TeamCreate で Team "fullcycle-issue-[sub-issue番号]" の**枠**を作成する
       （`team_name` + `description` のみ指定。`members` フィールドは存在しないので渡さない）
    1.5. Team の member は Agent tool に `team_name` + `name` + `subagent_type` を渡して
         明示的に spawn する。SendMessage で名前指定通信するには事前 spawn が必須。
         lazy spawn を推奨（各 Phase の初回利用時に必要な member を spawn）
    2. isolation 環境の `worktreeDir` / `branch` / `isolationKey` を取得し、
       `.full-cycle-state.json` を worktree 内に初期化または再利用する
       - 初回初期化時は以下を保存する:
         - `issue`: [sub-issue番号]
         - `branch`: isolation 環境のブランチ名
         - `worktreeDir`: isolation が割り当てたパス
         - `baseBranch`: [依存先ブランチ名 or "main"]
         - `currentPhase`: 1
         - `completedPhases`: [0]
         - `specFiles`: []
         - `decisions`: {}
         - `testFiles`: []
         - `snapshots`: []
         - `prNumber`: null
         - `snapshotComment`: false
         - `managedByParallel`: true
         - `teamName`: "fullcycle-issue-[sub-issue番号]"
         - `isolationKey`: isolation 識別子
       - 既存 `.full-cycle-state.json` があれば `currentPhase` から再開する
    3. Phase 0 は **実行しない**
       - isolation: worktree が worktree 作成を代替する
       - `mobiledev-fullcycle:full-cycle-dev` は呼び出さない
    4. `full-cycle-plan` / `full-cycle-impl` / `full-cycle-review` と
       各 phase 文書を Read し、Phase 1 以降を直接進行する
    5. Phase 2 / 3 / 5 / 6 / 8 / 9 / 12 / 15 / 16 / 18 は Team へ SendMessage を使う
    6. 各フェーズ遷移時に `.full-cycle-state.json` を更新し、進捗JSONを出力する

    ## 自律実行モード（重要）
    このタスクはバックグラウンドで実行されるため、ユーザーへの対話的な確認はできません。
    `AskUserQuestion` は使わず、以下のルールで自律的に判断してください：

    ### 自動承認するフェーズ
    - Phase 3 (PM/UX意思決定): `feature-planner` と `design-reviewer` を1メッセージで同時発行し、Go判定ならそのまま進行。条件付きGoの場合も進行。
    - Phase 5 (開発計画): 計画を自動承認して進行
    - Phase 6 (技術意思決定): `feature-planner` に SendMessage で実施。「判定:」行を確認し、`✅ 承認` なら Phase 7 へ。`⚠️ 修正提案` は計画修正して再実行（上限は `loops.techAssess` を参照）。`❌ 却下` / 上限到達で未承認なら停止。
    - Phase 10 (分割コミット): 論理的単位で自動コミット
    - Phase 11 (PR作成): `baseBranch` を使って自動作成
    - Phase 12: `code-reviewer`・`vrt-engineer`・`guideline-checker` を1メッセージで同時発行。Phase 12 が先に終わった場合は Phase 13/14 を先行して進めてよい。
    - Phase 16 (design-review): 承認ならそのまま進行。修正提案は自動対応。
    - Phase 16 (snapshot不足): UI変更がない場合は Phase 18 へ進行。UI変更がある場合は Phase 15 を1回再実行。
    - Phase 19 (Fix to Merge): `app-reviewer` に Task で別コンテキスト起動。「総合評価:」行を確認し、`A` かつ CI 通過なら Phase 20 へ。`B` / `C` は修正実施して再実行（上限は `loops.fixToMerge` を参照）。`D` / 上限到達で A + CI 未達なら停止。

    ### 停止条件（以下の場合は実行を中止し、理由を出力に記録）
    - **Phase 1 で権限不足が検出された場合** ⚠️ **新規**
    - Phase 3で No-Go（🔴）判定が出た場合
    - Phase 6 で修正ループが上限（`loops.techAssess`）に達してもまだ未承認の場合
    - Phase 16 で Phase 3 への差し戻しが必要な大幅変更が出た場合
    - Phase 19 で D評価が出た場合
    - Phase 19 で修正ループが上限（`loops.fixToMerge`）に達してもまだ A評価に達しない場合
    - ビルドまたはテストが連続失敗した場合（連続失敗の上限は `_schema/phase-flow.yaml` の `ciRetry.consecutiveFailureLimit` を正本とする。数値をハードコードしない）
    - isolation worktree の初期化、再接続、または状態ファイル更新に失敗した場合

    ### 権限チェック（Phase 1）の実行と停止条件
    worktree 初期化後、以下の権限チェックを順に実行する:

    0. **コマンド許可の事前検証（git/gh + 状態ファイル Write）** ⚠️ **新規（#52）**:
       - `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh" --dir "$PWD"` を実行
       - exit 1（不足）時：「git/gh または状態ファイルの事前許可が不足。メインリポジトリの `.claude/settings.json` にプラグイン同梱の `.claude/settings.example.json` の内容（allow と deny のセット）をコピーするか、`Bash(git:*)` / `Bash(gh:*)` / `Write(.full-cycle-state.json)` を **settings.example.json の deny セットと対で** 追加してから再実行してください（deny なしの包括許可は破壊的コマンドも無確認実行可能にします）」と記録して停止
       - exit 2（検証不能）時：警告のみ記録して継続
       - 理由：background 実行では対話的な許可プロンプトに応答できず、未許可の `git push` / `gh pr create` が自動拒否されて詰むため、ここで事前に弾く
    
    1. **GitHub CLI 認証確認**:
       - `gh auth status` を実行
       - 失敗時：「GitHub CLI 未認証。`gh auth login` を実行してから再実行してください」と記録して停止
    
    2. **状態ファイル書き込み権限確認**:
       - `.full-cycle-state.json` にテスト行を1行書き込み
       - 失敗時：「.full-cycle-state.json への書き込み権限なし。settings.local.json で write 権限を追加してから再実行してください」と記録して停止
    
    ### git / gh の実行層制約（#52）
    git / gh は `Bash` 保有層（この orchestrator / `implementation-lead`）が直接実行する。
    `feature-planner` / `spec-analyzer` / `app-reviewer` は `Bash` を持たないため git/gh を委譲できない
    （分析・レビュー結果の返却のみ）。`design-reviewer` / `guideline-checker` / `tdd-test-writer` /
    `vrt-engineer` は `Bash` を持つが、commit / push / PR 作成 / コンフリクト解消は呼び出し元に集約する。

    いずれかのチェックが失敗した場合、Phase 1 で停止し、理由を出力に記録する。
    すべて成功した場合、Phase 2 へ進む。

    ## baseBranch（stacked PR用）
    - `baseBranch` は stacked PR のベースブランチとして保持する
    - Phase 0 は実行しないため、新規worktree作成には使わない
    - Phase 11 でPR作成時のベースブランチとして使用する
    - 再開時は `.full-cycle-state.json` と progress / result JSON の保存値を使う

    ## 進捗ハートビート（必須）
    各フェーズ遷移時に以下JSONを1行で出力:
    {"type":"progress","issue":[sub-issue番号],"status":"running","team":"fullcycle-issue-[sub-issue番号]","baseBranch":"[依存先ブランチ名 or \"main\"]","branch":"[ブランチ名]","worktreeDir":"[worktreeパス]","isolationKey":"[isolation識別子]","currentPhase":[現在Phase],"completedPhases":[完了Phase一覧],"resumeState":{"specFiles":[],"decisions":{},"testFiles":[],"snapshots":[],"prNumber":null,"snapshotComment":false}}

    ## 最終出力（必須）
    タスク完了時に以下JSONを1行で出力:
    {
      "type": "result",
      "issue": [sub-issue番号],
      "status": "success" | "stopped" | "skipped" | "error",
      "prNumber": [PR番号 or null],
      "baseBranch": "[依存先ブランチ名 or \"main\"]",
      "branch": "[ブランチ名]",
      "teamName": "fullcycle-issue-[sub-issue番号]",
      "worktreeDir": "[worktreeパス]",
      "isolationKey": "[isolation識別子]",
      "stopReason": "[停止理由 or null]",
      "skipReason": "[スキップ理由 or null]",
      "phases": {
        "completed": [完了Phase一覧],
        "current": [現在Phase],
        "skipped": [スキップPhase一覧]
      },
      "resumeState": {
        "specFiles": [],
        "decisions": {},
        "testFiles": [],
        "snapshots": [],
        "prNumber": null,
        "snapshotComment": false
      },
      "summary": "[1-2文の概要]"
    }
```

### バッチ実行モード

「最大N件ずつバッチ実行」が選択された場合:

1. 対象sub-issueを `batchSize` 件ずつのグループに分割
2. 各バッチを順次実行:
   - バッチ内のsub-issueは並行起動（上記のTask呼び出し）
   - バッチ内の全タスクが完了するまで Phase 3 で待機
   - 全タスク完了後、次のバッチを起動
3. 状態ファイルに現在のバッチ番号を記録

```json
{
  "batchSize": 3,
  "currentBatch": 1,
  "totalBatches": 4,
  "subIssues": [...]
}
```

### レイヤー実行モード（依存関係がある場合）

依存グラフが存在する場合、レイヤー単位で段階的に実行する:

1. Layer 0 のsub-issueを並列起動（baseBranch: main）
2. Layer 0 の全タスクが完了するまで待機
3. **失敗定義と後続スキップのロジック:**
   
   **失敗の定義:**
   - `status: "error"` のタスク → エラー終了
   - `status: "stopped"` かつ `prNumber: null` のタスク → PR 未作成で停止
   - worktree 初期化失敗 / 状態ファイル更新失敗も失敗に含める
   
   **連鎖スキップアルゴリズム:**
   - Layer N で失敗したタスク #X を `failedDependencies` に追加
   - 全レイヤーを横断して依存グラフを走査し、以下を再帰的に適用:
     1. `depends-on: #X` を含むすべての sub-issue を `skippedDependencies` に追加
     2. `skippedDependencies` に追加されたタスク #Y に対し、`depends-on: #Y` を含むすべての sub-issue を再度スキップ
     3. 新たにスキップされるタスクがなくなるまで繰り返す
   - Layer N+1 以降の実行時、`.parallel-full-cycle-state.json` の `skippedDependencies` に含まれるタスクは Task 自体を起動しない
   - スキップされたタスクは result JSON に以下を記録:
     - `"status": "skipped"`
     - `"skipReason": "依存先 #X が失敗（Layer N）"` または `"skipReason": "依存先 #Y がスキップされた"`
   
4. Layer 0 の各タスク完了結果からブランチ名を取得（失敗 / スキップのタスクは除外）
5. Layer 1 のsub-issueを並列起動：
   - 対象：Layer 1 に属し、かつ `skippedDependencies` に含まれないタスクのみ
   - baseBranch：依存先タスクのブランチ名（スキップされていない場合）
6. 以降、全レイヤーが完了するまで繰り返し

**重要**: 依存チェーンで単一のタスク失敗が発生した場合、そのタスクおよび後続のすべての依存タスクが自動スキップされる。スキップは強制的であり、例外はない。Phase 4 レポートに連鎖スキップ件数を明記する。

---

## Phase 2.5: Spawn Verification

Phase 2 で全 Task を発行した直後に呼び出す。**Phase 3 とは直列実行**で、Phase 2.5 が完了するまで Phase 3 監視は開始しない（state file の並行書き込み問題を回避）。

### 処理フロー

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-task-spawn.sh" --state .parallel-full-cycle-state.json` を実行
2. JSON 出力をパースし、`failed[]` の各 sub-issue について再 invoke する:
   - state を `status: "respawning"` に遷移
   - 2-5 秒のランダムジッタを入れる
   - **Phase 2 と同じ Task テンプレート**を使い、`number` / `baseBranch` / `parentIssue` / `teamName` を state から読み出して prompt を再生成
   - `Task(run_in_background: true, isolation: worktree, prompt: <regenerated>)` を発行
   - 新しい `taskId` / `outputFile` を state file に書き込み
   - `spawnRetries` をインクリメント
3. 再 invoke 後、`check-task-spawn.sh` をもう一度実行
4. 2 回目も `failed[]` に含まれる sub-issue は:
   - `spawnRetries >= SPAWN_MAX_RETRIES` (デフォルト 2) ならば `status: "spawn_failed"` を確定
   - そうでなければ手順 2 から繰り返し
5. **degraded モード**（script が `"degraded":true` を返す = jq 不在）の場合は Phase 2.5 を skip し、Phase 3 監視で代替する
6. 全 task が `healthy` または `spawn_failed` に確定したら Phase 3 へ遷移

### 連鎖スキップへの統合

`spawn_failed` の sub-issue は Phase 2 「レイヤー実行モード」の `failedDependencies` ロジックに同等として組み込む。後続レイヤーの依存タスクは自動スキップされる。

### 設定可能パラメータ（環境変数）

| 変数 | デフォルト | 説明 |
|---|---|---|
| `SPAWN_CHECK_WAIT_SEC` | 15 | agent 初期化を待つ秒数 |
| `SPAWN_MAX_RETRIES` | 2 | spawn 失敗時の最大リトライ回数 |
| `SPAWN_CHECK_PATTERNS` | （未設定） | 追加エラーキーワード正規表現（`|` 区切り） |
| `SPAWN_CHECK_DEBUG` | （未設定） | `1` で詳細ログを stderr に出力 |

---

## Phase 3: 進捗モニタリング

### モニタリング方法

各バックグラウンドタスクの `outputFile` を定期確認し、
`type=progress` / `type=result` のJSON行を抽出して状態ファイルへ反映する。

```
1. 状態ファイル (.parallel-full-cycle-state.json) を読み込む
2. 各sub-issueの outputFile から最新の progress JSON を取得
3. `currentPhase` / `completedPhases` / `resumeState` / `branch` / `worktreeDir` / `isolationKey` / `lastHeartbeatAt` を更新
4. result JSON が出力されたタスクは `completedAt` / `prNumber` / `error` / `stopReason` を更新
5. 未完了タスクがある場合は待機
```

### ハートビート死活監視

モニタリングループの各反復で、`status: "running"` の sub-issue について以下を実行:

1. **基準時刻** = `lastHeartbeatAt ?? startedAt`（lastHeartbeatAt が null なら startedAt をフォールバック）
2. `now - 基準時刻 > STALE_THRESHOLD_SEC` (デフォルト 1800 秒 = 30 分) なら **stale 候補**
3. stale 候補について `outputFile` の mtime も確認（`stat -f "%m" <file>` (BSD) / `stat -c "%Y" <file>` (GNU) / `python3 -c '...'` の 3 段フォールバック。`${CLAUDE_PLUGIN_ROOT}/scripts/check-task-spawn.sh` 内の `get_mtime` 関数と同じロジック）:
   - mtime も 30 分以上前 → **確定 stale** → `status: "error"`, `error: "heartbeat timeout (>30min, last=<ISO>)"`
   - mtime が新しい → progress 形式が壊れている可能性。warning ログのみ
4. `status: "error"` に遷移した task は既存の `failedDependencies` ロジックで後続レイヤーへの連鎖スキップを発火させる

**閾値選定の根拠**: Phase 19 (Fix to Merge) は CI 待ちで最大 ~25 分の idle が発生し得るため、デフォルトを 30 分とした。false positive が観測された場合のみフェーズ別に細分化する。

**設定**:
- `STALE_THRESHOLD_SEC` （デフォルト 1800）: ハートビート無音の閾値

### 進捗表示

モニタリングの度にユーザーに進捗を報告:

```markdown
## 並行フルサイクル進捗状況

**親Issue**: #[番号] [タイトル]
**経過時間**: [MM分SS秒]

| # | タイトル | 状態 | Phase | PR |
|---|---------|------|-------|----|
| [番号] | [タイトル] | 🟢 完了 | 20/20 | #[PR番号] |
| [番号] | [タイトル] | 🔵 実行中 | 9/20 | - |
| [番号] | [タイトル] | 🔴 停止 | 3/20 | - |
| [番号] | [タイトル] | ⏳ 待機中 | - | - |

**進捗**: [完了数]/[合計] ([パーセント]%)
```

### 完了判定

すべてのタスクが以下のいずれかの状態になったら Phase 4 へ進む:
- `success`: 正常完了（PR作成済み）
- `stopped`: 判定により停止
- `error`: エラーにより停止

---

## Phase 4: 最終レポート作成

### 結果集約

各タスクの最終出力JSONを収集・集約する。

### 親Issueへのコメント

```bash
gh issue comment [親Issue番号] --body "$(cat <<'EOF'
<details>
<summary>🤖 並行フルサイクル開発 完了レポート — 成功 [成功数] / 停止 [停止数] / スキップ [スキップ数] / エラー [エラー数]</summary>

## 並行フルサイクル開発 完了レポート

### 実行サマリー
- **対象sub-issue**: [合計]件
- **成功**: [成功数]件
- **停止**: [停止数]件
- **スキップ**: [スキップ数]件（依存先失敗 / spawn 失敗の連鎖含む）
- **エラー**: [エラー数]件
  - うち spawn 失敗: [N]件
  - うち heartbeat timeout: [N]件

### 結果一覧

| # | タイトル | 結果 | PR | 備考 |
|---|---------|------|-----|------|
| [番号] | [タイトル] | ✅ 成功 | #[PR番号] | - |
| [番号] | [タイトル] | ⏹️ 停止 | - | [停止理由] |
| [番号] | [タイトル] | ⏭️ スキップ | - | 依存先 #[番号] が失敗 |
| [番号] | [タイトル] | ❌ エラー | - | [エラー内容] |
| [番号] | [タイトル] | ❌ エラー | - | spawn 失敗（リトライ 2回） |
| [番号] | [タイトル] | ❌ エラー | - | heartbeat timeout (>30min) |

### 作成されたPR一覧
- [ ] #[PR番号]: [タイトル]
- [ ] #[PR番号]: [タイトル]

### Stacked PR Chain
以下の順序でマージしてください:
1. #[PR番号] ([ブランチ名] → main)
2. #[PR番号] ([ブランチ名] → [依存先ブランチ名])
3. #[PR番号] ([ブランチ名] → [依存先ブランチ名])

> ※ Stacked PRがない場合、このセクションは省略されます。

### 停止・エラーとなったIssue
> 以下のIssueは手動対応が必要です:
> - #[番号]: [停止/エラー理由]

### 次のアクション
- 作成されたPRのレビュー・マージ
- 停止/エラーのIssueへの個別対応

</details>
EOF
)"
```

### ユーザーへの最終報告

```markdown
## 並行フルサイクル開発 完了

### 結果
- ✅ 成功: [N]件 → PR作成済み
- ⏹️ 停止: [N]件 → 手動対応が必要
- ⏭️ スキップ: [N]件 → 依存先失敗により自動スキップ
- ❌ エラー: [N]件 → 手動対応が必要

### 作成されたPR
[PRリンク一覧]

### Stacked PR Chain（該当する場合）
以下の順序でマージしてください:
1. #[PR番号] ([ブランチ名] → main)
2. #[PR番号] ([ブランチ名] → [依存先ブランチ名])

### スキップされたIssue
以下は依存先の失敗により自動スキップされました：
- #[番号]: depends-on #[失敗Issue] が失敗

### 手動対応が必要なIssue
- **停止**: [Issue一覧と理由]
- **エラー**: [Issue一覧と理由]

> 親Issue #[番号] にレポートをコメントしました。
```

### クリーンアップ

```bash
# 状態ファイルを削除
rm -f .parallel-full-cycle-state.json
```

---

## 中断・再開

### 再開メカニズム

`/parallel-full-cycle` を再実行した際、`.parallel-full-cycle-state.json` が存在する場合は再開モードになる。

```
1. .parallel-full-cycle-state.json の存在を確認
2. 存在する場合 → 自動的に未完了のsub-issueのみ再開する:
   - status が "running" または "error" のsub-issueのみを再起動
   - 状態ファイルに保存された `worktreeDir` / `branch` / `baseBranch` / `teamName` / `isolationKey` / `currentPhase` / `completedPhases` / `resumeState` を使って対象環境を特定する
3. 既存 `worktreeDir` に再接続でき、`.full-cycle-state.json` が残っている場合:
   - その `.full-cycle-state.json` を読み込み、中断Phaseから再開する
4. 既存 worktree に再接続できない場合:
   - 新しい `isolation: worktree` を作成する
   - 並行実行の状態ファイルに保存していた `branch` / `baseBranch` / `currentPhase` / `completedPhases` / `resumeState` を使って `.full-cycle-state.json` を再生成してから再開する
```

---

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| GraphQL APIエラー | gh auth statusを確認し、再認証を促す |
| sub-issueが50件超 | 先頭50件のみ表示し、バッチ実行を推奨 |
| isolation worktree初期化失敗 | 該当sub-issueのみ停止し、他タスクは継続 |
| 個別タスクのタイムアウト | タイムアウトを記録し、他タスクは継続 |
| 全タスク失敗 | 共通原因（権限・ネットワーク等）を調査 |
| spawn 失敗（リトライ上限到達） | spawn_failed として記録、連鎖スキップを発火 |
| heartbeat timeout | status: error として記録、連鎖スキップを発火 |

---

## 使用例

```bash
# 基本的な使用方法（親Issueの全OPEN sub-issueを並行実行）
/parallel-full-cycle #100

# 実行イメージ:
#   親Issue #100 のsub-issue:
#     #101 ログイン機能実装       → orchestrator + Team + isolation:worktree
#     #102 プロフィール画面実装    → orchestrator + Team + isolation:worktree
#     #103 設定画面実装           → orchestrator + Team + isolation:worktree
#   → 3件が並行で開発され、それぞれPRが作成される
```
