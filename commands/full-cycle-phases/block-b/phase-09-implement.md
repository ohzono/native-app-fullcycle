# Phase 9: 最終確認（implementation-lead）

⚠️ **Phase 9 は原則スキップ**。Phase 8 の `tdd-test-writer` が振る舞い一覧を全て消化し、テストが全て通っていれば、このフェーズは不要です。

Phase 9 を実行するのは「**Phase 8 でTDDしきれなかった部分**」がある場合のみ。ただし、その存在自体が **TDDの抜け道** になり得るため、以下の制約に従うこと。

## デフォルト: スキップ

以下の**全て**を満たす場合、Phase 9 はスキップする（**ほぼ全てのケースで該当する**）:
1. Phase 8 の出力レポートで未完了 TODO が 0 件
2. 全テストがパスしている
3. ビルドが通っている

判断はオーケストレーター（full-cycle-impl）が Phase 8 の出力を解析して行う。

## 例外的な実行ケース

Phase 9 を実行できるのは、以下の **いずれか** に該当する場合のみ:

| ケース | 例 | Phase 9 で行うこと |
|---|---|---|
| **テスト網羅できない外部結合** | OS権限ダイアログ、決済SDK、プッシュ通知の実機挙動 | 統合確認・手動検証スクリプトの整備（テストハーネスを書ける箇所はTDDに戻す） |
| **環境設定ファイル** | Info.plist、AndroidManifest、build.gradle の追加 | 最小変更を適用 |
| **DI登録の追加** | コンテナへの登録漏れ | 登録を追加（**ただしDI登録自体のテストを書くべき**） |

**禁止**: 「Phase 8 でテストを書きにくかった」を理由に Phase 9 でパッチ実装するのは禁止。それは設計の問題なので、Phase 8 に戻って `tdd-test-writer` に「テストの声を聴く」ループを回させること。

## 役割（実行時のみ）

- Phase 8 で対応不能だった外部結合・環境設定の最小変更
- アーキテクチャ整合性の最終確認
- 全テストの最終実行確認

> **iOS の SwiftUI / Swift Concurrency を含む変更の場合は、`mobiledev-fullcycle:swiftui-pro` skill を default で呼び出す**（CLAUDE.md の優先方針に準拠）。

**「Phase 8 で書きにくかった部分の代替実装」ではない**。書きにくい = 設計のシグナルなので、Phase 8 に差し戻すか、`tdd-test-writer` に「テストの声を聴く」レポートを出させて設計改善する。

## Bug fix 系 Issue の場合（baseline: root-cause analysis）

Issue が bug fix / 不具合対応系（タイトル/本文/label に `bug`/`fix`/`crash`/`flaky`/`regression`/`不具合`/`修正` を含む）の場合、Phase 8 / Phase 9 の実装に入る前に **`root-cause-analysis` skill を default で呼び出す**。

これは「enable する mode」ではなく **baseline**。「patch するなら理由を PR に残す」モデルに統一する。

### Phase 9 で確認すべき root-cause output

`root-cause-analysis` skill が以下を生成済みであることを確認する（Phase 8 で完了している前提）:

- **Root cause（最低3階層の Why）** または **棄却した仮説と調査範囲**
- **最小再現テスト**（修正前に Red、修正後に Green）
- **横展開（grep / Glob）の結果**: 同じ根本原因が他箇所にないか
- **修正方針の self-review**: root fix か patch か明示

確認できない場合は Phase 8 に差し戻し、`root-cause-analysis` を実行させる。

### Patch を選択した場合の PR description 必須項目

`root-cause-analysis` で patch を選んだ場合、Phase 11（PR作成）で以下を **PR description に必ず含めるよう implementer に指示**する:

```markdown
## Root cause
（特定できた真因。特定できなかった場合は調査範囲と棄却した仮説）

## Why patch instead of root fix
- [ ] 時間制約（リリース直前 等、具体的に）
- [ ] Scope 外（他チーム/他コンポーネント所管）
- [ ] 真因の修正コストが見積もり比 N 倍以上
- [ ] 真因不明だが本番影響が大きく一時止血が必要
- [ ] その他: ___

## Follow-up
- 起票した issue: #___  ← **必須**
- 期限の目安: ___
```

