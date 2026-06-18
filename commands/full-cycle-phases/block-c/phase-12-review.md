# Phase 12: コードレビュー（app-reviewer）+ プラットフォーム規約チェック

`app-reviewer`で自己レビューを実施します。同時に `guideline-checker` でプラットフォーム規約の準拠チェックも行います。

## 並行実行モード（Phase 15 + guideline-checker と同時）

**重要**: `currentPhase = 12` 開始時は、`code-reviewer`・`vrt-engineer`・`guideline-checker` への
`SendMessage` を**1メッセージで同時発行**すること。順次実行は禁止。

## 既存PRコメントの取得（送信前に実行）

SendMessage / Task を発行する前に、PR上に既に投稿されているコメント・レビュースレッドを取得し、レビュー指示に含める。Draft PR でも既に CI のAIレビュアー（CodeRabbit等）や人間レビュアーがコメントしている可能性があるため。

```bash
PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null)
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

if [ -n "$PR_NUMBER" ]; then
  gh pr view "$PR_NUMBER" --json comments \
    --jq '.comments[] | "[" + .author.login + "] " + .body'
  gh api repos/$REPO/pulls/$PR_NUMBER/reviews \
    --jq '.[] | select(.body != "") | "[" + .user.login + ":" + .state + "] " + .body'
  gh api repos/$REPO/pulls/$PR_NUMBER/comments \
    --jq '.[] | "[" + .user.login + "] " + .path + ":" + (.line|tostring) + " - " + .body'
fi
```

PR がまだ存在しない（Phase 11 でのDraft PR作成前）場合は当該手順をスキップしてよい。

## Team内メッセージ送信（推奨）

```yaml
SendMessage:
  to: code-reviewer
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 対象ブランチ: {Phase 0で作成したブランチ名}
    - スコープ: PR全変更

    ## 既存PRコメント（取得済み・存在する場合のみ）
    {上記スクリプトで取得したコメント・レビュー・行コメントを貼り付け}

    既存コメントがある場合、最新コミットで対応済みか分類し、未対応分は本レビューの指摘に含めてください。

    ## レビュアの構え（必須・出力には漏らさない）
    このレビューは Block B 実装の続きで走るため、自分側の成果物への迎合（sycophancy）が起きやすい。対象 diff を「別のエンジニアが提出した PR」として三人称で帰属させ、無条件に正しいとは仮定せず欠陥を能動的に探すこと。中立帰属をデフォルトとし、「junior」等の能力 prior は使わない。批判性はコードの欠陥に向け、表現は建設的に保つ。これは網羅性を上げる構えで、評価閾値は下げない（欠陥が nits のみなら A のまま）。
    **リークガード**: 出力（レポート / PR コメント / 確認質問）に作者帰属・人格言及（「別のエンジニアが書いた」「ジュニア」「junior」等）を含めないこと。詳細は `code-review` skill の「Phase 0」を参照。

    ## 実行指示
    Issue #{issue番号} のPR（全変更）に対してコードレビューを実施してください。

    以下の観点でレビューしてください:
    - コード品質（可読性、保守性、DRY原則）
    - アーキテクチャ整合性（既存設計との整合）
    - セキュリティ（OWASP Top 10、入力検証）
    - パフォーマンス（メモリ効率、不要な再計算）
    - テスト品質（網羅性、境界値カバレッジ、テストの保守性）
    - UX一貫性（既存UIとのスタイル・操作性の統一）

    各観点の評価を「✅ / ⚠️ / ❌」で出力してください。
```

## Task実行（フォールバック）

```yaml
Task:
  description: コードレビューを実施
  subagent_type: mobiledev-fullcycle:app-reviewer
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 対象ブランチ: {Phase 0で作成したブランチ名}
    - スコープ: PR全変更

    ## 既存PRコメント（取得済み・存在する場合のみ）
    {上記スクリプトで取得したコメント・レビュー・行コメントを貼り付け}

    既存コメントがある場合、最新コミットで対応済みか分類し、未対応分は本レビューの指摘に含めてください。

    ## レビュアの構え（必須・出力には漏らさない）
    このレビューは Block B 実装の続きで走るため、自分側の成果物への迎合（sycophancy）が起きやすい。対象 diff を「別のエンジニアが提出した PR」として三人称で帰属させ、無条件に正しいとは仮定せず欠陥を能動的に探すこと。中立帰属をデフォルトとし、「junior」等の能力 prior は使わない。批判性はコードの欠陥に向け、表現は建設的に保つ。これは網羅性を上げる構えで、評価閾値は下げない（欠陥が nits のみなら A のまま）。
    **リークガード**: 出力（レポート / PR コメント / 確認質問）に作者帰属・人格言及（「別のエンジニアが書いた」「ジュニア」「junior」等）を含めないこと。詳細は `code-review` skill の「Phase 0」を参照。

    ## 実行指示
    Issue #{issue番号} のPR（全変更）に対してコードレビューを実施してください。

    以下の観点でレビューしてください:
    - コード品質（可読性、保守性、DRY原則）
    - アーキテクチャ整合性（既存設計との整合）
    - セキュリティ（OWASP Top 10、入力検証）
    - パフォーマンス（メモリ効率、不要な再計算）
    - テスト品質（網羅性、境界値カバレッジ、テストの保守性）
    - UX一貫性（既存UIとのスタイル・操作性の統一）

    各観点の評価を「✅ / ⚠️ / ❌」で出力してください。
```

