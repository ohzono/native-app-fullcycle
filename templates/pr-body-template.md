## What
<変更の概要: 何を実装/修正したか>

## Why
<変更の理由: なぜこの変更が必要か>
Closes #<Issue番号>

## How
- <変更点1>
- <変更点2>

<!--
================================================================================
Bug fix / 不具合対応の場合は、以下の「Root cause」セクションを必須で記入する。
新機能開発のみの場合は「Root cause」「Why patch instead of root fix」
「Follow-up」セクション全体を削除して構わない。
================================================================================
-->

## Root cause
<!-- bug fix の場合は必須。`root-cause-analysis` skill の output をそのまま貼る -->
<!-- 特定できた真因（最低3階層の Why）。特定できなかった場合は調査範囲と棄却した仮説を記載 -->

**Symptom**: <観測された現象>

**Why chain**:
- Why 1: <一次原因>
- Why 2: <二次原因>
- Why 3: <根本原因>

**Horizontal expansion**（同じ根本原因の他箇所探索）:
- 同PR で修正: <ファイル一覧 or なし>
- Follow-up issue: #<番号> or なし
- 影響なし（確認したパターン）: <内容>

**Fix strategy**: 以下のいずれかにチェック
- [ ] Root fix（真因を直接修正する）
- [ ] Patch / workaround（症状を抑制する → 下記 `Why patch instead of root fix` 必須）

## Why patch instead of root fix
<!-- Patch を選んだ場合のみ記入。Root fix の場合はこのセクション削除 OK -->
<!-- 最低1つチェックし、具体的な理由を併記 -->

- [ ] 時間制約（例: リリースまで X日、真因修正は Y日かかる）
- [ ] Scope外（他チーム/他コンポーネント所管 → 連携先: ___）
- [ ] 真因の修正コストが見積もり比 N倍以上（N=___）
- [ ] 真因不明だが本番影響が大きく一時止血が必要
- [ ] その他: ___

## Follow-up
<!-- Patch を選んだ場合のみ必須。Root fix の場合はこのセクション削除 OK -->

- 起票した issue: #___  ← **必須**（無い patch PR は code-review で `[BLOCKER]` が発火し merge gate になる）
- 期限の目安: <YYYY-MM-DD or リリース X+1>

## Testing
- [ ] ユニットテスト追加/更新
- [ ] 全テストパス確認
- [ ] **bug fix の場合**: 最小再現テストを追加し、修正前に Red、修正後に Green を確認
- <手動確認手順があれば記載>

## Screenshots
<!-- UI変更がある場合 -->
<!-- before/after比較を以下の形式で記載: -->
<!-- | 画面 | Before | After | -->
<!-- UI変更なしの場合: N/A -->

### VRTスナップショット差分
<!-- VRT実行済みの場合、変更されたスナップショットのbefore/after比較を記載 -->
<!-- 詳細な差分はPRコメント（gh pr comment）で投稿する -->

```bash
# 変更されたスナップショットの検出
git diff main --name-only -- '*.png' | grep -E '(__Snapshots__|snapshots)/'
```

| 画面 | Before | After |
|------|--------|-------|
| [画面名] | [before画像 or N/A（新規）] | [after画像] |

## Checklist
- [ ] コードレビュー準備完了
- [ ] テスト追加済み
- [ ] ドキュメント更新済み（該当する場合）
- [ ] 破壊的変更なし
- [ ] **bug fix の場合**: `Root cause` セクションを記入した
- [ ] **patch 選択の場合**: `Why patch instead of root fix` と `Follow-up` issue（必須）を記入した
- [ ] アンチパターン（例外握りつぶし / テスト無効化 / `workaround` `temporary` `hack` `TODO: fix later` コメント / root cause未特定の retry）を新規追加していない（追加した場合は理由を記載）
