# Phase 13: PRにレビューコメント追加

## データソース

Phase 12 の結果は状態ファイルの以下のフィールドから取得する:

- **レビュー結果**: `decisions.reviewHistory` 配列の最新エントリ（`phase: 12` のもの）
  - `grade`: 総合評価 (A/B/C/D)
  - `criticals`: 必須修正のタイトル一覧
  - `shouldFix`: 推奨修正のタイトル一覧
  - `questions`: 確認質問一覧
- **規約チェック結果**: `decisions.guidelineCheck`（存在する場合のみ）
  - `rejectionRisk`: リジェクトリスク
  - `findings`: 指摘事項

## PRコメント投稿

```bash
gh pr review [PR番号] --comment --body "<details>
<summary>🤖 セルフレビュー結果（初回） — 総合評価: [grade]</summary>

## セルフレビュー結果（初回）

### 品質チェック
| 観点 | 評価 | コメント |
|------|------|----------|
| コード品質 | ✅/⚠️/❌ | [コメント] |
| アーキテクチャ | ✅/⚠️/❌ | [コメント] |
| セキュリティ | ✅/⚠️/❌ | [コメント] |
| パフォーマンス | ✅/⚠️/❌ | [コメント] |
| テスト品質 | ✅/⚠️/❌ | [コメント] |
| UX一貫性 | ✅/⚠️/❌ | [コメント] |

**総合評価**: [decisions.reviewHistory の最新エントリの grade]

### プラットフォーム規約チェック
[decisions.guidelineCheck が存在する場合:]
| 観点 | 評価 | コメント |
|------|------|----------|
| [観点名] | ✅/⚠️/❌ | [コメント] |

**リジェクトリスク**: [decisions.guidelineCheck.rejectionRisk]

[decisions.guidelineCheck が存在しない場合:]
対象外（プラットフォーム規約チェック未実施）

### Critical（必須修正）
[decisions.reviewHistory 最新エントリの criticals から転記。なければ「なし」]

### Should Fix（推奨修正）
[decisions.reviewHistory 最新エントリの shouldFix から転記。なければ「なし」]

### 確認質問
[decisions.reviewHistory 最新エントリの questions から転記。なければ「なし」]

</details>
"
```
