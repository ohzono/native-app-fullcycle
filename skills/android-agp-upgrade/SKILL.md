---
name: android-agp-upgrade
description: Android Gradle Plugin (AGP) 9 へのアップグレードガイド。移行手順、互換性チェック、ビルド設定更新を提供します。
model: sonnet
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
user-invocable: false
---

# Android AGP 9 Upgrade Skill

Google 公式 android/skills (Apache 2.0, Google LLC) のラッパースキルです。

**作業開始前に、以下のファイルを Read ツールで読み込んでください:**

1. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/build/agp/agp-9-upgrade/SKILL.md` — メインのワークフロー定義
2. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/build/agp/agp-9-upgrade/references/` — 参照ドキュメント群。ディレクトリは直接 Read できないため、Glob で一覧してから必要なファイルを Read してください