## グレード判定基準

| 評価 | 基準 |
|------|------|
| **A** | 指摘なし。マージ可能 |
| **B** | shouldFix のみ（Critical なし）。修正後マージ可能 |
| **C** | Critical が1件以上。修正必須 |
| **D** | 根本的な設計見直しが必要。実装の大部分をやり直す必要がある |

この基準で総合評価を判定し、`decisions.codeReview.grade` に記録すること。

> **iOS の SwiftUI / Swift Concurrency を含む変更の場合は、`mobiledev-fullcycle:swiftui-pro` skill を default で呼び出す**（CLAUDE.md の優先方針に準拠）。

**出力**: コードレビューレポート

## プラットフォーム規約チェック（guideline-checker・並行実行）

コードレビューと同時に、プラットフォーム規約（App Store Review Guidelines / Google Play Developer Policy）への準拠をチェックする。リジェクトリスクは早期に検出すべきため、レビューフェーズの最初に並行実行する。

### Team内メッセージ送信（推奨）

```yaml
SendMessage:
  to: guideline-checker
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 対象ブランチ: {Phase 0で作成したブランチ名}
    - スコープ: PR全変更

    ## 実行指示
    Issue #{issue番号} の変更に対して、プラットフォーム規約の準拠チェックを実施してください。

    以下の観点でチェック:
    - **App Store Review Guidelines**（iOS対象の場合）
      - プライバシー（データ収集・利用目的の明示、ATT対応）
      - セキュリティ（キーチェーン使用、暗号化）
      - コンテンツ（不適切コンテンツのフィルタリング）
      - 課金（StoreKit使用、外部決済への誘導禁止）
      - パフォーマンス（クラッシュ、電池消費）
    - **Google Play Developer Policy**（Android対象の場合）
      - プライバシー（パーミッション最小化、データセーフティ）
      - セキュリティ（WebView設定、intent-filter）
      - 課金（Google Play Billing Library使用）
      - コンテンツ（年齢別レーティング）
      - ターゲットAPI対応（targetSdkVersion要件）

    ## 出力要件
    | 観点 | 評価 | コメント |
    |------|------|----------|
    | [観点名] | ✅/⚠️/❌ | [詳細] |

    **リジェクトリスク**: 高/中/低/なし
    **必須対応**: [リジェクトに直結する問題があれば記載]
```

### Task実行（フォールバック）

```yaml
Task:
  description: プラットフォーム規約チェック
  subagent_type: mobiledev-fullcycle:guideline-checker
  prompt: |
    （SendMessageと同内容）
```

### 結果の取り扱い

| リジェクトリスク | アクション |
|----------------|-----------|
| **高** | Phase 14 の Critical として修正必須 |
| **中** | Phase 14 の shouldFix として修正推奨 |
| **低/なし** | 記録のみ（Phase 13 の PRコメントに含める） |

## 状態ファイルへの書き込み

Phase 12 完了時に、レビュー結果を状態ファイルに保存する:

```bash
# .full-cycle-state.json の decisions.reviewHistory 配列に追記する:
# "decisions": {
#   ...,
#   "reviewHistory": [
#     {
#       "phase": 12,
#       "round": 1,
#       "type": "code-review",
#       "grade": "A / B / C / D",
#       "criticals": ["必須修正のタイトル一覧（あれば）"],
#       "shouldFix": ["推奨修正のタイトル一覧（あれば）"],
#       "questions": ["作成者への確認質問（あれば）"]
#     }
#   ],
#   "guidelineCheck": {
#     "rejectionRisk": "高/中/低/なし",
#     "findings": ["指摘1", "指摘2"],
#     "platform": "ios / android / both"
#   }
# }
```

**重要**:
- `reviewHistory` は配列。上書きではなく**追記**すること。Phase 14→18 のループで複数回のレビュー結果が蓄積される
- Phase 14（修正対応）と Phase 18（最終レビュー）は同一 Review Team 内で実行されるため Team コンテキストから参照可能だが、Task フォールバック時には state file が唯一の情報源になる。指摘内容は省略せず記録すること
- `guidelineCheck` は規約チェック結果。リジェクトリスクが高/中の場合は Phase 14 の修正対象に含める
