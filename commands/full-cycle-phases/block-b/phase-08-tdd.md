# Phase 8: TDDサイクル（tdd-test-writer）

`tdd-test-writer`エージェントでTDDサイクル（Red → Green → Refactor）を1テストずつ回して機能を段階的に実装します。

## Phase 8 と Phase 9 の役割分担

- **Phase 8（tdd-test-writer）**: TDDサイクルの主担当。1テストずつ Red → Green → Refactor を繰り返し、機能を段階的に実装する。テスト設計と実装の両方を担う。**ほぼ全てのケースで Phase 8 だけで完結する**。
- **Phase 9（implementation-lead）**: 原則スキップ。例外的に必要な場合のみ「外部結合・環境設定・DI登録」の最小変更を行う。「Phase 8 でテストが書きにくかった部分の代替実装」ではない（書きにくい = 設計シグナル）。

## TDDの対象範囲（レイヤ別）

Phase 8 でTDDサイクルを回す対象範囲を明確化する。「TDDできない」と早合点せず、レイヤごとに適切な保護方法を選ぶこと。

| レイヤ | TDD対象 | テスト種別 | 備考 |
|-------|--------|-----------|------|
| **Domain / Entity / Value Object** | ✅ 必須 | 単体テスト | 純粋関数なのでTDDが最も自然。最初に着手すべき |
| **UseCase / Interactor** | ✅ 必須 | 単体テスト（モック使用最小限） | ビジネスロジックの中核 |
| **ViewModel / Reducer / Presenter** | ✅ 必須 | 単体テスト | 状態遷移をTDDで検証 |
| **Repository実装（DB/API）** | ✅ 推奨 | 統合テスト or 契約テスト | 境界はテストで守る |
| **View（SwiftUI/Compose）** | ⚠️ 部分的 | 状態遷移はTDD、見た目は VRT（Phase 15） | 「ViewはTDDできない」は誤解 |
| **DI登録 / コンテナ設定** | ✅ 推奨 | 解決テスト（resolveできることをテスト） | Phase 9 で追加した場合もテスト必須 |
| **マイグレーション / DBスキーマ** | ✅ 推奨 | 統合テスト（前後のスキーマで動作確認） | 「テストできない」と諦めない |
| **外部SDK（決済・プッシュ等）** | ⚠️ 抽象化境界をTDD | アダプタをモック化してTDD、実機部分は Phase 9 | 抽象化レイヤは必ずTDDで保護 |

**原則**: 「TDDできない」と判断する前に、**抽象化境界（Seam, Humble Object）を作ってTDD可能な部分を切り出す** ことを試みる。それでも残る部分のみ Phase 9 で対応する。

## Team内メッセージ送信（推奨）

Implementation Team の `test-writer` メンバーへ `SendMessage` します。

**注意**: Phase 2/5 は Plan Team（別Team）で実行されるため、Implementation Team のコンテキストには含まれない。
状態ファイルの `decisions.spec` / `decisions.plan` を読み込んで SendMessage に明示的に渡すこと。

```yaml
SendMessage:
  to: test-writer
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様概要: {状態ファイルの decisions.spec から読み込み}
    - 実装計画: {状態ファイルの decisions.plan から読み込み}

    ## 実行指示
    Issue #{issue番号} の仕様に基づいてTDDサイクル（Red → Green → Refactor）を回してください。

    以下を実施してください:
    - 仕様からTODOリストを作成
    - 1テストずつ Red → Green → Refactor のサイクルを繰り返す
    - 各サイクルでテストが通ることを確認しながら段階的に実装
    - テストの声を聴き、設計上の問題があれば改善

    **重要**: テストをまとめて書いてから実装するのではなく、1テストずつサイクルを回してください。

    ## 出力要件
    出力に以下を必ず含めてください:
    - TODOリストと完了状況
    - 各サイクルの実行ログ（Red/Green/Refactorの内容）
    - 作成したテストファイルと実装ファイルのパス一覧
    - テスト実行コマンド
    - 最終テスト実行結果
```

## Task実行（フォールバック）

Team未使用時のフォールバック。状態ファイルから仕様・計画情報を読み込んで渡す必要があります。

```yaml
Task:
  description: TDDサイクルで機能を実装
  subagent_type: mobiledev-fullcycle:tdd-test-writer
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様概要: {状態ファイルの decisions.spec から読み込み}
    - 実装計画: {状態ファイルの decisions.plan から読み込み}

    ## 実行指示
    Issue #{issue番号} の仕様に基づいてTDDサイクル（Red → Green → Refactor）を回してください。

    以下を実施してください:
    - 仕様からTODOリストを作成
    - 1テストずつ Red → Green → Refactor のサイクルを繰り返す
    - 各サイクルでテストが通ることを確認しながら段階的に実装
    - テストの声を聴き、設計上の問題があれば改善

    **重要**: テストをまとめて書いてから実装するのではなく、1テストずつサイクルを回してください。

    ## 出力要件
    出力に以下を必ず含めてください:
    - TODOリストと完了状況
    - 各サイクルの実行ログ（Red/Green/Refactorの内容）
    - 作成したテストファイルと実装ファイルのパス一覧
    - テスト実行コマンド
    - 最終テスト実行結果
```

**出力**:
- TDDサイクルで段階的に実装されたコードとテスト
- TDDサイクル レポート（TODOリスト、サイクルログ、ファイルパス一覧）
