# Phase 14: 修正対応（必要に応じて）

## 分岐処理

1. Phase 12のレビュー結果を確認する
2. **すべて ✅ の場合**: Phase 15へ進む
3. **⚠️ または ❌ の観点がある場合**: 以下の修正手順に従う

## 修正優先順位

1. **Critical（必須修正）**: 全件対応する。スキップ不可
2. **shouldFix（推奨修正）**: 対応可否を判断する。技術的に正しく、かつ変更範囲が限定的なものは対応。大規模な変更が必要なものは理由を記録してスキップ可
3. **questions（確認質問）**: PR コメントに回答を記載する。コード修正が不要な場合でも回答は必須

## 修正方針の決定（指摘ごとに分類）

各指摘を以下の3カテゴリに分類し、それぞれ異なる修正フローを適用する:

| カテゴリ | 例 | 修正フロー |
|---------|----|-----------|
| **A: ロジック変更・バグ修正** | 条件分岐の誤り、計算式の誤り、境界値漏れ、入力検証不足 | **TDD必須**（Red→Green→Refactor） |
| **B: リファクタリング** | 命名変更、関数抽出、責務分離、型定義改善 | 既存テストを維持したまま Edit で修正 |
| **C: ドキュメント・スタイル** | コメント追加、フォーマット、import順序 | Edit で修正（テスト不要） |

判断に迷う場合は **A（TDD）を選択**する。

## 修正の実施

### カテゴリA（TDD必須）

`tdd-test-writer` エージェントを使い、指摘内容を再現する失敗テストから書き始める。Phase 8 と同じTDDサイクルを維持する。

```yaml
SendMessage:
  to: test-writer
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - PR番号: #{PR番号}
    - レビュー指摘事項（カテゴリA）:
      [指摘1: ファイルパス:行番号 - 内容]
      [指摘2: ファイルパス:行番号 - 内容]

    ## 実行指示
    各指摘について、以下のTDDサイクルで修正してください:

    1. **Red**: 指摘された問題を再現する失敗テストを追加
       - バグ修正なら「修正前のコードでは失敗するテスト」
       - 入力検証漏れなら「不正入力で例外を期待するテスト」
    2. **Green**: 最小実装でテストを通す
    3. **Refactor**: コードを整理（テストは引き続き通る）

    ## 重要な制約
    - パッチ修正（テストなしの直接 Edit）は禁止
    - 既存テストが壊れていないことを必ず確認

    ## テストの声を聴く
    指摘内容をテストで再現しようとしたとき、**テストが書きにくければそれは設計問題のシグナル**です。
    パッチ的なテスト追加ではなく、設計改善（責務分割、依存性注入、インターフェース抽出）を検討してください。
    - 修正すべきは「指摘箇所」ではなく「より深い設計」かもしれません
    - 判断に迷ったら「テストが書きにくい理由」をレポートし、Phase 5（計画見直し）or Phase 8（TDDサイクル再開）に戻る選択肢を提示してください
```

Team未使用時は Task で `tdd-test-writer` に委譲する（フォールバック）。

### カテゴリB（リファクタリング）

**前提条件**: リファクタリングは「振る舞いを変えずに構造を変える」ものであり、**既存テストが安全網になっていることが必須**。安全網がない状態でのリファクタリングは「振る舞いの変化を見逃すパッチ修正」になる。

1. **カバレッジ確認**: 修正対象コードが既存テストでカバーされているか Read で確認
2. **不足していれば特性化テスト（Characterization Test）を先に追加**
   - 「現状の振る舞い」を記録するテストを書く
   - これは TDD の Red ではなく「現状を固定する」ためのテスト
   - `tdd-test-writer` に依頼してもよい:

```yaml
SendMessage:
  to: test-writer
  message: |
    ## 実行指示（特性化テスト）
    [ファイルパス] のリファクタリング前に、現状の振る舞いを記録する特性化テストを追加してください。
    新しい振る舞いを定義するのではなく、既存の振る舞いをそのままテストで固定することが目的です。
```

3. **既存テスト + 特性化テストが全て通る状態でリファクタリング開始**
4. Edit で修正
5. 全テストが通ることを確認（壊れたら振る舞いを変えている証拠 → カテゴリAへ昇格）

