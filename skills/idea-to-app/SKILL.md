---
name: idea-to-app
description: アイデアからPRD作成・GitHub Issue作成・フルサイクル開発までを全自動で実行します。テキストやURLでアイデアを渡すだけで、実装済みPRまで到達します。
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, WebSearch, WebFetch, Skill, Task, AskUserQuestion
model: opus
user-invocable: true
argument-hint: "[アイデアのテキスト or 参考URL]"
---

# Idea to App

アイデアから実装済みPRまでを全自動で実行します。

## 引数について

- **$ARGUMENTS**: アイデアの指定
  - **テキスト直接指定**: 「ユーザーがお気に入り登録できる機能」等
  - **参考URL**: 競合アプリや参考記事のURL（WebFetchで取得）
  - **引数なし**: `AskUserQuestion` でヒアリング

## 実行フロー

```
アイデア
  │
  ▼
┌─────────────────────────┐
│ Step 1: アイデアの具体化   │  ← ヒアリング（必要に応じて）
│ Step 2: PRD作成           │
│ Step 3: GitHub Issue作成  │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ /full-cycle-dev #issue   │  ← 既存フローに合流
│  Block A → B → C         │
└─────────────────────────┘
```

## Step 1: アイデアの具体化

引数が曖昧な場合、`AskUserQuestion` で以下を確認:

1. **対象プラットフォーム**: iOS / Android / 両方
2. **ターゲットユーザー**: 誰が使うか
3. **コア機能**: 最低限実現したいこと（MVP）
4. **既存プロジェクトの有無**: 新規 or 既存リポジトリに追加

引数が十分に具体的であれば、ヒアリングをスキップして Step 2 へ。

## Step 2: PRD作成

アイデアを以下の構造で PRD（Product Requirements Document）に整理:

```markdown
# PRD: [機能名]

## 概要
[1-2文で機能の説明]

## 背景・課題
[なぜこの機能が必要か]

## ユーザーストーリー
- [ ] [ペルソナ]として、[行動]したい。なぜなら[理由]だから。

## 機能要件
- [ ] 要件1
- [ ] 要件2

## 非機能要件
- パフォーマンス: [目標]
- セキュリティ: [考慮事項]
- アクセシビリティ: [基準]

## UI/UX概要
- [画面構成の概要]
- [主要なユーザーフロー]

## 成功基準
- [完了の定義]

## スコープ外
- [今回対応しないもの]
```

## Step 3: GitHub Issue作成

PRD を Issue body として GitHub Issue を作成:

```bash
gh issue create \
  --title "[機能名]" \
  --body "$(cat <<'EOF'
[Step 2 で作成した PRD の内容]
EOF
)" \
  --label "enhancement"
```

作成された Issue 番号を取得。

## Step 4: フルサイクル開発に合流

```
Skill(skill="mobiledev-fullcycle:full-cycle-dev", args="#[Issue番号]")
```

以降は `/full-cycle-dev` の Phase 0-20 が実行されます。

## 実行例

```
/idea-to-app ユーザーがお気に入り登録できる機能
/idea-to-app https://example.com/competitor-feature を参考にしたブックマーク機能
/idea-to-app  # 対話的にヒアリング
```
