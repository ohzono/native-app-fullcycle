# Phase 2: 仕様チェック（spec-analyzer）

`spec-analyzer`エージェントを使用して仕様の穴や抜け漏れを検出します。

## 重複実行モード（Phase 0 先行起動）

Phase 0 で spec-analyzer を先行起動している場合は、以下の順で処理する:

1. 先行実行したTaskの結果が利用可能か確認
2. 利用可能ならその結果を Phase 2 の公式結果として採用（再実行しない）
3. 利用不可・失敗時のみ、下記のTaskを通常実行する

仕様ファイルパス指定時は、対象ファイルが `main` に存在することを確認すること。

## Team内メッセージ送信（推奨）

Plan Team の `spec-analyzer` メンバーへ `SendMessage` します。

```yaml
SendMessage:
  to: spec-analyzer
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様ファイル: {仕様ファイルパス}（ない場合はIssue本文を参照）

    ## 実行指示
    Issue #{issue番号} の仕様を分析してください。

    以下を実行してください:
    - 仕様の曖昧さ・矛盾・不足を検出
    - エッジケースの洗い出し
    - 技術的実現可能性の初期評価
    - **アクセシビリティ要件の確認**（後述）
    - 実装可否判定（🟢可 / 🟡条件付き可 / 🔴仕様確定待ち）

    ## アクセシビリティ要件チェック（UI変更がある場合）
    仕様にUI変更が含まれる場合、以下のアクセシビリティ要件が明示されているか確認:
    - VoiceOver/TalkBack でのナビゲーション可能性
    - Dynamic Type/フォントスケールへの対応
    - カラーコントラスト比（WCAG AA: 4.5:1 以上）
    - タッチターゲットサイズ（iOS: 44pt、Android: 48dp 以上）
    - 色だけに依存しない情報伝達（色覚多様性への配慮）
    仕様に記載がない場合は **warning として指摘** し、Phase 5 の計画に含めるよう推奨すること。
```

## Task実行（フォールバック）

```yaml
Task:
  description: 仕様チェックを実行
  subagent_type: mobiledev-fullcycle:spec-analyzer
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様ファイル: {仕様ファイルパス}（ない場合はIssue本文を参照）

    ## 実行指示
    Issue #{issue番号} の仕様を分析してください。

    以下を実行してください:
    - 仕様の曖昧さ・矛盾・不足を検出
    - エッジケースの洗い出し
    - 技術的実現可能性の初期評価
    - **アクセシビリティ要件の確認**（UI変更がある場合: VoiceOver/TalkBack、Dynamic Type、コントラスト比、タッチターゲット、色依存の有無）
    - 実装可否判定（🟢可 / 🟡条件付き可 / 🔴仕様確定待ち）
```

**出力**: 仕様レビューレポート（実装可否判定を含む）

## 状態ファイルへの書き込み

Phase 2 完了時に、分析結果のサマリーを状態ファイルに保存する（Taskフォールバック時の引き継ぎ用）:

```bash
# .full-cycle-state.json の decisions.spec を更新
# Write ツールで decisions.spec にオブジェクトとして書き込む:
# "decisions": {
#   "spec": {
#     "summary": "仕様の要約（2-3文）",
#     "verdict": "🟢可 / 🟡条件付き可 / 🔴仕様確定待ち",
#     "criticals": ["Critical問題のタイトル一覧（あれば）"],
#     "warnings": ["Warning問題のタイトル一覧（あれば）"],
#     "edgeCases": ["未定義のエッジケース一覧（あれば）"],
#     "requirements": {
#       "functional": ["機能要件の箇条書き"],
#       "nonFunctional": ["非機能要件の箇条書き"]
#     }
#   }
# }
```

**重要**: Block B の Implementation Team は Plan Team のコンテキストを持たないため、ここで書き込む内容が実装フェーズの唯一の仕様情報源になる。要件は省略せず記録すること。