follow-up issue が無い patch PR は Phase 12（code-review）で `[BLOCKER]` が発火する。

### エスカレーション条件

`root-cause-analysis` の以下の条件に該当したら、Phase 9 を中断してユーザに相談:

- 真因の修正コストが見積もり比 **N=3** 倍以上（推奨デフォルト）→ context 投資の合意を取る
- 真因が他チーム/他コンポーネントにある → escalation 先の相談
- 真因不明 + 本番影響大 → 一時 patch + 詳細 incident report のフロー切替

N はチーム SLA に従う。デフォルト `N=3` を超えたら必ず escalation。

### 軽量バグの例外

真因が一目瞭然なケース（typo / 自明な null check 漏れ等）は、Why を 1行で済ませて良い。
判断基準: **修正前に「なぜ起きたか」を1文で説明できるか**。

## Team内メッセージ送信（推奨）

Implementation Team の `implementer` メンバーへ `SendMessage` します。
`test-writer` が残したテスト設計意図は Team コンテキスト（同じ Implementation Team 内）から自動参照されます。

**注意**: Phase 5 は Plan Team（別Team）で実行されるため、状態ファイルの `decisions.plan` / `decisions.spec` を読み込んで渡すこと。

```yaml
SendMessage:
  to: implementer
  message: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様概要: {状態ファイルの decisions.spec から読み込み}
    - 実装計画: {状態ファイルの decisions.plan から読み込み}
    - テスト設計意図は Team コンテキスト（Phase 8 の結果）を参照してください

    ## 実行指示
    Phase 8 の成果物を確認し、**外部結合・環境設定の最小変更のみ** 対応してください。

    ## 通すべきテスト
    {Phase 8で作成されたテストファイルパス一覧}

    ## テスト実行コマンド
    {Phase 8で出力されたテスト実行コマンド}

    ## 重要な制約
    - Phase 0で作成済みのworktreeで作業中です。新しいworktreeは作成しないでください。
    - **「テストが書きにくかった部分」のパッチ実装は禁止**。設計問題のシグナルなので Phase 8 に差し戻してください。
    - 対応可能なのは: 外部結合（実機SDK等）、環境設定ファイル、DI登録のみ。
    - DI登録を追加した場合は、登録自体のテストも書いてください。
    - 全テストがパスすることを最終確認してください。
```

## Task実行（フォールバック）

Team未使用時のフォールバック。状態ファイルから計画・仕様情報を読み込んで渡す必要があります。

```yaml
Task:
  description: 実装仕上げ
  subagent_type: mobiledev-fullcycle:implementation-lead
  prompt: |
    ## コンテキスト
    - Issue: #{issue番号}
    - 仕様概要: {状態ファイルの decisions.spec から読み込み}
    - 実装計画: {状態ファイルの decisions.plan から読み込み}

    ## 実行指示
    Phase 8 の成果物を確認し、**外部結合・環境設定の最小変更のみ** 対応してください。

    ## 通すべきテスト
    {Phase 8で作成されたテストファイルパス一覧}

    ## テスト実行コマンド
    {Phase 8で出力されたテスト実行コマンド}

    ## 重要な制約
    - Phase 0で作成済みのworktreeで作業中です。新しいworktreeは作成しないでください。
    - **「テストが書きにくかった部分」のパッチ実装は禁止**。設計問題のシグナルなので Phase 8 に差し戻してください。
    - 対応可能なのは: 外部結合（実機SDK等）、環境設定ファイル、DI登録のみ。
    - DI登録を追加した場合は、登録自体のテストも書いてください。
    - 全テストがパスすることを最終確認してください。
```

**確認項目**:
- [ ] 全テストがパスする
- [ ] 追加実装が「外部結合・環境設定・DI登録」のいずれかに該当する
- [ ] パッチ実装（テストなしの直接 Edit）を行っていない
- [ ] コードスタイル準拠
- [ ] セキュリティ考慮
- [ ] **bug fix の場合**: `root-cause-analysis` の output（真因・最小再現・横展開・修正方針）が揃っている
- [ ] **bug fix で patch 選択の場合**: PR description に `Root cause` / `Why patch instead of root fix` / `Follow-up`（issue 番号）が含まれる
