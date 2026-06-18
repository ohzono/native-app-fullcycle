---
name: code-review
description: コードレビューを実施します（考慮漏れ検出強化版）。質問駆動レビュー、不在の検出、PRコメント投稿まで一気通貫で実行。プルリクエストのレビュー、コード監査、コード変更へのフィードバック提供時に使用します。
model: opus
allowed-tools: Read, Glob, Grep, WebSearch, Bash(gh pr review *), Bash(gh pr view *), Bash(gh pr diff *)
user-invocable: true
argument-hint: "[ファイルパス or PR番号]"
---

# コードレビュー（考慮漏れ検出強化版）

指定されたコード「$ARGUMENTS」に対して、**考慮漏れを徹底的に検出する**包括的コードレビューを実施します。

**Bug fix PR の場合**: [[root-cause-analysis]] の output（Root cause / 最小再現テスト / 横展開 / Fix strategy）が PR description に含まれているかも MUST 確認します。patch 選択時の follow-up issue 起票チェックとアンチパターン（例外握りつぶし / テスト無効化 / workaround コメント / root cause 未特定の retry）の自動検出も baseline で実施します。

**iOS の SwiftUI / Swift Concurrency を含む変更の場合は、`mobiledev-fullcycle:swiftui-pro` skill を default で呼び出します**（CLAUDE.md の優先方針に準拠）。modern API・保守性・パフォーマンスの観点を本レビューに統合します。

## 引数について

- **$ARGUMENTS**: レビュー対象の指定
  - **ファイルパス指定**: 該当ファイルを直接レビュー
  - **PR番号指定** (例: `#123`): `gh pr diff` で変更内容を取得してレビュー
  - **指定なし**: `git diff` で現在の未コミット変更をレビュー
  - **ディレクトリ指定**: 配下の全ファイルを対象にレビュー

---

## Phase 0: レビュアの構え（帰属フレーミングによる sycophancy 抑制）

> **このフェーズは出力を生成しない。** Phase 1 以降のレビューに入る前に、レビュア自身の**内部の構え（framing）**を整えるためのもの。

### なぜ構えを整えるのか

フルサイクル開発では実装（Block B）→ レビュー（Block C）が同一プラグイン内で連続して走る。レビューが別 context で実行されても、LLM レビュアには「自分側のフロー／自分が関与した成果物」に**迎合（sycophancy）して評価を甘くする**傾向がある。結果として `A` 評価の安売りや `LGTM` 寄りの判定が起きやすい。

