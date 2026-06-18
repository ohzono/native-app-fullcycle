---
description: "フルサイクル開発: Block C レビューフェーズ（Phase 12-20）"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, WebSearch, WebFetch, Skill, Task, TeamCreate, SendMessage, AskUserQuestion
argument-hint: "#issue番号"
user-invocable: true
---

# Block C: レビューフェーズ（Phase 12-20）

フルサイクル開発のレビューフェーズを実行します。

## 前提条件

- `.full-cycle-state.json` が存在し、`currentPhase` が 12-20 の範囲であること
- Block B（実装フェーズ）が完了し、PRが作成済みであること

## フェーズ一覧

「判定」列はエージェントによる判定の有無を示す。

| Phase | 内容 | 判定 |
|-------|------|------|
| 12 | コードレビュー（code-reviewer）+ Phase 15 + **規約チェック**（同時起動） | **品質評価** |
| 13 | PRにレビューコメント追加 | なし |
| 14 | 修正対応（指摘がなければスキップ） | 条件付き |
| 15 | VRTスナップショットテスト（vrt-engineer） | 条件付き |
| 16 | Design Review（design-reviewer）+ **HIG/Material Design準拠** | **承認/修正提案** |
| 17 | Design修正対応（承認ならスキップ） | 条件付き |
| 18 | 最終Code Review + **セキュリティレビュー** | **品質評価** |
| 19 | Fix to Merge（別コンテキストレビュー + 修正ループ） | **A評価まで** |
| 20 | 最終レビューコメント・完了 + **CI待ち → マージ** | なし |

## 実行手順

0. **Worktree解決と cd（状態ファイルを読む前に必須）**

   状態ファイルは worktree 内 (`${WORKTREE_DIR}/.full-cycle-state.json`) にあります。Issue 番号から worktree を解決し、`cd` してから状態ファイルを読みます。

   ```bash
   ISSUE_NUMBER=[引数のIssue番号]
   WORKTREE_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-worktree.sh" "${ISSUE_NUMBER}")
   # ハード挙動: 前段 (full-cycle-impl) で worktree が存在することが必須
   if [ -z "${WORKTREE_DIR}" ] || [ ! -d "${WORKTREE_DIR}" ]; then
     echo "ERROR: worktree for issue #${ISSUE_NUMBER} not found. Run /full-cycle-impl first."
     exit 1
   fi
   cd "${WORKTREE_DIR}"
   ```

1. `.full-cycle-state.json` を読み込み、`currentPhase` を確認する
2. Review Teamを作成する（未作成時のみ）:
   - Team名: `review-team-issue-{issue番号}`
   - メンバー:
     - `code-reviewer` (`mobiledev-fullcycle:app-reviewer`)
     - `design-reviewer` (`mobiledev-fullcycle:design-reviewer`)
     - `vrt-engineer` (`mobiledev-fullcycle:vrt-engineer`)
     - `guideline-checker` (`mobiledev-fullcycle:guideline-checker`)
   - 実行例:
   ```yaml
   TeamCreate:
     name: "review-team-issue-{issue番号}"
     members:
       - name: code-reviewer
         subagent_type: mobiledev-fullcycle:app-reviewer
       - name: design-reviewer
         subagent_type: mobiledev-fullcycle:design-reviewer
       - name: vrt-engineer
         subagent_type: mobiledev-fullcycle:vrt-engineer
       - name: guideline-checker
         subagent_type: mobiledev-fullcycle:guideline-checker
   ```
3. 状態ファイルから引き継ぎデータを取得する:
   - `issue`: Issue番号
   - `branch`: ブランチ名
   - `worktreeDir`: worktreeディレクトリ
   - `prNumber`: PR番号
   - `testFiles`: テストファイルパス
   - `snapshots`: スナップショットパス（Phase 15 で設定）
   - `snapshotComment`: スナップショット差分コメント投稿済みフラグ（Phase 15 で設定）
4. 該当するフェーズの詳細指示を `Read` ツールでロードする:
   - Phase 12: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-12-review.md`
   - Phase 13: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-13-pr-comment.md`
   - Phase 14: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-14-fix.md`
   - Phase 15: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-15-vrt.md`
   - Phase 16: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-16-design-review.md`
   - Phase 17: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-17-design-fix.md`
   - Phase 18: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-18-final-review.md`
   - Phase 19: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-19-fix-to-merge.md`
   - Phase 20: `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/block-c/phase-20-complete.md`
