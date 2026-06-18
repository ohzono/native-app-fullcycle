---
description: "フルサイクル開発: Block A 計画フェーズ（Phase 0-7）"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, WebSearch, WebFetch, Skill, Task, TeamCreate, SendMessage
argument-hint: "#issue番号 [仕様ファイルパス]"
user-invocable: true
---

# Block A: 計画フェーズ（Phase 0-7）

フルサイクル開発の計画フェーズを実行します。

## フェーズ一覧

「判定」列はエージェントによる Go/No-Go 等の判定の有無を示す（ユーザーへの確認質問ではない）。

| Phase | 内容 | 判定 |
|-------|------|------|
| 0 | Worktree準備 | なし |
| 1 | 権限チェック | 条件付き |
| 2 | 仕様チェック（spec-analyzer）※Phase 0 と重複実行 | なし |
| 3 | PM + UX 意思決定 | **Go/No-Go** |
| 4 | 仕様検証完了記録 | なし |
| 5 | 開発計画（feature-planner） | **計画策定** |
| 6 | 技術意思決定 | **承認/却下** |
| 7 | 計画承認記録 | なし |

## 実行手順

0. **Worktree解決と cd（状態ファイルを読む前に必須）**

   状態ファイルは worktree 内 (`${WORKTREE_DIR}/.full-cycle-state.json`) に配置されています。並行実行時の衝突を防ぐため、Issue 番号から worktree を解決し、その worktree に `cd` してから状態ファイルを読みます。

   ```bash
   ISSUE_NUMBER=[引数のIssue番号]
   WORKTREE_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-worktree.sh" "${ISSUE_NUMBER}")
   if [ -n "${WORKTREE_DIR}" ] && [ -d "${WORKTREE_DIR}" ]; then
     cd "${WORKTREE_DIR}"
   fi
   # ソフト挙動: worktree が無ければ Phase 0 で作成される（Phase 0 内で cd する）
   ```

1. `.full-cycle-state.json` を読み込み、`currentPhase` を確認する（cwdは worktree 内、なければ未開始扱いで Phase 0 へ）
2. Plan Teamを作成する（未作成時のみ）:
   - Team名: `plan-team-issue-{issue番号}`
   - メンバー:
     - `spec-analyzer` (`mobiledev-fullcycle:spec-analyzer`)
     - `feature-planner` (`mobiledev-fullcycle:feature-planner`)
     - `design-reviewer` (`mobiledev-fullcycle:design-reviewer`)
   - 実行例:
   ```yaml
   TeamCreate:
     name: "plan-team-issue-{issue番号}"
     members:
       - name: spec-analyzer
         subagent_type: mobiledev-fullcycle:spec-analyzer
       - name: feature-planner
         subagent_type: mobiledev-fullcycle:feature-planner
       - name: design-reviewer
         subagent_type: mobiledev-fullcycle:design-reviewer
   ```
3. 該当するフェーズの詳細指示を `Read` ツールでロードする:
   - Phase 0: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-00-worktree.md`
   - Phase 1: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-01-permission.md`
   - Phase 2: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-02-check-spec.md`
   - Phase 3: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-03-decision.md`
   - Phase 4: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-04-checkin-spec.md`
   - Phase 5: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-05-dev-plan.md`
   - Phase 6: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-06-tech-assess.md`
   - Phase 7: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-a/phase-07-checkin-plan.md`
4. フェーズの指示に従って実行する
   - `currentPhase = 0` の場合、Phase 0 の指示に従って
     **Worktree作成（Bash）と仕様チェック（Task）を1メッセージで同時発行**する
   - Phase 2 到達時は、先行実行した spec-analyzer の結果があるか確認し、
     あれば再利用・なければ通常どおりPhase 2を実行する
   - Phase 2 / 3 / 5 / 6 は Plan Team の `SendMessage` を優先利用する
5. 各フェーズ完了時に `.full-cycle-state.json` を更新する（フィールド名は `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/state-schema.yaml` を正本とする）:
   - `currentPhase` を次のフェーズ番号に更新
   - `completedPhases` に完了したフェーズを追加
   - フェーズ固有のデータ（decisions等）を保存
6. Phase 7 完了後、`currentPhase` を `8` に設定する

## エラーハンドリング

| Phase | 失敗パターン | 対応 |
|-------|-------------|------|
| 0 | worktree作成失敗 | 既存ブランチ/worktreeの確認を促す |
| 1 | 権限不足 | settings.json更新を提案 |
| 2 | 仕様に重大な問題 | Issue作成者に確認依頼 |
| 3 | No-Go判定 | 理由を記録して終了 |

## コンテキスト管理

- Plan Team内では Phase 2 の詳細分析結果を保持し、Phase 3/5/6 で継続利用する
- Team 使用時: 前フェーズの結果は Team コンテキストから自動参照されるため、SendMessage に転写不要
- Task フォールバック時: 状態ファイルの `decisions` から仕様・計画情報を読み込んで prompt に明示的に渡す
- ユーザー向け報告時は必要なサマリーを抜粋して記録する
- 詳細はIssueコメントに記録する
- Block A完了後、Block B への引き継ぎデータは状態ファイルに保存する
- Phase 4/7 の Issue コメントは次ブロック開始時の文脈復元にも利用する
