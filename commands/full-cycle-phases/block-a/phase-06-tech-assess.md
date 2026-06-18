# Phase 6: 技術意思決定

`feature-planner`の技術アセスメント機能を使用します。
Phase 5 と同じ Team メンバーを継続利用し、コンテキストを引き継ぎます。

## Team内メッセージ送信（推奨）

Phase 5 の結果は Team コンテキストから自動参照されるため、サマリーの転写は不要です。

```yaml
SendMessage:
  to: feature-planner
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - モード: 意思決定（decision）
    - 開発計画は Team コンテキスト（Phase 5 の結果）を参照してください

    ## 実行指示
    [MODE: decision]
    Issue #{issue番号} の開発計画について技術アセスメントを実施してください。

    以下を評価してください:
    - アーキテクチャ整合性（既存設計との整合、拡張性）
    - 技術リスク（未検証技術、依存関係の複雑さ）
    - 保守性（コードの可読性、テスト容易性）
    - パフォーマンス（想定負荷への対応能力）
    - セキュリティ（認証・認可、データ保護、通信暗号化）

    計画判定を以下いずれかで「判定:」行に出力してください:
    - ✅ 承認
    - ⚠️ 修正提案（修正点を具体的に記載）
    - ❌ 却下（理由を記載）
```

## Task実行（フォールバック）

Team未使用時は状態ファイルの `decisions` から Phase 5 の情報を読み込んで渡す。

```yaml
Task:
  description: 技術アセスメントを実施
  subagent_type: mobiledev-fullcycle:feature-planner
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - モード: 意思決定（decision）
    - 開発計画: {状態ファイルの decisions.plan から読み込み}

    ## 実行指示
    [MODE: decision]
    Issue #{issue番号} の開発計画について技術アセスメントを実施してください。

    以下を評価してください:
    - アーキテクチャ整合性（既存設計との整合、拡張性）
    - 技術リスク（未検証技術、依存関係の複雑さ）
    - 保守性（コードの可読性、テスト容易性）
    - パフォーマンス（想定負荷への対応能力）
    - セキュリティ（認証・認可、データ保護、通信暗号化）

    計画判定を以下いずれかで「判定:」行に出力してください:
    - ✅ 承認
    - ⚠️ 修正提案（修正点を具体的に記載）
    - ❌ 却下（理由を記載）
```

## 判定結果に応じた分岐処理

1. エージェント出力の「判定:」行を確認する
2. **❌ 却下の場合**:
   - `gh issue comment {issue番号}` で却下理由を記録する（本文は折りたたみ形式: `<details>` → `<summary>🤖 技術アセスメント却下 ⚠️ 要対応</summary>` → 空行 → `## 技術アセスメント却下` ＋判定理由 → 空行 → `</details>`）
   - `terminalState.kind=rejected`（phase: 6, reason, recordedAt）を記録
   - ユーザーに報告し、**フルサイクルをここで終了する**
3. **⚠️ 修正提案の場合**:
   - 修正点を反映して計画を更新
   - `techAssessLoopCount`（state-schema.yaml 参照）をインクリメントする
   - 再度技術アセスメントを実行（ループ上限・比較演算子は `${CLAUDE_PLUGIN_ROOT}/commands/full-cycle-phases/_schema/phase-flow.yaml` の `loops.techAssess` を正本とする。数値をハードコードしない）
   - 上限に達した場合は `terminalState.kind=loop-exhausted`（phase: 6）を記録し、ユーザーに判断を委ねる
4. **✅ 承認の場合**:
   - Phase 7 へ進む

## 状態ファイルへの書き込み

Phase 6 完了時に、技術アセスメント結果を状態ファイルに保存する:

```bash
# .full-cycle-state.json の decisions.techAssess を更新
# Write ツールで decisions.techAssess に構造化オブジェクトとして書き込む:
# "decisions": {
#   ...,
#   "techAssess": {
#     "verdict": "🟢承認 / 🟡修正提案 / 🔴却下",
#     "architecture": "✅ / ⚠️ / ❌ + コメント",
#     "risk": "✅ / ⚠️ / ❌ + コメント",
#     "maintainability": "✅ / ⚠️ / ❌ + コメント",
#     "performance": "✅ / ⚠️ / ❌ + コメント",
#     "security": "✅ / ⚠️ / ❌ + コメント",
#     "concerns": ["懸念事項（あれば）"]
#   }
# }
```

**重要**: Block B の Implementation Team は Plan Team のコンテキストを持たないため、ここで書き込む内容が実装フェーズの技術アセスメント判定の唯一の情報源になる。判定理由は省略せず記録すること。
