---
name: root-cause-analysis
description: バグ修正・不具合対応・flaky test・原因不明クラッシュ調査のbaseline手順。5 Whys（最低3階層）・最小再現・横展開grep・症状抑制 vs 根本治療の自己判定を強制し、patch選択時はjustificationを必須化します。
allowed-tools: Read, Glob, Grep, Bash, WebSearch
model: opus
user-invocable: true
argument-hint: "[Issue番号 or バグの説明]"
---

# Root-Cause Analysis（真因分析）

**設計思想**: root-cause analysis は **baseline（常時 ON）**。patch / workaround は **justification 必須の例外**として扱う。

「root-cause モードを enable する」のではなく、**「root-cause が default、patch するなら理由を PR に残す」** モデルに統一する。

---

## いつ使うか

**MUST**: 以下のタスクではこの skill を default で呼び出す。

- バグ修正 / 不具合対応（symptom が明確）
- flaky test の解消
- 本番クラッシュ / 例外調査
- 既存機能のregression対応
- 「動かない」「たまに失敗する」「タイミングによる」系の調査

**例外（軽量バグ）**: 真因が一目瞭然なケースは Step 1 の Why を 1行で済ませて良い。
- typo の修正
- 単純な null check 漏れ
- 自明な型ミス

**判断基準**: 修正前に「なぜ起きたか」を1文で説明できないなら、軽量バグではない → full flow を回す。

**判定主体（MUST）**: implementer の自己申告だけで「軽量」と判定するのは骨抜き化の温床。
- implementer は PR description に **軽量と判定した根拠（1行 Why）を必ず書く**
- reviewer は [[code-review]] Phase 2.9 で「軽量判定の妥当性」をチェックする
- 判定が妥当でないと reviewer が判断したら `[SHOULD]` 以上で flag し、full flow を要求する

---

## Core Flow（4 step）

### Step 1: 真因の特定（最低3階層の Why）

5 Whys の軽量版。**最低3階層**、止まったら 5階層まで掘る。

```
Symptom: <観測された現象>
Why 1: なぜ起きた？ → <一次原因>
Why 2: なぜそれが起きた？ → <二次原因>
Why 3: なぜそれが起きた？ → <根本原因の候補>
（必要なら Why 4, Why 5）
```

**書き方の例**:

```
Symptom: ログイン後にユーザー名が表示されないことがある
Why 1: ViewModel の userName が nil のまま画面が描画されている
Why 2: API レスポンスが返る前に View が初期化されている
Why 3: View 初期化時に async fetch を kick していないコードパスがある
→ 根本原因: View の lifecycle と data fetch の依存が宣言されていない
```

**禁止パターン**（symptom を言い換えただけで止まる）:

```
Symptom: ユーザー名が表示されない
Why 1: userName が nil（← これは現象の言い換え。停止禁止）
```

**仮説棄却の記録**: 複数仮説を立てた場合、棄却した仮説と棄却理由も残す。

```
仮説 A: API が 500 を返している → 棄却（ログを確認、200 が返っている）
仮説 B: View 初期化前に async fetch が完了しない → 採用
```

### Step 2: 最小再現の確立

**MUST**: 最小再現コードを作り、**テストとして残す**。

- 再現条件を最小化する（環境依存・入力依存を排除）
- 失敗するテストを書く（Red 状態の確認）
- これが Step 3 の修正後に Green になることで「治った」と判定する

**flaky test の場合**: 再現率を上げる方法を探す（並列実行、ループ実行、遅延注入）。100% 再現させてから直す。

### Step 3: 横展開（同じ根本原因の他箇所探索）

**MUST**: grep / Glob で同じパターンを探し、影響範囲を把握する。

```bash
# パターン例: View 初期化時の fetch 欠落
grep -rn "init.*View" --include="*.swift" | xargs -I {} grep -l "fetch" {}

# パターン例: 例外握りつぶし
grep -rn "catch.*{[[:space:]]*}" --include="*.kt"
grep -rn "except:[[:space:]]*pass" --include="*.py"
```

横展開で見つけた箇所は:
- **同じ修正で直せる** → 同一PRで一括修正
- **修正コストが大きい** → follow-up issue として切り出し、PR本文に記載

### Step 4: 修正方針の self-review

PR description / commit message に必ず書く:

```markdown
## Root cause
<Step 1 で特定した真因。特定できなかった場合は調査範囲と棄却した仮説>

## Fix strategy
<以下のいずれかを明示>
- [ ] Root fix: 真因を直接修正する
- [ ] Patch / workaround: 症状を抑制する（→ 後述の justification 必須）

## Horizontal expansion
<Step 3 で grep / Glob で確認した同パターンの箇所と対応方針>
- 同PR で修正: <ファイル一覧>
- Follow-up issue: #<番号>
- 影響なし: <確認したパターンと結果>
```

---

## Patch を選択する場合（escape hatch）

patch / workaround を選ぶこと自体は否定しない。ただし以下を **PR description で必須** にする:

```markdown
## Why patch instead of root fix
<以下から最低1つ選択、理由を具体的に書く>
- [ ] 時間制約（例: リリースまで X日、真因修正は Y日かかる）
- [ ] Scope外（他チーム/他コンポーネント所管 → 連携先を明記）
- [ ] 真因の修正コストが見積もり比 N倍以上（具体的に N=?）
- [ ] 真因不明だが本番影響が大きく一時止血が必要
- [ ] その他: <具体的な理由>

## Follow-up
- 起票した issue: #<番号>  ← **必須**
- 期限の目安: <YYYY-MM-DD or リリース X+1>
```

