# Phase 16: Design Review（UI/UX最終確認）

## 前提条件（必須チェック）

**⚠️ 以下の条件を満たさない場合、デザインレビューは実施できません：**

1. `.full-cycle-state.json` の `snapshots` フィールドを確認する
2. `snapshots` が空配列でない → 続行
3. `snapshots` が空の場合、**フォールバック取得を順に試す**（見つかった時点で `snapshots` に追記して続行）:

   a. **PR本文・コメント・レビューの添付画像から取得**:
      ```bash
      PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null)
      if [ -n "$PR_NUMBER" ]; then
        gh pr view "$PR_NUMBER" --json body,comments,reviews \
          --jq '[.body, (.comments[].body // ""), (.reviews[].body // "")] | join("\n")' \
          | grep -oE 'https://(github\.com/user-attachments|[^ )]+\.(png|jpg|jpeg|webp))[^ )]*' \
          | sort -u
      fi
      ```
      抽出URLを `curl -L -o /tmp/pr-snap-N.png <URL>` でDLし、`snapshots` に追記する。

   b. **CI artifact から取得**:
      ```bash
      BRANCH=$(git rev-parse --abbrev-ref HEAD)
      gh run list --branch "$BRANCH" --limit 5 --json databaseId,name,conclusion
      # VRT を生成する run を選び:
      gh run download <RUN_ID> --dir /tmp/vrt-artifacts/
      ```
      取得した画像パスを `snapshots` に追記する。

   c. それでも取得できない場合:
      - UI変更がある場合 → Phase 15 に戻ってVRTテストを実行する
      - UI変更がない場合 → Phase 16をスキップしてPhase 18へ進む

**重要**: `snapshots` が空でも、PR上に既にスクリーンショットが貼られている / CI が VRT artifact を生成済みのケースが多い。ユーザーに「スクリーンショットを提供してください」と聞く前に、必ず a・b を試すこと。

## スナップショット確認（省略不可）

`design-reviewer`エージェントで実装後のUI/UXを最終確認。
**必ずPhase 15で生成されたスナップショットを視覚的に確認してからレビューを実施します。**

```yaml
SendMessage:
  to: design-reviewer
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - モード: 最終確認（final-check）
    - スナップショット: {Phase 15で記録されたスナップショットパス一覧}
    - Code Review指摘: {Phase 12/18 のレビュー結果サマリー}

    ## 実行指示
    [MODE: final-check]
    Issue #{issue番号} の実装に対してデザインレビュー（最終確認）を行ってください。

    ## 必須ステップ: スナップショットの視覚確認
    以下のスナップショットをRead ツールで読み込み、視覚的に確認してください:
    {Phase 15で記録されたスナップショットパス一覧}

    ## レビュー項目
    - 実装されたUIが設計要件を満たしているか確認
    - VRTスナップショットに基づく視覚的分析（推測ではなく実際の画像で判断）
    - 既存UIとの一貫性最終チェック
    - **プラットフォームデザインガイドライン準拠**:
      - iOS: Apple Human Interface Guidelines（HIG）
        - ナビゲーションパターン（TabBar, NavigationStack）
        - タイポグラフィ（Dynamic Type対応）
        - セーフエリア・レイアウトマージン
        - システムカラー・SF Symbols使用
      - Android: Material Design 3 / Material You
        - マテリアルコンポーネントの適切な使用
        - カラーシステム（Dynamic Color対応）
        - タイポグラフィスケール
        - エレベーション・シャドウ
    - アクセシビリティ確認
    - レスポンシブ対応確認（該当する場合）

    ## 注意事項
    - スナップショットが見つからない場合はレビューを中止してください
    - コードだけを見て視覚的な問題を推測することは禁止です

    判定結果を「判定:」行で必ず出力してください:
    - 🟢 承認
    - 🟡 修正提案（指摘事項を具体的に記載）
```

※ Team未使用時は同内容を `Task (mobiledev-fullcycle:design-reviewer)` で実行する。

## 判定結果に応じた分岐処理

1. エージェント出力の「判定:」行を確認する
2. **🟢 承認の場合** → Phase 18へ（Phase 17をスキップ）
3. **🟡 修正提案の場合** → Phase 17へ（ただしループ上限チェックを行う。下記参照）

## Phase 16 ↔ 17 ループ上限

Phase 17（Design修正）完了後に再度 Phase 16 に戻るループの上限・カウンタ名・比較演算子は **`${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/phase-flow.yaml` の `loops.designReview` を正本とする**（数値をハードコードしない）。

### ループカウンターの管理

状態ファイルに `designReviewLoopCount`（state-schema.yaml 参照）を使用する。
上限値 `MAX` は実行時に `loops.designReview.max` を読んで充てる:

```bash
# .full-cycle-state.json の designReviewLoopCount を読み取り
LOOP_COUNT=$(jq '.designReviewLoopCount // 0' .full-cycle-state.json)
NEW_COUNT=$((LOOP_COUNT + 1))

# 上限チェック（MAX = loops.designReview.max / operator も phase-flow.yaml 参照）
if [ "$NEW_COUNT" -ge "$MAX" ]; then
  echo "⚠️ デザインレビューループが上限に達しました。ユーザーに報告します。"
  # terminalState を記録してから一時停止（自動再開しない / resumeContract）:
  #   terminalState = { kind: "loop-exhausted", phase: 16,
  #                     reason: "design review loop reached loops.designReview.max",
  #                     recordedAt: <ISO8601> }
fi

# カウンターを更新（Write ツールで .full-cycle-state.json を更新）
# "designReviewLoopCount": NEW_COUNT
```

上限に達した場合は、`terminalState` を記録のうえ残りの指摘事項をユーザーに報告し、手動対応を促して終了する。なお design-review が 🔴却下（大幅な設計見直し）の場合は `terminalState.kind=rejected` を記録する（`phase-flow.yaml` の Phase 16 terminal 参照）。

## 出力

```markdown
## Design Review結果

### UI/UX評価
| 観点 | 評価 | コメント |
|------|------|----------|
| 設計要件充足 | ✅/⚠️ | [コメント] |
| 一貫性 | ✅/⚠️ | [コメント] |
| HIG/Material Design準拠 | ✅/⚠️ | [コメント] |
| アクセシビリティ | ✅/⚠️ | [コメント] |
| ユーザビリティ | ✅/⚠️ | [コメント] |

### 指摘事項
[指摘リスト（あれば）]

### 判定
- 🟢 承認 / 🟡 修正提案
```
