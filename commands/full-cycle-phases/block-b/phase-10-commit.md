# Phase 10: 分割コミット

ユーザーへの確認は不要。最小の論理的単位で自動的にコミットする。

> **実行層の制約（#52）**: `git` コマンドは **`Bash` を保有する層（orchestrator / `implementation-lead`）が
> 直接実行**する。`feature-planner` / `spec-analyzer` / `app-reviewer` は `Bash` を持たないため commit を委譲できない。
> `Bash` を持つ agent（`vrt-engineer` / `design-reviewer` / `tdd-test-writer` 等）に対しても commit は呼び出し元に
> 集約する。事前許可は Phase 1 で検証済み（`Bash(git:*)`）。

## スキップ条件

Phase 8/9 で既にコミット済みの場合（`git status` で未コミット変更がない場合）、このフェーズはスキップする。

```bash
# 変更内容を確認
git status
git diff --stat

# 未コミット変更がなければスキップ
# 未コミット変更がある場合のみ、最小の論理的単位でコミット（確認不要・自動実行）
# 例: テスト追加 → 実装 → リファクタリング
```

## git add 除外対象

以下のファイルは `git add` の対象に含めないこと:
- `.full-cycle-state.json`（フルサイクル状態ファイル）
- `.DS_Store`
- その他 `.gitignore` に含まれるファイル

```bash
# 個別ファイル指定でステージング（git add -A は使わない）
git add [対象ファイル1] [対象ファイル2] ...
```

## TDDサイクルのコミット粒度

Phase 8 で TDD したコードは、**1 TDDサイクル（Red→Green→Refactor）= 1 コミット** を原則とする。
テストと実装は **同じコミット** に含める。

### 理由

- テストのみのコミット = リポジトリ履歴に **Red 状態（失敗するテスト）** が残ることになる
- これは TDD の履歴ではなく、「テストを書いた / 実装を書いた」という別作業の履歴
- 1サイクル1コミットなら、後から `git log` を見るだけで「どの振る舞いを、どんなテストで、どう実装したか」が1単位で読める

### Good / Bad の例

✅ **Good**:
```
feat(auth): メールアドレス検証を追加

- 有効なメールでユーザー登録できる
- 空のメールでバリデーションエラー
- @がないメールで形式エラー

テスト: UserRegistrationTests.swift
実装: UserRegistration.swift
Refs: #123
```

❌ **Bad**（テストと実装を分割）:
```
test(auth): メールアドレス検証のテストを追加  ← Red状態でリポジトリに残る
feat(auth): メールアドレス検証の実装を追加
```

### 例外

以下の場合は分割してよい:
- リファクタリング（Refactor フェーズが大きい場合）→ `refactor(auth): メールアドレス検証を ValueObject に抽出`
- 純粋なドキュメント追加 → `docs(auth): READMEに使い方を追加`

## コミットメッセージ形式（Conventional Commits準拠）

| type | 用途 |
|------|------|
| feat | 新機能追加（**TDDサイクルのテスト+実装をまとめてここ**） |
| fix | バグ修正（テストと修正を1コミットに） |
| refactor | リファクタリング（テストは変えず構造のみ変更） |
| test | テストのみの追加・修正（**TDDサイクル中の単独利用は避ける**。特性化テストや既存テストの修正のみ） |
| docs | ドキュメント変更 |
| style | コードスタイル変更（機能変更なし） |
| chore | ビルド・設定等の変更 |

```
<type>(<scope>): <概要>

<詳細>

Refs: #[issue番号]
```

例: `feat(auth): ログイン画面のUI実装（テストと実装）`
