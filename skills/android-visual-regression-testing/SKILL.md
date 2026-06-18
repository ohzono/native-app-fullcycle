---
name: android-visual-regression-testing
description: Compose Preview Screenshot Testing（Google公式）を使用したAndroid Visual Regression Testingの専門知識。エミュレータ不要のピクセルパーフェクトなUI検証、CI/CD統合。Androidスナップショットテストの設計・実装、VRTカバレッジ改善、CI/CDへのVRT統合時に使用します。
model: opus
allowed-tools: Read, Glob, Edit, Write, WebSearch, Bash
user-invocable: false
---

# Android Visual Regression Testing Skill

## Overview
Comprehensive expertise in implementing Visual Regression Testing (VRT) for Android applications. This includes snapshot testing with Compose Preview Screenshot Testing (Google official), enabling fast UI verification without emulators.

## Why Visual Regression Testing?

### Benefits
- **No Emulator Required**: Compose Preview Screenshot Testing runs on JVM for fast feedback without emulators
- **Catch UI Regressions Early**: Detect unintended visual changes before release
- **Design System Validation**: Ensure components match design specifications
- **Refactoring Safety**: Confidently refactor UI code with visual verification
- **Multi-Configuration Testing**: Dark mode, locales, font scales in one test run

### When to Use
- Jetpack Compose component development
- Material Design 3 implementation
- Design system/component library projects
- UI refactoring initiatives
- Accessibility visual testing
- Multi-theme support verification

## Compose Preview Screenshot Testing

Official Google library for testing Compose Previews. Runs entirely on JVM without emulators.

```kotlin
// Installation: id("com.android.compose.screenshot") version "0.0.1-alpha15"
// バージョン追従ポリシー: 本ライブラリは alpha 段階で API が変わり得る。導入時は
// https://developer.android.com/studio/preview/compose-screenshot-testing-release-notes
// で最新安定 alpha を確認して置き換えること。
// 画像比較の validation-api は plugin が内部解決するため、通常は明示依存不要。
// build.gradle.kts
android {
    experimentalProperties["android.experimental.enableScreenshotTest"] = true
}
dependencies {
    screenshotTestImplementation("androidx.compose.ui:ui-tooling")
}

// テスト作成: src/screenshotTest/kotlin/ に配置
@Preview(name = "Light", showBackground = true)
@Preview(name = "Dark", showBackground = true, uiMode = UI_MODE_NIGHT_YES)
@Composable
fun ProductCardPreview() {
    AppTheme { ProductCard(product = Product.sample()) }
}

// フォントスケール
@Preview(name = "Large Font", fontScale = 1.5f, showBackground = true)
@Composable
fun ProductCardLargeFontPreview() {
    AppTheme { ProductCard(product = Product.sample()) }
}

// Gradle commands
// Record:  ./gradlew updateDebugScreenshotTest
// Verify:  ./gradlew validateDebugScreenshotTest
```

## Best Practices

### Test Naming Convention

Compose Preview Screenshot Testing は `@Preview` 付き Composable 関数を対象とする（`@Test` メソッドは検出されない）。命名は Preview 関数名で表現する:

```kotlin
// Format: ComponentName + State + Preview（@Preview 関数名ベース）
@Preview @Composable fun ProductCardDefaultPreview() { /* ... */ }
@Preview @Composable fun ProductCardOnSalePreview() { /* ... */ }
@Preview @Composable fun ProductCardDarkThemePreview() { /* ... */ }
@Preview @Composable fun ProductCardLargeFontScalePreview() { /* ... */ }
```

> `@Test fun productCard_default()` のような命名は Paparazzi / Roborazzi 等の手動キャプチャ API の流儀であり、本ライブラリでは使わない。

### Handling Dynamic Content
- Use fixed test data (fixed dates, placeholder images)
- Use `PreviewParameterProvider` for consistent test data
- Use `FakeImageLoader` for image loading tests

### Handling Flaky Tests
- Use `LocalInspectionMode provides true` to disable animations
- Include Android resources: `isIncludeAndroidResources = true`

### CI/CD Key Points
- Compose Preview Screenshot Testing runs on `ubuntu-latest` (no emulator needed)
- Upload failed snapshots as artifacts on failure

## Verification Checklist
- [ ] All UI components have snapshot coverage
- [ ] Dark/Light theme variants tested
- [ ] Font scale variations tested (1.0x, 1.5x, 2.0x)
- [ ] Multiple screen sizes covered (phone, tablet, foldable)
- [ ] RTL layouts tested for internationalization
- [ ] CI/CD pipeline integration complete
- [ ] Snapshot update process documented

## Evidence-First Visual Testing

**Core Belief**: "Visual regression testing provides objective evidence of UI consistency and enables confident UI refactoring"

### Standards Compliance
- Material Design 3 visual specifications
- Android accessibility guidelines (contrast ratios, touch targets)
- Design system documentation
- Platform-specific rendering requirements

## When to Use This Skill
- Setting up Android snapshot testing (Compose Preview Screenshot Testing)
- Creating visual regression tests for Compose components
- Testing Material Design 3 theme implementations
- Multi-device and accessibility visual testing
- CI/CD integration for visual verification
- Debugging flaky snapshot tests
- Design system component validation
- Localization visual verification

## 詳細リファレンス

より詳細な技術リファレンス、コード例、チェックリストは [reference.md](reference.md) を参照してください。
