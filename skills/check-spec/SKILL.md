---
name: check-spec
description: 仕様の穴や抜け漏れを発見し、実装前に問題を洗い出します。GitHub Issue、ファイルパス、テキスト直接指定に対応。
allowed-tools: Read, Glob, Grep, WebSearch, WebFetch, AskUserQuestion
model: opus
user-invocable: true
argument-hint: [仕様URL/ファイルパス/テキスト] [--quick|--medium|--thorough]
---

# 仕様チェック

`$ARGUMENTS` の仕様を分析し、問題を洗い出します。

## 引数の解析

1. **GitHub Issue/PR URL** (`https://github.com/.../issues/...` or `#123`): `gh api` または `WebFetch` で取得
2. **ファイルパス** (`@path/to/spec.md` or 拡張子付き): `Read` で読み込み
3. **テキスト直接指定**: そのまま使用
4. **引数なし**: `AskUserQuestion` でヒアリング

## スコープオプション

- `--quick`: 基本チェックのみ
- `--medium`: 標準チェック（デフォルト）
- `--thorough`: 徹底分析（関連コード全探索 + PRD照合）

## 実行

引数を解析したら、分析の実行と出力は `spec-analyzer` エージェントの定義に従ってください。
エージェントが持つ分析観点、手順、出力フォーマットをそのまま使用します。
