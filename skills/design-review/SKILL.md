---
name: design-review
description: UI/UXデザインレビューを実施します。スクリーンショット必須で、ユーザビリティ、アクセシビリティ（WCAG 2.1）、ビジュアルデザインを包括的にチェックします。
allowed-tools: Read, Glob, Grep, Bash(sips *), Bash(git *), AskUserQuestion
model: opus
user-invocable: true
argument-hint: "[ファイルパス or コンポーネント名] [--screenshot=スクリーンショットパス]"
---

# デザインレビュー

指定された対象「$ARGUMENTS」に対して、UI/UXの観点からデザインレビューを実施します。

**重要**: デザインレビューには必ず画面のスクリーンショットが必要です。

## 引数について

- **ファイルパス指定**: 該当コンポーネントを直接レビュー
- **コンポーネント名指定**: プロジェクト内を検索してレビュー
- **--screenshot=パス**: スクリーンショット画像を指定（複数可）
- **指定なし**: UIコンポーネントディレクトリ全体をレビュー

## スクリーンショットの取得

1. `--screenshot=` で指定されていれば Read で読み込み
2. 指定なしの場合、VRTスナップショットディレクトリ（`__Snapshots__`, `snapshots/`）を検索
3. 見つからない場合、`AskUserQuestion` でパスを要求
4. 提供されない場合、レビューを中止

## 実行

スクリーンショットを取得したら、レビューの実行と出力は `design-reviewer` エージェントの定義に従ってください。

## 実行例

```
/design-review src/components/Button.tsx --screenshot=screenshots/button.png
/design-review Header
/design-review src/components/
```
