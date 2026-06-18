---
name: android-compose-migration
description: XML View から Jetpack Compose への構造化マイグレーション。テーマ・レイアウト移行、検証、XMLクリーンアップを提供します。
model: sonnet
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
user-invocable: false
---

# Android Compose Migration Skill

Google 公式 android/skills (Apache 2.0, Google LLC) のラッパースキルです。

**作業開始前に、以下のファイルを Read ツールで読み込んでください:**

1. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/jetpack-compose/migration/migrate-xml-views-to-jetpack-compose/SKILL.md` — メインのワークフロー定義
2. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/jetpack-compose/migration/migrate-xml-views-to-jetpack-compose/references/` — 参照ドキュメント群。ディレクトリは直接 Read できないため、Glob で一覧してから必要なファイルを Read してください
