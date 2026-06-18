# Upstream

このディレクトリは外部プロジェクト android/skills から vendored copy として取り込んでいます。
`vendor/android-skills/` 配下のファイルは直接編集しないでください（このファイルを除く）。
更新は upstream で行い、`scripts/sync-android-skills.sh` を再実行してください。

- Source: https://github.com/android/skills
- Ref: 392fd3bcf28d25c890f48b20fd9a7f680d9bdc64
- Commit: 392fd3bcf28d25c890f48b20fd9a7f680d9bdc64
- License: Apache License 2.0 (see `LICENSE.txt`)
- Copyright: © Google LLC

## 取り込んでいるサブツリー（ラッパー skill と対応）

- `build/agp/agp-9-upgrade` → skills/android-agp-upgrade
- `jetpack-compose/migration/migrate-xml-views-to-jetpack-compose` → skills/android-compose-migration
- `navigation/navigation-3` → skills/android-navigation3
- `performance/r8-analyzer` → skills/android-r8-analyzer
- `play/play-billing-library-version-upgrade` → skills/android-play-billing
- `system/edge-to-edge` → skills/android-edge-to-edge
