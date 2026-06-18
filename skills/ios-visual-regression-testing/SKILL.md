---
name: ios-visual-regression-testing
description: swift-snapshot-testingとXCTestプレビューテストを使用したiOS Visual Regression Testingの専門知識。視覚的UI検証のためのCI/CD統合。iOSスナップショットテストの設計・実装、VRTカバレッジ改善、CI/CDへのVRT統合時に使用します。
model: opus
allowed-tools: Read, Glob, Edit, Write, WebSearch, Bash
user-invocable: false
---

# iOS Visual Regression Testing Skill

## Overview
Comprehensive expertise in implementing Visual Regression Testing (VRT) for iOS applications. This includes snapshot testing, preview testing, pixel-perfect comparison, and CI/CD pipeline integration for automated visual verification.

## Why Visual Regression Testing?

### Benefits
- **Catch Unintended UI Changes**: Detect visual regressions before they reach production
- **Design System Consistency**: Ensure UI components match design specifications
- **Refactoring Confidence**: Safely refactor UI code with visual verification
- **Cross-Device Validation**: Test across different device sizes and configurations
- **Documentation**: Snapshots serve as visual documentation of UI states

### When to Use
- Component library development
- Design system implementation
- UI refactoring projects
- Accessibility testing (Dynamic Type, Dark Mode)
- Multi-device support verification

## Snapshot Testing Frameworks

### swift-snapshot-testing (Point-Free)

The most popular and flexible snapshot testing library for Swift.

```swift
// SPM: .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
// 1.17+ 必須: withSnapshotTesting(record:) スコープ API と Swift Testing 統合のため

import SnapshotTesting

// UIKit view
assertSnapshot(of: view, as: .image(size: CGSize(width: 375, height: 200)))

// SwiftUI view
assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .light)))

// Dark mode
assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .dark)), named: "dark")

// Accessibility
assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13),
    traits: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge)), named: "accessibility-xl")

// Multiple devices
for (name, config) in [("iPhone-SE", ViewImageConfig.iPhoneSe), ("iPhone-13", .iPhone13), ("iPad-Pro", .iPadPro12_9)] {
    assertSnapshot(of: view, as: .image(layout: .device(config: config)), named: name)
}

// Perceptual precision (anti-aliasing tolerance)
assertSnapshot(of: view, as: .image(precision: 0.99, perceptualPrecision: 0.98))
```

## Best Practices

### Directory Structure
```
MyApp/
├── MyAppTests/
│   ├── SnapshotTests/
│   │   ├── __Snapshots__/           # Reference images
│   │   ├── MyViewTests.swift
│   │   └── SnapshotTestCase.swift   # Base class
│   └── UnitTests/
```

### Naming Convention
```swift
// Format: test[Component]_[state]_[variant]
func testProductCard_default() { }
func testProductCard_onSale() { }
func testProductCard_darkMode() { }
func testProductCard_accessibilityXL() { }
```

### Handling Flaky Tests
- Disable animations: `UIView.setAnimationsEnabled(false)`
- Use fixed dates: `DateProvider.current = MockDateProvider(fixedDate: ...)`
- Disable caret blinking in text fields
- Mock all dynamic content (images, timestamps, random values)
- Always specify exact device and OS version

### CI/CD Integration Key Points
- Use `macos-14` runner with specific Xcode version
- Upload failed snapshots as artifacts on failure
- Support `RECORD_SNAPSHOTS` environment variable for update workflow

## Verification Checklist
- [ ] All UI states have corresponding snapshots
- [ ] Dark mode variants tested
- [ ] Accessibility sizes tested (Dynamic Type)
- [ ] Multiple device sizes covered
- [ ] RTL languages tested if applicable
- [ ] CI/CD pipeline integration complete

## Evidence-First Visual Testing

**Core Belief**: "Visual regression testing provides objective evidence of UI consistency and prevents unintended design changes"

### Standards Compliance
- Apple Human Interface Guidelines visual specifications
- Accessibility requirements (WCAG contrast ratios)
- Design system documentation
- Platform-specific rendering requirements

## When to Use This Skill
- Setting up snapshot testing infrastructure
- Creating visual regression tests for UI components
- Integrating VRT into CI/CD pipelines
- Debugging flaky snapshot tests
- Testing design system components
- Multi-device and accessibility visual testing
- Localization visual verification

## 詳細リファレンス

より詳細な技術リファレンス、コード例、チェックリストは [reference.md](reference.md) を参照してください。