### カテゴリC（ドキュメント・スタイル）

1. Read → Edit で修正
2. テスト実行は不要（ただしビルドは確認）

## 共通: 修正後のセルフチェック＆コミット

> **実行層の制約（#52）**: 以下の `git commit` / `git push` および CI 待機の `gh` 呼び出しは、
> **`Bash` を保有する層（orchestrator / `implementation-lead`）が直接実行**する。カテゴリAの修正は
> `tdd-test-writer`（`Bash` 保有）に委譲してよいが、`app-reviewer` 等の no-Bash agent に commit/push を
> 委譲しない。事前許可は Phase 1 で検証済み（`Bash(git:*)` / `Bash(gh:*)`）。

全カテゴリの修正完了後:

1. Phase 12 の criticals リストの各項目について、指摘箇所の diff を確認
2. 修正が新たな問題を生んでいないか、周辺コードを Read で確認
3. ビルド確認（プロジェクトに応じたコマンド）
4. テスト実行（既存テスト + Phase 8 で追加したテスト + カテゴリAで追加したテスト）
5. コミット＆プッシュ:

```bash
# カテゴリAの場合、テストファイルと実装ファイルを同時にステージング
git add {修正ファイル} {追加したテストファイル}
git commit -m "fix: code review指摘対応

- [修正内容1]
- [修正内容2]

Refs: #[issue番号]"

git push
```

6. **CI結果を待機（必須）**: push 後は必ず CI の完了を待ってから次の Phase に進む

```bash
LATEST_SHA=$(git rev-parse HEAD)
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

# 最大20回（30秒 × 20 = 10分）ポーリング
for i in $(seq 1 20); do
  RESULT=$(gh api repos/$REPO/commits/$LATEST_SHA/check-runs \
    --jq '[.check_runs[] | .conclusion] | if length == 0 then "no_checks" elif all(. == "success") then "success" elif any(. == null) then "pending" elif any(. == "failure") then "failure" else "other" end')
  
  case "$RESULT" in
    "success") echo "CI passed"; break ;;
    "failure") echo "CI failed"; break ;;
    "no_checks") echo "No CI checks configured"; break ;;
    "pending") echo "CI running... ($i/20)"; sleep 30 ;;
  esac
done
```

| CI 結果 | アクション |
|---------|-----------|
| `success` | 次の Phase（15 or 18）へ進む |
| `failure` | CI失敗ログ（`gh run view [RUN_ID] --log-failed`）を取得して原因を修正 → 再コミット＆push → CI待機を再実行 |
| `no_checks` | CIが未設定のため次の Phase へ進む |
| 10分経過しても `pending` | タイムアウト報告して一時停止 |

## Phase 14 ↔ 18 ループ上限

Phase 18（最終レビュー）で再度修正が必要になった場合、Phase 14 に戻って修正を行う。
このループの上限・カウンタ名・比較演算子は **`${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/phase-flow.yaml` の `loops.codeReview` を正本とする**（数値をハードコードしない）。上限に達した場合はユーザーに状況を報告し、判断を委ねる。

### ループカウンターの管理

Phase 14 完了時に `reviewLoopCount`（カウンタ名は schema 参照）をインクリメントする。
上限値 `MAX` は実行時に `loops.codeReview.max` を読んで充てる:

```bash
# 1. 現在のカウントを読み取り（reviewLoopCount は state-schema.yaml 参照）
LOOP_COUNT=$(jq '.reviewLoopCount' .full-cycle-state.json)
NEW_COUNT=$((LOOP_COUNT + 1))

# 2. 上限チェック（MAX = loops.codeReview.max / operator も phase-flow.yaml 参照）
if [ "$NEW_COUNT" -ge "$MAX" ]; then
  echo "⚠️ レビューループが上限に達しました。ユーザーに報告します。"
  # terminalState を記録してから一時停止（自動再開しない / phase-flow.yaml resumeContract）:
  #   terminalState = { kind: "loop-exhausted", phase: 14,
  #                     reason: "code review loop reached loops.codeReview.max",
  #                     recordedAt: <ISO8601> }
fi

# 3. カウンターを更新（Write ツールで .full-cycle-state.json を更新）
# "reviewLoopCount": NEW_COUNT
```
