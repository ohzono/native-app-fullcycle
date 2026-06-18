# NOTICE

本プラグイン（mobiledev-fullcycle, MIT License）は以下のサードパーティ資産を同梱しています。

## android/skills

- Source: https://github.com/android/skills
- 同梱方法: vendored copy (`vendor/android-skills/`)。ラッパー skill が参照する 6 サブツリーのみを実ファイルとして同梱（marketplace の github source インストールでもそのまま含まれる）。
- Pinned commit: `392fd3bcf28d25c890f48b20fd9a7f680d9bdc64`（`vendor/android-skills/UPSTREAM.md` 参照）
- 同期スクリプト: `scripts/sync-android-skills.sh`
- License: Apache License 2.0
- Copyright: © Google LLC
- ライセンス本文: `vendor/android-skills/LICENSE.txt`

本プラグインでは `skills/` 配下にラッパー skill を作成し、vendor の SKILL.md を `${CLAUDE_PLUGIN_ROOT}/vendor/android-skills/...` の Read 指示で参照しています:

- `android-agp-upgrade` → `vendor/android-skills/build/agp/agp-9-upgrade/`
- `android-compose-migration` → `vendor/android-skills/jetpack-compose/migration/migrate-xml-views-to-jetpack-compose/`
- `android-navigation3` → `vendor/android-skills/navigation/navigation-3/`
- `android-r8-analyzer` → `vendor/android-skills/performance/r8-analyzer/`
- `android-play-billing` → `vendor/android-skills/play/play-billing-library-version-upgrade/`
- `android-edge-to-edge` → `vendor/android-skills/system/edge-to-edge/`

## twostraws/SwiftUI-Agent-Skill

- Source: https://github.com/twostraws/SwiftUI-Agent-Skill
- 同梱方法: vendored copy (`skills/swiftui-pro/`)
- Pinned commit: `61b74001b64b292da8397355464d7c8a4c2c7d89`（`skills/swiftui-pro/UPSTREAM.md` 参照）
- 同期スクリプト: `scripts/sync-swiftui-pro.sh`
- License: MIT
- Author: Paul Hudson (@twostraws)
- ライセンス本文: `skills/swiftui-pro/UPSTREAM_LICENSE`

## Gradle wrapper

- Source: https://github.com/gradle/gradle
- 同梱方法: KMP テンプレート (`templates/kmp-ios-android/`) に `gradlew` / `gradlew.bat` / `gradle/wrapper/gradle-wrapper.jar` / `gradle/wrapper/gradle-wrapper.properties` を同梱
- License: Apache License 2.0
- Copyright: © 2015-2021 the original authors（同梱 `gradlew` のヘッダ表記に準拠）
- ライセンス本文: `templates/kmp-ios-android/gradle/wrapper/LICENSE`（Apache-2.0 本文を実ファイルとして同梱。upstream: https://github.com/gradle/gradle/blob/master/LICENSE ）
