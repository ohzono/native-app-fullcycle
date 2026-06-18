---
description: "フルサイクル開発: Block B 実装フェーズ（Phase 8-11）"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, WebSearch, WebFetch, Skill, Task, TeamCreate, SendMessage
argument-hint: "#issue番号"
user-invocable: true
---

# Block B: 実装フェーズ（Phase 8-11）

フルサイクル開発の実装フェーズを実行します。

## 前提条件

- `.full-cycle-state.json` が存在し、`currentPhase` が 8-11 の範囲であること
- Block A（計画フェーズ）が完了していること

## フェーズ一覧

「判定」列はエージェントによる判定や重要な出力の有無を示す。

| Phase | 内容 | 判定 |
|-------|------|------|
| 8 | TDDサイクル（tdd-test-writer） | なし |
| 9 | 機能実装（implementation-lead） | なし |
| 10 | 分割コミット（未コミット変更がなければスキップ） | なし |
| 11 | PR作成 | **PR URL出力** |

## 実行手順

0. **Worktree解決と cd（状態ファイルを読む前に必須）**

   状態ファイルは worktree 内 (`${WORKTREE_DIR}/.full-cycle-state.json`) にあります。Issue 番号から worktree を解決し、`cd` してから状態ファイルを読みます。

   ```bash
   ISSUE_NUMBER=[引数のIssue番号]
   WORKTREE_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-worktree.sh" "${ISSUE_NUMBER}")
   # ハード挙動: 前段 (full-cycle-plan) で worktree が作成済みであることが必須
   if [ -z "${WORKTREE_DIR}" ] || [ ! -d "${WORKTREE_DIR}" ]; then
     echo "ERROR: worktree for issue #${ISSUE_NUMBER} not found. Run /full-cycle-plan first."
     exit 1
   fi
   cd "${WORKTREE_DIR}"
   ```

1. `.full-cycle-state.json` を読み込み、`currentPhase` を確認する
2. Implementation Teamを作成する（未作成時のみ）:
   - Team名: `impl-team-issue-{issue番号}`
   - メンバー:
     - `test-writer` (`mobiledev-fullcycle:tdd-test-writer`)
     - `implementer` (`mobiledev-fullcycle:implementation-lead`)
   - 実行例:
   ```yaml
   TeamCreate:
     name: "impl-team-issue-{issue番号}"
     members:
       - name: test-writer
         subagent_type: mobiledev-fullcycle:tdd-test-writer
       - name: implementer
         subagent_type: mobiledev-fullcycle:implementation-lead
   ```
3. 状態ファイルから引き継ぎデータを取得する（フィールド名は `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/state-schema.yaml` を正本とする）:
   - `issue`: Issue番号
   - `branch`: ブランチ名
   - `worktreeDir`: worktreeディレクトリ
   - `decisions`: Phase 3, 5, 6 の判定結果
### コミット方針

**Phase 8/9 ではコミットしない。** 全ての変更は Phase 10 でまとめてコミットする。

理由:
- コミット粒度を Phase 10 で統一的に制御するため
- Phase 8/9 のエージェントが不適切な粒度でコミットすることを防ぐため
- Phase 9 スキップ時にもコミット済み変更が混在しないようにするため

Phase 8/9 の SendMessage に以下の制約を含めること:
> **コミット禁止**: 実装・テストの変更はファイルに書き込むが、`git add` / `git commit` は実行しないこと。コミットは Phase 10 で行います。

4. 該当するフェーズの詳細指示を `Read` ツールでロードする:
   - Phase 8: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-b/phase-08-tdd.md`
   - Phase 9: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-b/phase-09-implement.md`
   - Phase 10: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-b/phase-10-commit.md`
   - Phase 11: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-b/phase-11-pr.md`
5. フェーズの指示に従って実行する
   - Phase 8 / 9 は Implementation Team の `SendMessage` を優先利用する
6. 各フェーズ完了時に `.full-cycle-state.json` を更新する:
   - `currentPhase` を次のフェーズ番号に更新
   - `completedPhases` に完了したフェーズを追加
   - `testFiles`: Phase 8 で作成したテストファイルパス
   - `prNumber`: Phase 11 で作成したPR番号
7. Phase 11 完了後、`currentPhase` を `12` に設定する

## エラーハンドリング

| Phase | 失敗パターン | 対応 |
|-------|-------------|------|
| 8 | テスト作成失敗 | 手動でテスト作成を依頼 |
| 9 | 実装失敗 | エラー内容を記録し、手動対応を依頼 |
| 11 | PR作成失敗 | gh auth確認を促す |

## コンテキスト管理

- Implementation Team内でテスト設計意図を共有し、Phase 8→9の引き継ぎロスを防ぐ
- Team 使用時: 前フェーズの結果は Team コンテキストから自動参照（SendMessage への転写不要）
- Task フォールバック時: 状態ファイルの `decisions` から計画情報を読み込んで prompt に渡す
- ユーザー向け報告時は必要なサマリーを抜粋して記録する
- Block B完了後、Block C への引き継ぎデータ（testFiles, prNumber）は状態ファイルに保存する
- Block B 開始時は Issue コメント（Phase 7 の計画承認記録）も文脈復元に活用する
