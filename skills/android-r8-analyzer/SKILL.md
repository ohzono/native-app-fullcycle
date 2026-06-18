---
name: android-r8-analyzer
description: R8 keep ルールの冗長性分析とアプリサイズ最適化。ProGuard 設定のトラブルシューティングを提供します。
model: sonnet
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
user-invocable: false
---

# Android R8 Analyzer Skill

Google 公式 android/skills (Apache 2.0, Google LLC) のラッパースキルです。

**作業開始前に、以下のファイルを Read ツールで読み込んでください:**

1. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/performance/r8-analyzer/SKILL.md` — メインのワークフロー定義
2. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/performance/r8-analyzer/references/` — 参照ドキュメント群（SKILL.md 内で明示的に参照されるため必読）。ディレクトリは直接 Read できないため、Glob で一覧してから個別に Read してください
