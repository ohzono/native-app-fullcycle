# KMP + iOS + Android テンプレート

フルサイクル開発の Phase 0 でコピーされる最小構成テンプレート。

## 構成

- **shared/** — Kotlin Multiplatform 共有モジュール（Android + iOS ターゲット）
- **androidApp/** — Android アプリ（shared を利用）
- **iosApp/** — iOS アプリ（Tuist で管理、`Project.swift` から生成）

## バージョン

- Kotlin: 2.1.0
- AGP: 8.7.3
- Android compileSdk: 35 / minSdk: 24
- iOS deploymentTarget: 15.0

## セットアップ

worktree にコピー後、以下で検証：

```bash
# Android / shared
./gradlew :shared:build

# iOS (Tuist 必要)
cd iosApp && tuist generate
```