**follow-up issue が無い patch PR は code-review で `[BLOCKER]` を発火させる**（[[code-review]] skill 参照）。merge gate として機能させ、「症状を抑制する PR が真因対応なしで merge される」リスクを構造的に防ぐ。

---

## エスカレーション（staff engineer 判断ポイント）

以下のいずれかに該当したら **default を中断してユーザに相談**:

| 条件 | 相談内容 |
|---|---|
| 真因の修正コストが見積もり比 **N=3** 倍以上（推奨デフォルト） | context 投資の合意を取る |
| 真因が他チーム/他コンポーネントにある | escalation 先の相談 |
| 真因不明 + 本番影響大 | 一時 patch + 詳細 incident report のフロー切替 |
| 修正範囲が当初の想定を大きく超える | scope 拡大の合意を取る |

**N の運用**: デフォルトは `N=3`（見積もり 1日 → 実コスト 3日以上）。チーム/プロジェクト固有の SLA がある場合はそれを優先。N は PR description に **具体値で記入** することで判断の透明性を担保する。

**エスカレーションの判断軸**: 「ユーザの想定の範囲内で済むか」。範囲外なら相談する。

---

## アンチパターン（baseline でも常時検出）

以下を新規追加した変更は code-review で必ず根拠を求める。**正当な理由が無ければ修正を要求**。

### 1. 例外握りつぶし

```kotlin
// ❌ Anti-pattern
try { riskyOperation() } catch (e: Exception) { }

// ✅ 何らかの対応
try {
    riskyOperation()
} catch (e: Exception) {
    logger.error("riskyOperation failed", e)
    metrics.increment("risky_operation.failure")
    throw e // または明示的な fallback
}
```

```python
# ❌ Anti-pattern
try:
    risky_operation()
except:
    pass

# ❌ さらに悪い
try:
    risky_operation()
except Exception:
    pass
```

```swift
// ❌ Anti-pattern
do { try riskyOperation() } catch { }
```

### 2. テスト無効化

- `@Ignore` / `@Disabled` (JUnit)
- `xit` / `xdescribe` (XCTest / Jest)
- `skip()` / `pytest.mark.skip` (Python)
- `t.Skip()` (Go)

**ルール**: 無効化するなら理由をコメントで書き、再有効化の条件 / follow-up issue を必須化する。

```kotlin
// ❌
@Disabled
fun testUserLogin() { ... }

// ✅
@Disabled("Flaky on CI due to clock skew. Tracked in #1234. Re-enable after #1234 is fixed.")
fun testUserLogin() { ... }
```

### 3. workaround コメント

以下のキーワードを含むコメントが新規追加された場合、**真因と follow-up を明記**する:

- `workaround`
- `temporary`
- `hack`
- `TODO: fix later`
- `FIXME` （理由なし）
- `HACK`

```swift
// ❌ Anti-pattern
// HACK: 後で直す
sleep(0.5)

// ✅ 受容可能なら受容可能で記録する
// Workaround: iOS 17.0-17.1 で UIKit 内部の layout race を回避するための遅延。
// 真因: 17.2 で修正済み（FB12345678）。最低 deploy target が 17.2 になったら削除する。
// Follow-up: #1234
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ... }
```

### 4. root cause 未特定の retry

retry でしのいでいる箇所は危険信号。retry が **真因対策と並行している** ことを確認する。

```kotlin
// ❌ Anti-pattern
suspend fun callApi(): Result {
    repeat(3) {
        try { return realCall() } catch (_: Exception) { delay(100) }
    }
    error("failed after 3 retries")
}

// ✅ root cause が分かっていて意図的なら OK
suspend fun callApi(): Result {
    // Server-side rate limiting で 429 が散発的に返る（incident #5678 で確認済み）。
    // Exponential backoff で許容範囲内に収まることを SLO で確認。
    return retryWithBackoff(maxAttempts = 3, baseDelay = 100.ms) { realCall() }
}
```

---

## Self-review checklist

bug fix PR を出す前に self-check:

- [ ] Step 1: Why を最低3階層書いたか？（軽量バグなら 1行で OK）
- [ ] Step 2: 最小再現テストを書いたか？（修正前に Red を確認したか？）
- [ ] Step 3: grep / Glob で横展開を確認したか？
- [ ] Step 4: PR description に `Root cause` / `Fix strategy` / `Horizontal expansion` を書いたか？
- [ ] Patch を選んだなら `Why patch instead of root fix` と `Follow-up` を書いたか？
- [ ] アンチパターンを新規追加していないか？追加したなら理由を書いたか？
- [ ] 修正方針の self-review: これは「症状抑制」か「根本治療」か明示したか？

---

## 関連 skill

- [[implement]] — bug fix 系タスクでこの skill を default 呼び出しする
- [[code-review]] — アンチパターン検出と follow-up issue 欠落の `[BLOCKER]` 発火を実施する
- [[test-driven-development]] — Step 2 の最小再現テストは TDD の Red phase
- [[check-spec]] — 真因が仕様の曖昧さに起因する場合の調査
- [[pr-conflict-resolution]] — マージコンフリクトもroot cause視点で解消する
