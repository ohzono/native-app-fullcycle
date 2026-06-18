---
name: implement
description: 機能を実装します。GitHub Issueを起点にWorktree分離、仕様理解、TDD実装、コミット、Draft PR作成、コンフリクト解消までを実行します。
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, WebSearch, Skill, Task
model: opus
user-invocable: true
argument-hint: "#issue番号 [仕様ファイルパス]"
---

# 機能実装

指定された仕様「$ARGUMENTS」に基づいて、機能を実装します。

## 引数について

- **$ARGUMENTS**: 実装対象の指定（**Issue番号は必須**）
  - **Issue番号**: `#123` 形式
  - **Issue URL**: `https://github.com/owner/repo/issues/123`
  - **仕様ファイルパス + Issue番号**: 組み合わせ指定

**注意**: Issue番号がない場合は worktree を作成できません。先に GitHub Issue を作成してください。

## 実行フロー

1. **Worktree 分離**: Issue番号からブランチ名を決定し、作業用worktreeを作成
2. **仕様理解**: Issue内容を取得し、必要に応じて `spec-analyzer` で事前チェック
3. **タスク種別判定**: Issue が bug fix / 不具合対応系か、新機能開発か判定
4. **コードベース分析**: プロジェクト構造、技術スタック、関連コードを調査
5. **実装**: TDDサイクル（Red→Green→Refactor）で段階的に実装
6. **テスト確認**: ビルド確認 + 全テスト実行
7. **コミット**: Conventional Commits形式で分割コミット
8. **Draft PR作成**: テンプレートに基づいてPR作成 + コンフリクト解消

各ステップの詳細な手順は `implementation-lead` エージェントの定義に従ってください。

## Bug fix / 不具合対応の場合（baseline: root-cause analysis）

タスクが以下のいずれかに該当する場合、**`root-cause-analysis` skill を default で呼び出す**（enable条件ではなく baseline）:

- Issue タイトル / 本文に `bug` / `fix` / `不具合` / `修正` / `crash` / `flaky` / `regression` / `error` などのキーワードを含む
- Issue ラベルが `bug` / `fix` / `incident` を含む
- ユーザから「直して」「動かない」「失敗する」「クラッシュする」と依頼された

**呼び出しタイミング**: ステップ 4（コードベース分析）の **直後 / ステップ 5（実装）の前**。

### 強制フロー

```yaml
Skill:
  skill: root-cause-analysis
  args: "#<issue番号> <バグの説明>"
```

`root-cause-analysis` skill が以下の Output を返すまで実装に進まない:

1. **真因（最低3階層の Why）** または **棄却した仮説と調査範囲**
2. **最小再現テスト**（Red 状態の確認）
3. **横展開（grep / Glob）の結果**: 同じ根本原因が他箇所にあるか
4. **修正方針**: root fix or patch（patch なら justification と follow-up issue 必須）

### Patch を選んだ場合の追加義務

`root-cause-analysis` の Step 4 で patch を選択した場合、PR description に以下を**必ず含める**:

- `Root cause` セクション
- `Why patch instead of root fix` セクション（チェック理由を具体的に）
- `Follow-up` セクション（**起票した issue 番号を必須**）

follow-up issue が無い patch PR は `code-review` skill で `[BLOCKER]` が発火する（merge gate）。

### エスカレーションの判断

`root-cause-analysis` のエスカレーション条件（修正コスト N倍 / 他チーム所管 / 真因不明＋本番影響大 / scope 拡大）に該当した場合、**実装を中断してユーザに相談**する。

### 軽量バグの例外

真因が一目瞭然なケース（typo / 自明な null check 漏れ / 単純な型ミス）は、Step 1 の Why を 1行で済ませて良い。判断基準: **修正前に「なぜ起きたか」を1文で説明できるか**。

## 新機能開発の場合

bug fix キーワードを含まず、新機能追加・改善系のタスクの場合は、`root-cause-analysis` skill を呼び出さず、通常の TDD フロー（[[test-driven-development]]）で進める。

## iOS SwiftUI / Swift Concurrency の場合

**iOS の SwiftUI / Swift Concurrency を含む変更の場合は、`mobiledev-fullcycle:swiftui-pro` skill を default で呼び出す**（CLAUDE.md の優先方針に準拠）。modern API・保守性・パフォーマンスの観点をステップ 5（実装）で反映する。

## 実行例

```
/implement #123
/implement #123 docs/spec/user-auth.md
/implement https://github.com/owner/repo/issues/123
```
