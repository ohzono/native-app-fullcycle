---
name: android-play-billing
description: Google Play Billing Library のバージョンアップグレードガイド。レガシー PBL から最新安定版への移行手順を提供します。
model: sonnet
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
user-invocable: false
---

# Android Play Billing Skill

Google 公式 android/skills (Apache 2.0, Google LLC) のラッパースキルです。

**作業開始前に、以下のファイルを Read ツールで読み込んでください:**

1. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/play/play-billing-library-version-upgrade/SKILL.md` — メインのワークフロー定義
2. `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/play/play-billing-library-version-upgrade/references/` — 参照ドキュメント群。ディレクトリは直接 Read できないため、Glob で一覧してから必要なファイルを Read してください