5. フェーズの指示に従って実行する
   - `currentPhase = 12` の開始時は、**Phase 12 (code-reviewer)・Phase 15 (vrt-engineer)・guideline-checker を1メッセージで同時発行**する
   - VRT 実行中に Phase 12 が先に終わった場合、Phase 13/14 は先行して進めてよい
   - Phase 16 は `design-reviewer` が Team 内の code-review 文脈を参照して実行する
   - Phase 18 は初回と同じ `code-reviewer` が最終確認を行う
6. 各フェーズ完了時に `.full-cycle-state.json` を更新する
7. Phase 20 完了後、フルサイクル完了を報告する

## 条件分岐

- **Phase 15**: UI変更がない場合、Phase 15, 16, 17 をスキップして Phase 18 へ
- **Phase 14 → 15再実行**: Phase 14 の修正でUIが変わった場合、Phase 15 を再実行してから Phase 16 へ
- **Phase 16**: スナップショットが空の場合、Phase 15に戻ってVRTテストを再実行するか、Phase 18へスキップする（UI変更がない場合）
- **Phase 17**: Design Review が 🟢承認 の場合スキップ

## エラーハンドリング

| Phase | 失敗パターン | 対応 |
|-------|-------------|------|
| 15 | VRTテスト実行失敗 | 手動でスクリーンショットを提供するか、UIテスト環境を確認 |
| 16 | スナップショットなし | Phase 15に戻るか、手動でスクリーンショットを提供 |
| 16 | design-review却下 | 大幅な設計変更が必要な場合、Phase 3に戻る |
| 18 | 最終review失敗 | Phase 14に戻り修正（上限は `_schema/phase-flow.yaml` の `loops.codeReview`。超過時は `terminalState.kind=loop-exhausted` を記録しユーザーに報告） |
| 19 | D評価 | 根本的な設計見直しが必要。`terminalState.kind=grade-d` を記録しユーザーに報告して終了 |
| 19 | ラウンド上限超過 | 上限は `_schema/phase-flow.yaml` の `loops.fixToMerge`。`terminalState.kind=loop-exhausted` を記録し、現在の評価と残りの指摘をユーザーに報告して手動対応を促す |
| 19 | コンフリクト自動解消失敗 | git merge --abort してユーザーに報告 |
| 20 | CI失敗 | 失敗ジョブを報告。自動マージしない |
| 20 | マージ失敗 | 保護ブランチルール等を確認し、ユーザーに報告 |

## 品質ゲート通過基準

各レビューフェーズの評価形式と通過基準の対応:

| Phase | 評価形式 | 通過基準 | 不通過時 |
|-------|---------|---------|---------|
| 12 (コードレビュー) | ✅/⚠️/❌ × 6観点 + A/B/C/D | A（全✅） | Phase 14 で修正 |
| 12 (規約チェック) | リジェクトリスク 高/中/低/なし | 低/なし | Phase 14 で修正 |
| 16 (デザインレビュー) | 🟢承認/🟡修正提案/🔴却下 | 🟢承認 | Phase 17 で修正 |
| 18 (最終レビュー) | ✅/⚠️/❌ × 3観点 | 全✅ | Phase 14 に戻る |
| 18 (セキュリティ) | セキュリティリスク 高/中/低/なし | 低/なし | Phase 14 に戻る |
| 19 (Fix to Merge) | A/B/C/D | A | 修正して再レビュー |

**評価形式の変換ルール**:
- Phase 12/18 の `✅/⚠️/❌` → Phase 19 の `A/B/C/D`:
  - 全 ✅ = A
  - ⚠️ のみ（❌ なし）= B
  - ❌ 1件以上 = C
  - 全面的にやり直し = D

## コンテキスト管理

- Review Team内で Code Review / VRT / Design Review の文脈を共有する
- Block B の実装コンテキスト（testFiles, prNumber 等）は状態ファイルから取得する
- Task フォールバック時: 状態ファイルの各フィールドから必要情報を読み込んで prompt に渡す
- ユーザー向け報告時は必要なサマリーを抜粋して記録する
- レビュー詳細はPRコメントに記録する
