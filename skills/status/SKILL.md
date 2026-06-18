---
name: status
description: フルサイクル開発の進捗状況を表示します。現在のフェーズ、完了済みフェーズ、判定結果を一覧で確認できます。
allowed-tools: Read, Glob, Bash
model: sonnet
user-invocable: true
argument-hint: "[#issue番号]"
---

# フルサイクル開発 進捗状況表示

> 読み取る状態フィールド名は `commands/full-cycle-phases/_schema/state-schema.yaml` の `readers.status` を正本とする。フェーズ名・終局状態の意味は `_schema/phase-flow.yaml` を参照。

## 手順

状態ファイルは各 worktree 内 (`${WORKTREE_DIR}/.full-cycle-state.json`) に配置されます。

1. **状態ファイルの探索**:
   - `$ARGUMENTS` で Issue 番号が指定されている場合: `git worktree list --porcelain` で `{feat|fix}/issue-N` ブランチの worktree を特定し、その中の `.full-cycle-state.json` を読む
   - 引数なしの場合: 現在のカレントディレクトリの `.full-cycle-state.json` を読む。なければ全 worktree の `.full-cycle-state.json` を `git worktree list --porcelain` で列挙し、見つかったすべての状態を順に表示する

   ```bash
   # Issue指定時: 共通スクリプトで解決
   ISSUE_NUMBER=$1
   WORKTREE_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-worktree.sh" "${ISSUE_NUMBER}")
   STATE_FILE="${WORKTREE_DIR}/.full-cycle-state.json"

   # 引数なし + カレントに .full-cycle-state.json が無い場合: 全 worktree を列挙
   git worktree list --porcelain \
     | awk '/^worktree / { print substr($0, 10) "/.full-cycle-state.json" }' \
     | while read -r f; do
         if [ -f "$f" ]; then
           echo "=== $f ==="
           cat "$f"
         fi
       done
   ```

2. ファイルが存在しない場合は「進行中のフルサイクル開発はありません」と表示して終了する
3. 以下のフォーマットで進捗状況を整形して表示する

## フェーズ名マッピング

```
0: Worktree準備
1: 権限チェック
2: 仕様チェック
3: PM/UX意思決定
4: 仕様検証記録
5: 開発計画
6: 技術意思決定
7: 計画承認記録
8: TDDサイクル
9: 実装仕上げ
10: コミット分割
11: PR作成
12: コードレビュー
13: PRコメント
14: 修正対応
15: VRT
16: デザインレビュー
17: デザイン修正
18: 最終レビュー
19: Fix to Merge
20: 完了
```

## 表示アイコンルール

- `completedPhases` に含まれるフェーズ: ✅
- `currentPhase` と一致するフェーズ: 🔄
- `skippedPhases` に含まれるフェーズ: ⏭️
- それ以外の未実行フェーズ: ⏳

## 出力フォーマット

以下の形式で表示する。JSON の値を埋め込むこと:

```markdown
# フルサイクル開発 進捗状況

**Issue**: #[issueNumber]
**ブランチ**: [branch]
**現在のフェーズ**: Phase [currentPhase] ([フェーズ名])
**PR**: [prNumber があれば PR URL を構築して表示、なければ「未作成」]
**終局状態**: [terminalState が null なら「進行中」。null でなければ「🛑 [kind]（Phase [phase]）: [reason]」を表示し、`_schema/phase-flow.yaml` の `resumeContract` に従い「自動再開は不可。再開/クローズはユーザー確認が必要」と明記する]

## フェーズ進捗

### Block A: 計画（Phase 0-7）
- [アイコン] Phase 0: Worktree準備
- [アイコン] Phase 1: 権限チェック
- [アイコン] Phase 2: 仕様チェック
- [アイコン] Phase 3: PM/UX意思決定
- [アイコン] Phase 4: 仕様検証記録
- [アイコン] Phase 5: 開発計画
- [アイコン] Phase 6: 技術意思決定
- [アイコン] Phase 7: 計画承認記録

### Block B: 実装（Phase 8-11）
- [アイコン] Phase 8: TDDサイクル
- [アイコン] Phase 9: 実装仕上げ
- [アイコン] Phase 10: コミット分割
- [アイコン] Phase 11: PR作成

### Block C: レビュー（Phase 12-20）
- [アイコン] Phase 12: コードレビュー
- [アイコン] Phase 13: PRコメント
- [アイコン] Phase 14: 修正対応
- [アイコン] Phase 15: VRT
- [アイコン] Phase 16: デザインレビュー
- [アイコン] Phase 17: デザイン修正
- [アイコン] Phase 18: 最終レビュー
- [アイコン] Phase 19: Fix to Merge
- [アイコン] Phase 20: 完了

## 判定結果
| フェーズ | 判定 |
|---------|------|
| Phase 2 (仕様チェック) | [decisions.spec.verdict の値、未実施なら「-」] |
| Phase 3 (PM/UX判定) | [decisions.pmUx の値、未実施なら「-」] |
| Phase 5 (開発計画) | [decisions.plan があれば「策定済み」、なければ「-」] |
| Phase 12 (コードレビュー) | [decisions.codeReview.grade の値、未実施なら「-」] |
| Phase 19 (Fix to Merge) | [decisions.fixToMerge.finalGrade の値、未実施なら「-」] |
```

## 注意事項

- PR URL は、state に `repository` 情報があればそれを使い、なければ `gh pr view [prNumber] --json url` で取得する
- `skippedPhases` が空配列または存在しない場合、スキップ表示は不要
- JSON のキー名はプロジェクトの `.full-cycle-state.json` のスキーマに従う