公知の報告によれば、この迎合は**プロンプトの文法的人称（grammatical person）**に強く依存し、**一人称 → 三人称**（評価対象を第三者の成果物として帰属させる）に切り替えるだけで迎合が大きく低下するとされる（[Self-Blinding and Counterfactual Self-Simulation Mitigate Biases and Sycophancy in LLMs](https://arxiv.org/pdf/2601.14553) / [Interaction Context Often Increases Sycophancy in LLMs](https://arxiv.org/pdf/2509.12517) による）。また RLHF が迎合を強め、ユーザーの信念への同意が高評価の予測因子になるという Sharma et al.（Anthropic）の知見もある（[AI Sycophancy — IEEE Spectrum](https://spectrum.ieee.org/ai-sycophancy) による）。コードレビュー等の客観判断プロンプトに anti-sycophancy 句を入れる有用性も実務側から報告されている（[Crash Override](https://crashoverride.com/blog/prompting-llm-security-reviews/) / [Sparkco](https://sparkco.ai/blog/reducing-llm-sycophancy-69-improvement-strategies) による。いずれも一次論文未読のため断定はせず、出典に帰属させて記す）。

### 構え（この diff を「第三者が提出した PR」として扱う）

レビュー対象の diff を「自分側の成果物」ではなく、**別のエンジニアが提出した PR** として帰属させて読む。

- **無条件に正しいとは仮定しない。** 「動いているはず」「意図通りのはず」を前提にせず、欠陥を**能動的に探す**。
- 人称を一人称（"自分が書いた変更"）から三人称（"提出された変更"）に切り替えて読む。これだけで「自分への忖度」が外れる。
- 批判性は **コードの欠陥** に向ける。レビュアの態度（表現）を harsh にするためのものではない。後述のドメイン知識 §1「Be Kind and Constructive」/ §2「Focus on the Code, Not the Person」と必ず両立させる。

### キャリブレーション方針（中立帰属をデフォルトにする理由）

帰属表現として「**junior（ジュニア）が書いた PR をシニアがレビューする**」という能力 prior 付きの言い回しも検討したが、**既定では使わず、中立的な三人称（「別のエンジニアが提出した PR」）をデフォルト**とする。理由:

1. 公知の研究が裏付けるのは**人称の切替（一人称→三人称）**であって、「相手は能力が低い」という能力 prior ではない。junior 表現は研究の射程外の追加仮定。
2. 能力 prior は**過剰な nitpick / 上から目線 / スタイル偽陽性（false positive）**を招きやすく、本 skill が既に持つ質問駆動レビュー・アンチパターン検出と**相補**になるどころか FP を増やすリスクがある。
3. 「junior が書いた」という人格帰属は、後述のリークガード（出力に作者帰属を漏らさない）と緊張し、実在の作者を侮辱する事故の温床になる。

「junior」フレーミングは**キャリブレーションのダイヤル**として残す（迎合がどうしても抜けない特定プロジェクトで明示的に試す余地）が、既定の構えは中立帰属とする。

### リークガード（最重要・出力に作者帰属を漏らさない）

帰属フレーミングは**レビュアの内部の構え限定**であり、**いかなる出力にも漏らしてはならない**:

- PR コメント（`gh pr review`）・レビュー本文・確認質問・サマリーに、「別のエンジニアが書いた」「ジュニア」「junior」等の**作者帰属・人格言及を含めない**。実在の作者を侮辱しうるため。
- 出力に現れてよいのは **コードに対する指摘**（ファイルパス・行番号・問題・修正案）のみ。「誰が書いたか」は出力の関心事ではない。
- このガードは静的 grep（後述）で回帰チェックするが、本質はこの指示そのものである。自由記述で "this looks like junior code" 等を**書かない**こと。
- **スコープ**: このガードが禁じるのは「diff の**作者帰属**」（実在の作者が誰か）であり、Phase 4.6 の保守性シミュレーション（"新人エンジニアがこのコードを保守したら？" という**仮想の保守者視点**の設問）は対象外。後者はコードの可読性・意図の伝わりやすさを問う正当な指摘であり、抑制しない。回帰 grep を組む場合も `新人` 等の保守性設問由来の語は対象に含めない。

### 評価への効き方（網羅性を上げる。閾値は下げない）

この構えは「欠陥の見落としを減らす（網羅性を上げる）」ためのものであり、**評価を機械的に厳しくするものではない**。

- 評価（A/B/C/D）は **実在する欠陥の深刻度** にマップする（後述「レビュー基準」のまま）。
- 「能動的に探した結果 nits（軽微な指摘）しか無い」PR は **A のまま**。欠陥を探す姿勢と、見つかった欠陥の重み付けは別物。
- 目的は `A` 評価の安売り防止であって、全 PR を B に引き下げることではない。

---

## Phase 1: 対象コードの特定と文脈理解

### 1.1 コード取得
- ファイルパスが指定された場合: 該当ファイルを直接読み込み
- PR番号が指定された場合: `gh pr diff` で変更内容を取得
- 指定なしの場合: `git diff` で現在の変更を確認

### 1.2 文脈調査（MUST）
変更コードをレビューする前に、必ず以下を確認：
- **PR/コミットの説明文**: 何を達成しようとしているか
- **関連Issue**: 要件や背景
- **変更ファイルの周辺コード**: 既存の実装パターンとの整合性

---

## Phase 2: 考慮漏れ検出のための質問駆動レビュー

> **レビューの核心**: 「このコードは〜を考慮しているか？」という質問を系統的に投げかける

### 2.1 境界条件・エッジケースの質問（Chain-of-Thought）

各入力パラメータに対して、順番に検証：

```
Step 1: 入力が null/undefined/nil の場合はどうなる？
Step 2: 入力が空（空文字列、空配列、空辞書）の場合は？
Step 3: 入力が最大値/最小値の場合は？
Step 4: 入力が不正な型の場合は？
Step 5: 入力が境界値（0, -1, MAX_INT, MIN_INT）の場合は？
Step 6: 入力に特殊文字（改行、タブ、Unicode、絵文字）が含まれる場合は？
```

### 2.2 状態・タイミングの質問

```
Q1: この処理が並行実行された場合、競合状態は発生しないか？
Q2: この処理が途中で失敗した場合、中間状態はどうなるか？
Q3: この処理が複数回呼ばれた場合、冪等性は保たれるか？
Q4: この処理のタイムアウトは考慮されているか？
Q5: 外部サービス/DBが応答しない場合は？
Q6: ネットワーク接続が途切れた場合は？
```

### 2.3 セキュリティの質問

```
Q1: ユーザー入力が直接使われていないか？（SQLインジェクション、XSS、コマンドインジェクション）
Q2: 認証・認可チェックは適切に行われているか？
Q3: 機密情報がログに出力されていないか？
Q4: エラーメッセージに内部情報が漏洩していないか？
Q5: 外部からのデータは検証されているか？
Q6: ファイルパスに..やシンボリックリンクの攻撃は防がれているか？
```

### 2.4 暗黙の仕様・期待の質問

```
Q1: この機能の「当たり前」の動作は実装されているか？
    - リストの並び順は？（作成日順？更新日順？）
    - 削除後のリダイレクト先は？
    - エラー時のユーザーへのフィードバックは？

Q2: 関連機能への影響は考慮されているか？
    - この変更で既存機能が壊れないか？
    - キャッシュの無効化は必要か？
    - 検索インデックスの更新は必要か？

Q3: ユーザー体験として不足している点は？
    - ローディング表示は？
    - 処理中の再クリック防止は？
    - 成功/失敗のフィードバックは？
```

### 2.5 UX一貫性の質問（B評価頻出パターン #1）

> **本質**: 新機能を書くとき、既存UIとの横断的な一貫性を見落としやすい

```
Q1: 既存の類似ボタン・操作と sensoryFeedback / haptics は揃っているか？
Q2: 全てのインタラクティブ要素に accessibilityLabel / accessibilityHint が付いているか？
Q3: 関連する全UIに同じ disabled 条件が適用されているか？
Q4: 既存の類似コンポーネントとスタイル（フォント・色・スペーシング・角丸）が統一されているか？
Q5: エラー表示・空状態は他の画面と同じパターンか？
```

**検証手順**:
1. 変更したView/Componentと同種の既存UIを全てリストアップ（Grep/Globで検索）
2. フィードバック、アクセシビリティ、disabled条件、スタイルを横断比較
3. 差異があれば指摘する

### 2.6 操作中断・インタラクションのエッジケース（B評価頻出パターン #2）

> **本質**: ハッピーパスは完璧でも、操作の中断・複合・タイミング競合で壊れる

```
Q1: アニメーション途中でキャンセル/画面遷移したとき、opacity/transformが中間値で止まらないか？
Q2: ジェスチャーの複合操作（タップ→ドラッグ→タップ）で意図しない副作用が起きないか？
Q3: debounce/delay中に別の操作が来たとき、状態不整合にならないか？
Q4: ボタン連打で重複処理が走らないか？
Q5: アプリのバックグラウンド復帰時に状態は正しいか？
```

### 2.7 データ・リソース管理の質問

```
Q1: 開いたリソース（ファイル、DB接続、ソケット）は確実にクローズされるか？
Q2: メモリリークの原因となるオブジェクトの参照は残らないか？
Q3: 大量データ処理時にOOMにならないか？（ページネーション、ストリーム処理）
Q4: トランザクションの境界は適切か？
Q5: キャッシュの有効期限・無効化戦略は？
```

### 2.8 運用・デプロイの質問

```
Q1: この変更はDBマイグレーションを必要としないか？
Q2: 環境変数や設定の追加は必要か？
Q3: 後方互換性は保たれているか？（APIの変更、データスキーマの変更）
Q4: ロールバックは可能か？
Q5: モニタリング・アラートは適切か？
Q6: ログ出力は運用に十分か？
```

### 2.9 Root cause analysis チェック（bug fix PR の場合 / MUST）

> **本質**: bug fix PR で「テストが green になったから完了」を許さない。真因が特定されているか、patch を選んだなら justification があるかを確認する。

このセクションは PR / 変更が **bug fix 系** の場合に必須実施:

- PR タイトル / 本文 / コミットメッセージに `fix`, `bug`, `crash`, `flaky`, `regression`, `不具合`, `修正` を含む
- 関連 Issue に `bug` / `fix` / `incident` label が付いている

#### 2.9.1 PR description の必須項目チェック

```
□ Root cause セクションがあるか？
  - 最低3階層の Why が書かれているか？（軽量バグなら 1行 OK だが、その判断根拠を確認）
  - 特定できなかった場合: 調査範囲と棄却した仮説が書かれているか？

□ Horizontal expansion セクションがあるか？
  - grep / Glob で同パターンの他箇所を確認した結果が書かれているか？

□ Fix strategy が明示されているか？
  - Root fix or Patch のどちらか明確か？
```

#### 2.9.2 Patch 選択時の justification チェック

PR が **patch / workaround を選択している場合** （Fix strategy = Patch）、以下を MUST 確認:

```
□ Why patch instead of root fix セクションがあるか？
  - 理由が具体的に書かれているか？（「時間がないから」だけは NG、具体的な締切等が必要）
  - 最低1つチェックされているか？

□ Follow-up issue が起票されているか？  ← MUST
  - issue 番号が書かれているか？
  - issue が実在し、内容が patch 解消の方針を含んでいるか？（gh issue view で確認）
```

**follow-up issue が無い patch PR は `[BLOCKER]` を必ず発火させる**（merge gate）:

```markdown
[BLOCKER] patch / workaround を選択していますが follow-up issue が起票されていません。
これは「symptom を抑制する PR が真因対応なしで merge される」リスクがあります。
真因解消の follow-up issue を起票して PR description に記載してください。
真因が確定したら issue 不要というケースなら、PR description の Root cause セクションで明示してください。
```

#### 2.9.3 最小再現テストの存在チェック

```
□ bug の最小再現テストが追加されているか？
  - 修正前に Red、修正後に Green になるテストか？
  - 「症状が出ない」だけでなく「症状の原因が起きない」テストか？
```

#### 2.9.4 軽量バグ判定の妥当性チェック

PR description で **「軽量バグなので 1行 Why のみ」** と申告されている場合、reviewer は以下を MUST 確認:

```
□ implementer が PR description に「軽量と判定した根拠（1行 Why）」を書いているか？
□ その判断は妥当か？以下の判定基準で reviewer 自身が再評価:
  - 修正前に「なぜ起きたか」を1文で説明できる
  - 修正範囲が単一ファイル / 数行に収まる
  - 同種の bug が過去に複数回起きていない（grep / git log で確認）
  - 型ミス / typo / 明らかな null check 漏れ等、原因と結果が直結

□ 妥当でないと判断したら `[SHOULD]` 以上で flag し、full flow（Why 3階層 + 最小再現 + 横展開）を要求する
```

**判定例**:
- ✅ 妥当: 「`name == null` で表示されない → `name?.toString()` に修正」
- ❌ 不当: 「`name == null` で表示されない」だけで full flow を skip → なぜ null が入るのかが未解明（実は API レスポンスのスキーマ違反かもしれない）

---

## Phase 3: コード品質チェック

（以下のドメイン知識セクションの Code Review Checklist を使用）

---

## Phase 4: 不在の検出（「書かれていないもの」を見つける）

> **重要**: 最も見落としやすいのは「書かれていないコード」

### 4.1 不在チェックリスト

```
□ テストは書かれているか？
  - ユニットテスト
  - 境界値テスト
  - エラーケーステスト

□ ドキュメントは更新されているか？
  - README
  - APIドキュメント
  - 変更履歴

□ 必要なログ出力は入っているか？
  - エラーログ
  - 監査ログ
  - デバッグ用ログ

□ エラーハンドリングは適切か？
  - 例外のキャッチ
  - ユーザーへのエラー表示
  - リトライ処理

□ 入力検証は十分か？
  - 型チェック
  - 範囲チェック
  - フォーマットチェック
```

### 4.2 テスト品質チェック（B評価頻出パターン #3）

> **本質**: テストが「動く」だけで、保守性・網羅性のチェックが甘い

```
□ マジックナンバー禁止
  - テスト内の数値は実装側の定数を参照しているか？
  - 直値（20, 100等）がハードコードされていないか？

□ テストの対称性
  - row方向をテストしたならcol方向も
  - 横スクロールをテストしたなら縦スクロールも
  - 追加のテストがあるなら削除のテストも

□ エラーケース・境界値テスト
  - 空入力、最大値、不正入力のテストがあるか？
  - 正常系だけになっていないか？
```

### 4.3 プロダクション/テスト境界チェック（B評価頻出パターン #4）

```
□ テスト用フラグ/initは #if DEBUG で囲っているか？
□ テスト専用プロパティが public/internal で不必要に公開されていないか？
□ モック/スタブがプロダクションターゲットに含まれていないか？
```

### 4.4 コード重複チェック（B評価頻出パターン #5）

```
□ 文字列リテラルが2箇所以上にないか？（定数化すべき）
□ 同じ計算ロジックが複数箇所で呼ばれていないか？（共通化すべき）
□ アニメーション定義が withAnimation と .animation で二重になっていないか？
```

### 4.5 アンチパターン自動検出（baseline でも常時 ON）

> **本質**: 「symptom 抑制で patch しただけ」の変更を自動検出する。新規追加された場合は **必ず根拠を求める**。

新規追加または変更行に以下のパターンが含まれていたら、PR コメントで根拠を要求する。

**前処理（MUST）**: 全パターン共通で **`git diff main --unified=0` の `+` 行（新規追加行）のみを対象** にする。既存コード全体を grep すると false positive が爆発するため必ず diff に絞ること。

```bash
# 検査対象の diff を取得（+行のみ、ファイル名/hunk header 除去）
git diff main --unified=0 -- '*.kt' '*.java' '*.swift' '*.py' '*.js' '*.ts' '*.go' \
  | grep -E '^\+[^+]' | sed 's/^\+//'
```

以下の各パターンはこの diff 出力を pipe で受け取って検査する想定。

#### A. 例外握りつぶし

検出パターン（言語別 grep / 単語境界と中身チェックを併用）:

```bash
# Kotlin / Java / Swift / JS / TS — 「中身が空 or 改行のみ or コメントのみ」の catch ブロックに絞る
grep -nE '\bcatch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*(//[^\n]*)?[[:space:]]*\}' \
  --include="*.kt" --include="*.java" --include="*.swift" --include="*.js" --include="*.ts"

# Python — 直後の行が pass のみ
grep -nE '\bexcept\b[^:]*:[[:space:]]*$' -A1 --include="*.py" | grep -E '^[[:space:]]+pass[[:space:]]*$'

# Go — error 無視（`_ = err` 含む）
grep -nE 'if[[:space:]]+err[[:space:]]*!=[[:space:]]*nil[[:space:]]*\{[[:space:]]*\}' --include="*.go"
grep -nE '_[[:space:]]*=[[:space:]]*err\b' --include="*.go"
```

**Note**: 上記の正規表現は **single-line の空 catch のみ検出**。`catch (e: Exception) {\n}` のような multi-line 空ブロックは取りこぼす。複数行ブロックの空 catch を完全に拾うには `ast-grep` 等の **structural matcher** を使うこと。例:

```bash
# ast-grep の例（kotlin）
sg -p 'catch ($X) { }' --lang kotlin
sg -p 'catch ($X) {\n}' --lang kotlin
```

優先度: structural matcher の導入は推奨だが必須ではない。最低でも上記 grep を実行し、bug fix PR の reviewer は **手動で「catch ブロックの中身」を全件確認** する。

検出時のPRコメント例:

```markdown
[BLOCKER] 例外/エラーを握りつぶしています（L<行番号>）
- なぜ catch するのか？（root cause）
- 握りつぶしが正しい選択である理由は？
  - 期待される失敗で無視可能 → コメントで明示してください
  - 真因不明 → root-cause-analysis を実施してください
  - 上位への伝搬不要 → なぜ不要かコメントしてください
- 最低限 `log.error(...)` で痕跡を残すべきではないですか？
```

#### B. テスト無効化

検出パターン:

```bash
# JUnit
grep -nE '@(Ignore|Disabled)' --include="*.kt" --include="*.java"

# XCTest / Jest / Mocha
grep -nE '\b(xit|xdescribe|xtest|skip)\b' --include="*.swift" --include="*.js" --include="*.ts"

# pytest
grep -nE '@pytest\.mark\.skip' --include="*.py"

# Go
grep -nE 't\.Skip\(' --include="*.go"
```

検出時のPRコメント例:

```markdown
[BLOCKER] テストを無効化しています（L<行番号>）
- 無効化の理由は何ですか？（コメントで明示してください）
- 再有効化の条件は？（修正版がリリースされたら、別 issue が close されたら 等）
- follow-up issue は起票されていますか？

例:
@Disabled("Flaky on CI due to clock skew. Tracked in #1234. Re-enable after #1234 is fixed.")
```

#### C. Workaround コメント

> **重要**: 識別子（`tempDir`, `HackathonProject`, `backHack` 等）への部分一致を避けるため、**コメント行限定 + 単語境界 `\b` + 大文字小文字保持**で絞る。

検出パターン（**コメント行限定**）:

```bash
# git diff main --unified=0 の +行のうち、コメント開始記号（// # /* * <!--）で始まる行のみ抽出
git diff main --unified=0 -- '*.kt' '*.swift' '*.ts' '*.js' '*.py' '*.go' '*.html' \
  | grep -E '^\+[[:space:]]*(//|#|/\*|\*|<!--)' \
  | grep -niE '\b(workaround|temporary|temp[[:space:]]+fix|hack|FIXME|TODO:[[:space:]]*fix[[:space:]]+later)\b'
```

**設計上のポイント**:
- 後段 grep は **`-i` フラグを付与**して大文字小文字を無視する（`// Workaround:` `// HACK:` `// Hack:` `// FIXME` 等、コメントでは慣習的に capitalized で書かれることが多いため）
- `HackathonProject` や `tempDir` のような正当な identifier は **前段のコメント行前フィルタ**で除外されるため、`-i` を付けても false positive は再発しない
- 必ず単語境界 `\b` を付与（`temp` の部分一致で `tempDir` がヒットするのを防ぐ）
- コメント開始記号でフィルタすることで「文字列 literal 内の workaround」「変数名内の workaround」を除外
- `temp[[:space:]]+fix` は **空白1つ以上を要求**し、`tempFixture` のような connection を防ぐ

**Note**: `<!-- workaround -->` のような multi-line ブロックコメントの2行目以降（`*` 始まり）は検出するが、`/* workaround */` の途中行で `*` を持たない言語（生 HTML）は取りこぼす。完全な lexer ベース検出には `ast-grep` 等を使うこと。

検出時のPRコメント例:

```markdown
[SHOULD] `<キーワード>` を含むコメントが追加されています（L<行番号>）
- 真因は特定されていますか？
- 解消の follow-up issue は起票されていますか？
- 受容可能な workaround なら、削除条件と issue 番号を明記してください

例:
// Workaround: iOS 17.0-17.1 で UIKit 内部の layout race を回避するための遅延。
// 真因: 17.2 で修正済み（FB12345678）。最低 deploy target が 17.2 になったら削除する。
// Follow-up: #1234
```

#### D. Root cause 未特定の retry

> **重要**: `library_with_retry_in_name` のような文字列 literal や無関係 identifier を拾わないよう、**呼び出し / アノテーション形式に絞る**。

検出パターン（呼び出し / アノテーション限定）:

```bash
# git diff main --unified=0 の +行で検査
git diff main --unified=0 -- '*.kt' '*.swift' '*.ts' '*.js' '*.py' '*.go' \
  | grep -E '^\+[^+]' \
  | grep -nE '(@Retry\b|\bRetryPolicy\b|\.retry[A-Z]\w*\(|\bretryWithBackoff\b|\bretry_with_backoff\b)'

# 同 +行で「裸の retry ループ」を検出（while/for + try/catch + count）
git diff main --unified=0 \
  | grep -E '^\+[^+]' \
  | grep -nE '\b(repeat|for|while)\b.*\b(retry|attempt)\b'
```

**設計上のポイント**:
- 関数呼び出し（`.retryXxx(`）/ アノテーション（`@Retry`）/ クラス名（`RetryPolicy`）に絞ることで、文字列 literal `"library_with_retry_in_name"` の混入を回避
- 単純な `retry` / `retries` 単独の grep は false positive が極端に多いため除外
- ループ + retry/attempt キーワードの共起で「手書き retry ループ」も検出

**Note**: 「正当な retry 識別子」と「root cause 未特定の retry」の区別は **grep だけでは判定不能**。検出されたらコメント文 / 周辺コード / commit message で root cause が明示されているかを reviewer が手動確認すること。

retry が新規追加されている場合は以下を確認:

```markdown
[SHOULD] retry を新規追加しています（L<行番号>）
- なぜ retry が必要ですか？（root cause が確認されていますか？）
- retry 対象の失敗は「期待された一時的失敗」ですか？（rate limit / network flap 等）
- retry が「真因不明の隠蔽」になっていませんか？
- max attempts / backoff の根拠は SLO に基づいていますか？
```

#### E. アンチパターン検出時の総合判定

| 検出パターン | 評価への影響 |
|---|---|
| A. 例外握りつぶし | **C 評価以下**（根拠が無ければ） |
| B. テスト無効化（follow-up なし） | **C 評価以下** |
| C. Workaround コメント（follow-up なし） | **B 評価以下** |
| D. Root cause 未特定の retry | **B 評価以下** |
| Patch 選択で follow-up issue 無し | **C 評価以下** |

### 4.6 「もし〜だったら」シミュレーション

変更内容を見て、以下のシナリオを想像：

1. **新人エンジニアがこのコードを保守するとしたら？**
   - コメントや命名で意図が伝わるか
   - 複雑すぎないか

2. **このコードが本番で失敗したとしたら？**
   - 原因特定に必要な情報は得られるか
   - ロールバック可能か

3. **このコードを1年後に見たら？**
   - なぜこう実装したかわかるか
   - 技術的負債になっていないか

---

## レビュー出力形式

```markdown
# コードレビュー結果

## 概要
- **対象**: [ファイル名/PR番号]
- **レビュー日**: [日付]
- **総合評価**: [A/B/C/D]

---

## 考慮漏れ（発見された未対応事項）

### 境界条件・エッジケース
| 質問 | 考慮状況 | 問題点 | 推奨対応 |
|------|----------|--------|----------|
| null入力の場合 | ❌ 未対応 | クラッシュする | null checkを追加 |
| 空配列の場合 | ✅ 対応済 | - | - |

### 暗黙の仕様
| 期待される動作 | 実装状況 | 問題点 |
|----------------|----------|--------|
| 削除確認ダイアログ | ❌ 未実装 | 誤操作の危険 |

### 不在の検出
| 必要なもの | 状況 | 優先度 |
|------------|------|--------|
| エラーケースのテスト | ❌ 欠落 | High |

### Root cause analysis（bug fix の場合のみ）
| 確認項目 | 状況 | 問題点 |
|---|---|---|
| Root cause セクション | ❌ 欠落 / ✅ 記載済 | 真因が特定されていない |
| 最小再現テスト | ❌ 欠落 / ✅ 追加済 | 再発防止網が無い |
| 横展開チェック | ❌ 未実施 / ✅ 実施済 | 他箇所に同根本原因が残存 |
| Patch justification | ❌ 欠落 / ✅ 記載 / N/A | patch 理由が不明確 |
| Follow-up issue | ❌ 欠落 / ✅ #___ / N/A | 解消の進路が無い |

### アンチパターン検出
| パターン | 検出 | 行番号 | 根拠の記載 |
|---|---|---|---|
| 例外握りつぶし | ❌/✅ | L___ | あり/なし |
| テスト無効化 | ❌/✅ | L___ | あり/なし |
| Workaround コメント | ❌/✅ | L___ | あり/なし |
| Root cause 未特定の retry | ❌/✅ | L___ | あり/なし |

---

## 必須修正（Critical / Blocker）
1. [問題点と修正案]

## 推奨修正（Should Fix）
1. [改善点と提案]

## 軽微な指摘（Nice to Have）
1. [細かい指摘]

## 良い点
- [評価できる点]

---

## 確認質問（作成者への質問）
- [ ] Q1: 〜の場合の動作は意図通りですか？
- [ ] Q2: 〜は考慮されていますか？
```

---

## Phase 5: PRコメント投稿

レビュー完了後、レビュー結果をPRコメントとして投稿し、チームで共有可能にする。

### 5.1 PR番号の特定

以下の優先順で対象PRを特定する：

1. **`$ARGUMENTS` にPR番号が指定されている場合**: そのPR番号を使用
2. **それ以外の場合**: 現在のブランチに紐づくPRを自動検出する

```bash
gh pr view --json number -q .number
```

- PRが見つかった場合: そのPR番号を使用して 5.2 に進む
- PRが見つからない場合: PRコメント投稿をスキップし、レビュー結果の出力のみで終了する

### 5.2 レビュー結果の投稿

```bash
gh pr review [PR番号] --comment --body "<details>
<summary>🤖 コードレビュー結果 — 総合評価: [A/B/C/D]</summary>

## コードレビュー結果

### 概要
- **総合評価**: [A/B/C/D]
- **レビュー日**: [日付]

### 考慮漏れ（主要な発見事項）
[Phase 2で検出された主要な考慮漏れのサマリー]

### 必須修正（Critical / Blocker）
[必須修正のリスト、なければ「なし」]

### 推奨修正（Should Fix）
[推奨修正のリスト、なければ「なし」]

### 確認質問（作成者への質問）
[作成者に確認したい質問のリスト]

---
Generated by [Claude Code](https://claude.ai/code) `/code-review`

</details>
"
```

**注意事項**:
- コメント内容は出力形式（Phase 4まで）の結果をサマリーとして構成する
- 投稿前にユーザーに確認を取る（投稿する旨をユーザーに通知してから実行する）
- **リークガード（Phase 0）の遵守**: 投稿本文に作者帰属・人格言及（「別のエンジニアが書いた」「ジュニア」「junior」等）を**含めない**。帰属フレーミングはレビュアの内部の構え限定であり、出力に現れてよいのは「コードに対する指摘」のみ。投稿前に本文を見直し、該当語が無いことを確認する。

---

## レビュー基準

| 評価 | 基準 |
|------|------|
| A | 考慮漏れなし、マージ可能 |
| B | 軽微な考慮漏れあり、指摘対応後マージ可能 |
| C | 重要な考慮漏れあり、修正必須 |
| D | 根本的な考慮漏れ、設計見直しが必要 |

---

## 実行例

```
/code-review src/components/Button.tsx
/code-review #42
/code-review  # 現在の変更をレビュー
/code-review src/utils/
```

---
---

# ドメイン知識

## Code Review Principles

### 1. Be Kind and Constructive

**Good Feedback:**
```
"Consider extracting this logic into a separate function for better testability and reusability."

"This could be vulnerable to SQL injection. Using prepared statements would make it safer."

"Great refactoring! One suggestion: we could simplify this by using Array.map() instead of the for loop."
```

**Avoid:**
```
"This is wrong."
"Why didn't you just use map()?"
"This is terrible code."
```

### 2. Focus on the Code, Not the Person

**Good:**
```
"This function has high complexity. Breaking it into smaller functions would improve readability."
```

**Avoid:**
```
"You wrote a very complex function."
```

### 3. Explain Why

Provide reasoning behind suggestions.

**Good:**
```
"Using const instead of let here prevents accidental reassignment and makes the intent clearer."

"Caching this API call would reduce server load and improve response time for users."
```

### 4. Offer Alternatives

Provide concrete suggestions, not just criticism.

### 5. Distinguish Must-Fix from Nice-to-Have

Use prefixes or labels to indicate priority:

- **[MUST]** or **[BLOCKER]**: Bugs, security issues, broken functionality
- **[SHOULD]** or **[IMPORTANT]**: Maintainability, performance, design issues
- **[NITS]** or **[OPTIONAL]**: Style preferences, minor improvements
- **[QUESTION]**: Seeking clarification

### 6. Recognize Good Work

Positive feedback motivates and reinforces good practices.

---

## Code Review Checklist

### 1. Functionality
- [ ] **Does it work?** Code does what it's supposed to do
- [ ] **Logic correctness**: No logical errors or edge cases missed
- [ ] **Requirements met**: Addresses the issue/ticket/user story
- [ ] **No regressions**: Doesn't break existing functionality
- [ ] **Error handling**: Appropriate error handling and validation
- [ ] **Edge cases**: Handles boundary conditions (null, empty, max values)

### 2. Design and Architecture
- [ ] **SOLID principles**: Single responsibility, proper abstractions
- [ ] **DRY**: No unnecessary duplication
- [ ] **Separation of concerns**: Clear boundaries between layers
- [ ] **Appropriate patterns**: Using the right design patterns
- [ ] **Future extensibility**: Easy to extend without major refactoring
- [ ] **API design**: Clear, consistent interfaces

### 3. Readability and Maintainability
- [ ] **Clear naming**: Variables, functions, classes have descriptive names
- [ ] **Consistent style**: Follows project conventions
- [ ] **Appropriate comments**: Complex logic is explained
- [ ] **No commented-out code**: Remove dead code
- [ ] **Function size**: Functions are small and focused
- [ ] **Cognitive complexity**: Easy to understand at a glance

### 4. Performance
- [ ] **No obvious bottlenecks**: Algorithms are reasonably efficient
- [ ] **Database queries**: Optimized, no N+1 queries
- [ ] **Caching**: Appropriate use of caching
- [ ] **Memory leaks**: No obvious memory leaks
- [ ] **Resource cleanup**: Proper cleanup of resources (files, connections)
- [ ] **Async operations**: Proper use of async/await, no blocking operations

### 5. Security
- [ ] **Input validation**: All user input is validated and sanitized
- [ ] **SQL injection**: Using parameterized queries
- [ ] **XSS prevention**: Proper output encoding
- [ ] **Authentication**: Proper auth checks
- [ ] **Authorization**: Correct permission checks
- [ ] **Sensitive data**: No secrets in code, proper data handling
- [ ] **Dependencies**: No known vulnerable dependencies

### 6. Testing
- [ ] **Test coverage**: Adequate test coverage (unit, integration, e2e)
- [ ] **Test quality**: Tests are meaningful, not just increasing coverage
- [ ] **Edge cases tested**: Tests cover boundary conditions
- [ ] **Test readability**: Tests are clear and well-organized
- [ ] **No flaky tests**: Tests are deterministic

### 7. Documentation
- [ ] **Code comments**: Complex logic is explained
- [ ] **API documentation**: Public APIs are documented
- [ ] **README updates**: README reflects changes if needed
- [ ] **Migration guides**: Breaking changes documented

### 8. Dependencies and Configuration
- [ ] **Dependency updates**: Dependencies are up-to-date and necessary
- [ ] **No breaking changes**: New dependencies don't conflict
- [ ] **License compatibility**: Dependencies have compatible licenses
- [ ] **Configuration**: Config changes are documented

---

## 初回A評価のための自己レビューチェックリスト

> **背景**: 過去PRの分析から、B評価の正体は「実装の質」ではなく「周辺への目配り」の不足であることが判明。ロジック自体は正しいのに、既存UIとの一貫性・操作中断のエッジケース・テストの保守性で必ず1つは引っかかる。以下の6項目を実装完了後にチェックすれば、大半のBはAになる。

### 1. UX一貫性チェック（頻度: 最高）

- [ ] **sensoryFeedback / haptics**: 既存の類似ボタン・操作と触覚フィードバックは揃っているか？
- [ ] **accessibilityLabel / accessibilityHint**: 全てのインタラクティブ要素に付いているか？
- [ ] **disabled条件**: 関連する全UIに同じdisabled条件が適用されているか？
- [ ] **UIスタイルの統一**: 既存の類似コンポーネントとフォント・色・スペーシング・角丸が揃っているか？
- [ ] **エラー表示・空状態**: 他の画面と同じパターンで表示されているか？

### 2. 操作中断・インタラクションのエッジケース（頻度: 高）

- [ ] **アニメーション途中キャンセル**: opacity/transformが不正な中間値で止まらないか？
- [ ] **複合ジェスチャー**: タップ→ドラッグ→タップで意図しない動作が起きないか？
- [ ] **遅延中の割り込み**: debounce/delay中に別の操作が来たとき、状態不整合にならないか？
- [ ] **連打耐性**: ボタンの連打で重複処理が走らないか？
- [ ] **バックグラウンド復帰**: アプリ復帰時に状態は正しいか？

### 3. テストコードの品質（頻度: 高）

- [ ] **マジックナンバー禁止**: テスト内の数値は実装側の定数を参照しているか？
- [ ] **対称性テスト**: row/col、横/縦、追加/削除の対称性があるか？
- [ ] **エラーケース・境界値**: 正常系だけでなく、空入力・最大値・不正入力のテストがあるか？

### 4. プロダクション/テスト境界の分離（頻度: 中）

- [ ] **テスト用フラグ/init**: `#if DEBUG` で囲っているか？
- [ ] **テスト専用プロパティのアクセス制御**: `@testable import` で十分か？
- [ ] **モック/スタブの混入**: プロダクションターゲットに含まれていないか？

### 5. コード重複・冗長の排除（頻度: 中）

- [ ] **文字列リテラルの重複**: 同じ文字列が2箇所以上にないか？
- [ ] **同じ計算の重複**: 同じ計算ロジックが複数箇所で呼ばれていないか？
- [ ] **アニメーション定義の二重化**: `withAnimation` と `.animation()` が同じプロパティに二重定義されていないか？

### 6. 空・nil・ゼロの境界値（頻度: 中）

- [ ] **空コレクション**: `items.isEmpty` の場合にクラッシュしないか？
- [ ] **nil / Optional**: nilの場合、適切にハンドリングされるか？
- [ ] **ゼロ除算**: サイズや個数で割る処理があれば、ゼロの場合を考慮しているか？
- [ ] **初期状態**: 初回起動時やデータが空の状態で画面が正しく表示されるか？
