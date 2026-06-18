# Phase 3: PM + UX 意思決定

## 実行モード（必須）

**重要**: Plan Team 内の `feature-planner` と `design-reviewer` に対する
以下2つの `SendMessage` は、**必ず1つのメッセージで同時発行**すること。  
順次実行は禁止。
## 3.1 feature-planner（意思決定モード）

ビジネス価値評価とGo/No-Go判定を実施します。

```yaml
SendMessage:
  to: feature-planner
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - モード: 意思決定（decision）
    - 仕様分析は Team コンテキスト（Phase 2 の結果）を参照してください

    ## 実行指示
    [MODE: decision]
    Issue #{issue番号} の機能について意思決定モードで評価してください。

    以下を実施してください:
    - ビジネス価値評価（ユーザー価値、ビジネスインパクト、実現可能性、戦略的整合性）
    - Go/No-Go判定（🟢Go / 🟡条件付きGo / 🔴No-Go）
    判定結果を「判定:」行で必ず出力してください。
```

## 3.2 design-reviewer（意思決定モード）

UX観点での設計判断を実施します。

```yaml
SendMessage:
  to: design-reviewer
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - モード: 意思決定（decision）
    - 仕様分析は Team コンテキスト（Phase 2 の結果）を参照してください

    ## 実行指示
    [MODE: decision]
    Issue #{issue番号} の仕様に対してUX観点の意思決定を行ってください。

    以下を実施してください:
    - 設計判定（🟢承認 / 🟡修正提案 / 🔴却下）
    - 既存UIとの一貫性チェック
    - 代替案提示（修正提案の場合）
    判定結果を「判定:」行で必ず出力してください。
```

## Task実行（フォールバック）

Team未使用時は状態ファイルの `decisions.spec` から Phase 2 の情報を読み込んで渡す。

### 3.1 feature-planner（Task）

```yaml
Task:
  description: ビジネス価値評価とGo/No-Go判定
  subagent_type: mobiledev-fullcycle:feature-planner
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - モード: 意思決定（decision）
    - 仕様分析結果: {状態ファイルの decisions.spec から読み込み}

    ## 実行指示
    [MODE: decision]
    Issue #{issue番号} の機能について意思決定モードで評価してください。

    以下を実施してください:
    - ビジネス価値評価（ユーザー価値、ビジネスインパクト、実現可能性、戦略的整合性）
    - Go/No-Go判定（🟢Go / 🟡条件付きGo / 🔴No-Go）
    判定結果を「判定:」行で必ず出力してください。
```

### 3.2 design-reviewer（Task）

```yaml
Task:
  description: UX観点での設計判断
  subagent_type: mobiledev-fullcycle:design-reviewer
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - モード: 意思決定（decision）
    - 仕様分析結果: {状態ファイルの decisions.spec から読み込み}

    ## 実行指示
    [MODE: decision]
    Issue #{issue番号} の仕様に対してUX観点の意思決定を行ってください。

    以下を実施してください:
    - 設計判定（🟢承認 / 🟡修正提案 / 🔴却下）
    - 既存UIとの一貫性チェック
    - 代替案提示（修正提案の場合）
    判定結果を「判定:」行で必ず出力してください。
```

**注意**: 2つの Task は**並行実行**すること（1メッセージで同時発行）。

## 判定結果に応じた分岐処理

1. 並行起動した2つのメッセージ処理の完了を待つ
2. 両エージェントの出力から「判定:」行を確認する
3. **いずれかが🔴却下の場合**:
   - `gh issue comment {issue番号}` で却下理由を記録する（本文は折りたたみ形式: `<details>` → `<summary>🤖 No-Go / 却下判定 ⚠️ 要対応</summary>` → 空行 → `## No-Go / 却下判定` ＋判定理由 → 空行 → `</details>`。summary だけ常時表示され本文は折りたたまれる）
   - 状態ファイルに `terminalState.kind=no-go`（phase: 3, reason, recordedAt）を記録する（#29: 再開時の無確認再走を防ぐ）
   - ユーザーに「判定の結果、開発を中止します」と報告
   - **フルサイクルをここで終了する（以降のPhaseは実行しない）**
4. **いずれかが🟡修正提案の場合**:
   - `gh issue comment {issue番号}` で修正事項を記録する（本文は折りたたみ形式: `<details>` → `<summary>🤖 修正提案</summary>` → 空行 → `## 修正提案` ＋修正事項 → 空行 → `</details>`）
   - 修正提案の内容を反映して Phase 4 へ進む
5. **すべて🟢承認の場合**:
   - Phase 4 へ進む

## 状態ファイルへの書き込み

Phase 3 完了時に、PM/UX判定結果を状態ファイルに保存する:

```bash
# .full-cycle-state.json の decisions.pmUx を更新
# Write ツールで decisions.pmUx に構造化オブジェクトとして書き込む:
# "decisions": {
#   ...,
#   "pmUx": {
#     "pm": {
#       "verdict": "🟢Go / 🟡条件付きGo / 🔴No-Go",
#       "businessValue": "ビジネス価値評価のサマリー",
#       "conditions": ["条件付きGoの場合の条件（あれば）"]
#     },
#     "ux": {
#       "verdict": "🟢承認 / 🟡修正提案 / 🔴却下",
#       "feedback": "UX判定の詳細",
#       "alternatives": ["代替案（修正提案の場合）"]
#     }
#   }
# }
```

**重要**: Block B の Implementation Team は Plan Team のコンテキストを持たないため、ここで書き込む内容が実装フェーズのPM/UX判定の唯一の情報源になる。判定理由は省略せず記録すること。
