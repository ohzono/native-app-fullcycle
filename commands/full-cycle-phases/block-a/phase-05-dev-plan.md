# Phase 5: 開発計画（feature-planner）

`feature-planner`を使用して **TDDを駆動するための計画** を作成します。

## ⚠️ 設計駆動性を殺さないための制約

Phase 5 は **詳細設計を行わない** こと。クラス図・メソッドシグネチャ・データ構造の確定はTDDの過程（Phase 8）で発見されるべきものであり、ここで決め打ちすると `tdd-test-writer` が「計画通りに実装するためのテスト」を書くだけになり、テストの声を聴く余地が失われる。

Phase 5 の出力は以下に制限する:

| ✅ 含めるもの | ❌ 含めないもの |
|---|---|
| **振る舞い一覧（TODOリスト）** — 仕様から導出される振る舞いの箇条書き | クラス名・メソッド名・シグネチャ |
| **アーキテクチャ層の決定**（UI/Domain/Data など、既存パターンに沿った大枠） | データ構造・DBスキーマの詳細 |
| **テスト戦略の方針**（どのレイヤを単体テスト/統合テスト/VRT で保護するか） | テストケースの具体的な内容（Phase 8 で決まる） |
| **アクセシビリティ要件**（VoiceOver/TalkBack、Dynamic Type、コントラスト等） | 関数の内部ロジック・分岐の詳細 |
| **技術選定**（ライブラリ・SDK の採否） | 工数見積もり（フェーズ分割の数字） |
| **リスク・前提条件** | — |

**指針**: 「Phase 8 の `tdd-test-writer` が **TODOリストの先頭から1つずつ Red→Green→Refactor を回して発見していく**」という前提で計画を組む。

## Team内メッセージ送信（推奨）

Phase 2/3 の結果は Team コンテキストから自動参照されるため、サマリーの転写は不要です。

```yaml
SendMessage:
  to: feature-planner
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様分析・PM/UX判定は Team コンテキスト（Phase 2/3 の結果）を参照してください
    - 修正事項: {Phase 3 で修正提案があれば記載、なければ省略}

    ## 実行指示
    Issue #{issue番号} の機能について **TDDを駆動するための計画** を作成してください。

    以下を実施してください:
    - 要件分析（機能要件・非機能要件）
    - **振る舞い一覧（TODOリスト）の作成** — Phase 8 の tdd-test-writer がそのまま使える形式
    - 技術選定（推奨スタックと代替案）
    - テスト戦略（**どのレイヤを単体テスト/統合テスト/VRTで保護するか**）
    - **アクセシビリティ要件**（UI変更がある場合: VoiceOver/TalkBack対応、Dynamic Type、コントラスト比、タッチターゲットサイズ）
    - アーキテクチャ層の大枠（既存パターンに沿った層構成）
    - リスク評価

    ## 重要な制約（詳細設計の禁止）
    以下は出力に含めないでください。これらは Phase 8 の TDD サイクルで発見されるべき:
    - クラス名・メソッド名・シグネチャ
    - データ構造・DBスキーマの詳細
    - テストケースの具体的な内容
    - 関数の内部ロジック・分岐の詳細
```

## Task実行（フォールバック）

Team未使用時は状態ファイルの `decisions` から Phase 2/3 の情報を読み込んで渡す。

```yaml
Task:
  description: TDD駆動のための計画を作成
  subagent_type: mobiledev-fullcycle:feature-planner
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様概要: {状態ファイルの decisions.spec から読み込み}
    - PM/UX判定: {状態ファイルの decisions.pmUx から読み込み}
    - 修正事項: {あれば記載}

    ## 実行指示
    Issue #{issue番号} について **TDDを駆動するための計画** を作成してください。

    以下を実施してください:
    - 振る舞い一覧（TODOリスト）の作成
    - 技術選定（推奨スタックと代替案）
    - テスト戦略（どのレイヤを単体テスト/統合テスト/VRTで保護するか）
    - アクセシビリティ要件（UI変更がある場合）
    - アーキテクチャ層の大枠
    - リスク評価

    ## 重要な制約（詳細設計の禁止）
    以下は出力に含めないでください:
    - クラス名・メソッド名・シグネチャ
    - データ構造・DBスキーマの詳細
    - テストケースの具体的な内容
    - 関数の内部ロジック・分岐の詳細
```

**出力**: 実装計画書

## 状態ファイルへの書き込み

Phase 5 完了時に、実装計画のサマリーを状態ファイルに保存する:

```bash
# .full-cycle-state.json の decisions.plan を更新
# Write ツールで decisions.plan にオブジェクトとして書き込む:
# "decisions": {
#   ...,
#   "plan": {
#     "summary": "計画の要約（2-3文）",
#     "techStack": "選定した技術スタック",
#     "todoList": [
#       "振る舞い1: ○○すると××できる",
#       "振る舞い2: △△の場合は□□になる",
#       "振る舞い3: ..."
#     ],
#     "architectureLayers": ["UI", "Domain", "Data"],
#     "testStrategy": {
#       "unit": "ViewModel/UseCase/Domain を保護",
#       "integration": "Repository実装を契約テストで保護",
#       "vrt": "View（SwiftUI/Compose）を保護（UI変更がある場合）"
#     },
#     "accessibility": {
#       "required": true/false,
#       "requirements": ["VoiceOver/TalkBack対応", "Dynamic Type", "コントラスト比 4.5:1以上"]
#     },
#     "risks": ["リスク項目（あれば）"]
#   }
# }
```

**重要**: Block B の Implementation Team は Plan Team のコンテキストを持たないため、ここで書き込む内容がTDD・実装フェーズの唯一の計画情報源になる。**振る舞い一覧（todoList）は省略せず記録すること**。Phase 8 の `tdd-test-writer` は todoList の先頭から1つずつ Red→Green→Refactor を回し、必要に応じて新しい振る舞いを追加していく。
