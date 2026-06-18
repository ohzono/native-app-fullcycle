# iOS Visual Regression Testing 詳細リファレンス

このドキュメントは [ios-visual-regression-testing SKILL.md](SKILL.md) の詳細リファレンスです。

## swift-snapshot-testing Detailed Examples

### Installation (SPM)
```swift
// Package.swift
dependencies: [
    // 1.17+ 必須: withSnapshotTesting(record:) スコープ API と Swift Testing 統合のため
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
]

// Test target
.testTarget(
    name: "MyAppTests",
    dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ]
)
```

### Basic Usage
```swift
import XCTest
import SnapshotTesting
@testable import MyApp

final class MyViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Disable animations for consistent snapshots
        UIView.setAnimationsEnabled(false)
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        super.tearDown()
    }

    func testMyView() {
        let view = MyView()
        view.configure(with: .sample)

        assertSnapshot(of: view, as: .image(size: CGSize(width: 375, height: 200)))
    }

    func testMyViewController() {
        let vc = MyViewController()

        assertSnapshot(of: vc, as: .image(on: .iPhone13))
    }
}
```

### SwiftUI Snapshot Testing
```swift
import SwiftUI
import SnapshotTesting

final class SwiftUISnapshotTests: XCTestCase {

    func testContentView() {
        let view = ContentView()

        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: .iPhone13),
                traits: .init(userInterfaceStyle: .light)
            )
        )
    }

    func testContentViewDarkMode() {
        let view = ContentView()

        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: .iPhone13),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "dark"
        )
    }

    func testContentViewAccessibility() {
        let view = ContentView()

        // Test with larger text sizes
        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: .iPhone13),
                traits: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge)
            ),
            named: "accessibility-xl"
        )
    }
}
```

### Multiple Device Testing
```swift
final class MultiDeviceSnapshotTests: XCTestCase {

    func testAcrossDevices() {
        let view = ProductCardView(product: .sample)

        let devices: [(name: String, config: ViewImageConfig)] = [
            ("iPhone-SE", .iPhoneSe),
            ("iPhone-13", .iPhone13),
            ("iPhone-13-Pro-Max", .iPhone13ProMax),
            ("iPad-Mini", .iPadMini),
            ("iPad-Pro-12.9", .iPadPro12_9)
        ]

        for (name, config) in devices {
            assertSnapshot(
                of: view,
                as: .image(layout: .device(config: config)),
                named: name
            )
        }
    }
}
```

### State Variations Testing
```swift
final class ButtonStateSnapshotTests: XCTestCase {

    func testButtonStates() {
        let states: [(name: String, configure: (CustomButton) -> Void)] = [
            ("normal", { $0.isEnabled = true; $0.isHighlighted = false }),
            ("highlighted", { $0.isEnabled = true; $0.isHighlighted = true }),
            ("disabled", { $0.isEnabled = false }),
            ("loading", { $0.isLoading = true })
        ]

        for (name, configure) in states {
            let button = CustomButton()
            button.setTitle("Action", for: .normal)
            configure(button)

            assertSnapshot(
                of: button,
                as: .image(size: CGSize(width: 200, height: 50)),
                named: name
            )
        }
    }
}
```

## SwiftUI Preview Testing

### Xcode 16+ Preview Testing（Swift Testing）

> `import Testing`（Swift Testing）は Xcode 16+ / Swift 6 が必要。`@Test` 内で `assertSnapshot` の失敗が正しく報告されるには swift-snapshot-testing 1.17.0 以降（Swift Testing 統合）が必要。

```swift
import Testing
import SwiftUI

@Suite("Preview Snapshot Tests")
struct PreviewSnapshotTests {

    @Test("ContentView previews match snapshots")
    func contentViewPreviews() async throws {
        // Using Swift Testing with snapshot testing
        let previews = [
            ("light", ContentView().environment(\.colorScheme, .light)),
            ("dark", ContentView().environment(\.colorScheme, .dark))
        ]

        for (name, view) in previews {
            assertSnapshot(of: view, as: .image, named: name)
        }
    }
}
```

## Advanced Techniques

### Custom Snapshotting Strategies
```swift
import SnapshotTesting

extension Snapshotting where Value: UIViewController, Format == UIImage {
    static func image(
        on config: ViewImageConfig,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        size: CGSize? = nil,
        traits: UITraitCollection = .init()
    ) -> Snapshotting {
        return SimplySnapshotting.image(
            precision: precision,
            perceptualPrecision: perceptualPrecision
        ).asyncPullback { vc in
            Async { callback in
                // Custom setup before snapshot
                vc.loadViewIfNeeded()
                vc.view.layoutIfNeeded()

                // Wait for async content to load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    callback(vc.view.asImage())
                }
            }
        }
    }
}
```

### Testing with Mock Data
```swift
final class UserProfileSnapshotTests: XCTestCase {

    func testProfileWithMockUser() {
        let mockUser = User(
            id: "1",
            name: "John Doe",
            email: "john@example.com",
            avatarURL: nil,  // Use placeholder
            memberSince: Date(timeIntervalSince1970: 0)  // Fixed date
        )

        let view = UserProfileView(user: mockUser)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
}
```

### Localization Testing
```swift
final class LocalizationSnapshotTests: XCTestCase {

    func testMultipleLanguages() {
        let languages = ["en", "ja", "de", "ar"]  // Including RTL

        for language in languages {
            let bundle = Bundle(forLanguage: language)
            let view = WelcomeView()
                .environment(\.locale, Locale(identifier: language))

            assertSnapshot(
                of: view,
                as: .image(layout: .device(config: .iPhone13)),
                named: language
            )
        }
    }
}
```

### Async Content Testing
```swift
final class AsyncContentSnapshotTests: XCTestCase {

    func testViewWithAsyncContent() async {
        let viewModel = MyViewModel()
        let view = MyView(viewModel: viewModel)

        // Wait for async content to load
        await viewModel.loadData()

        // Give UI time to update
        await MainActor.run {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
}
```

## CI/CD Integration

### GitHub Actions
```yaml
name: Visual Regression Tests

on:
  pull_request:
    branches: [main, develop]

jobs:
  snapshot-tests:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Run Snapshot Tests
        run: |
          xcodebuild test \
            -scheme MyApp \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' \
            -only-testing:MyAppTests/SnapshotTests \
            -resultBundlePath TestResults.xcresult

      - name: Upload Failed Snapshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: failed-snapshots
          path: |
            **/Failures/**
            **/testFailures/**
          retention-days: 7

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
```

### Fastlane Integration
```ruby
# Fastfile
lane :snapshot_tests do
  scan(
    scheme: "MyApp",
    devices: ["iPhone 15"],
    only_testing: ["MyAppTests/SnapshotTests"],
    result_bundle: true,
    output_directory: "./test_output"
  )
end

lane :update_snapshots do
  ENV["RECORD_SNAPSHOTS"] = "1"
  scan(
    scheme: "MyApp",
    devices: ["iPhone 15"],
    only_testing: ["MyAppTests/SnapshotTests"]
  )
end
```

### Handling Snapshot Updates in PRs

> グローバル `isRecording` への代入は 1.17 で deprecated（並列テストを汚染するため）。スコープを限定する `withSnapshotTesting(record:)` か、`assertSnapshot(..., record:)` 引数を使う。

```swift
// TestConfiguration.swift
enum SnapshotTestConfiguration {
    static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }
}

// XCTest: テスト単位でスコープを限定して record モードを適用
final class SnapshotTests: XCTestCase {
    func testProductCard() {
        withSnapshotTesting(record: SnapshotTestConfiguration.recordMode) {
            assertSnapshot(of: view, as: .image)
        }
    }
}

// 単発の再記録は assertSnapshot の引数でも指定できる
assertSnapshot(of: view, as: .image, record: .all)
```

## Handling Flaky Tests

```swift
final class StableSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()

        // Disable animations
        UIView.setAnimationsEnabled(false)

        // Use fixed date for time-sensitive UI
        DateProvider.current = MockDateProvider(fixedDate: Date(timeIntervalSince1970: 0))

        // Disable caret blinking in text fields
        UITextInputTraits.caretBlinkingEnabled = false
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        DateProvider.current = SystemDateProvider()
        UITextInputTraits.caretBlinkingEnabled = true
        super.tearDown()
    }
}
```

## Troubleshooting

### 1. Snapshots differ across CI and local
```swift
// Always specify exact device and OS version
assertSnapshot(
    of: view,
    as: .image(
        layout: .device(config: .iPhone13),
        traits: UITraitCollection(displayScale: 3.0)
    )
)
```

### 2. Dynamic content causing failures
```swift
// Mock all dynamic content
struct SnapshotEnvironment {
    static func setup() {
        // Fixed date
        DateFormatter.shared.timeZone = TimeZone(identifier: "UTC")

        // Fixed random seed
        srand48(0)

        // Placeholder images
        ImageLoader.shared.usePlaceholders = true
    }
}
```

### 3. Memory issues with many snapshots
```swift
override func tearDown() {
    // Clear image cache after each test
    SDImageCache.shared.clearMemory()
    super.tearDown()
}
```

## Integration with Design Tools

### Figma Token Validation
```swift
final class DesignTokenSnapshotTests: XCTestCase {

    func testColorTokens() {
        let colors: [(name: String, color: UIColor)] = [
            ("primary", .primaryBrand),
            ("secondary", .secondaryBrand),
            ("error", .errorRed),
            ("success", .successGreen)
        ]

        for (name, color) in colors {
            let swatch = ColorSwatchView(color: color, name: name)
            assertSnapshot(of: swatch, as: .image, named: name)
        }
    }

    func testTypographyTokens() {
        let styles: [(name: String, font: UIFont)] = [
            ("heading1", .heading1),
            ("heading2", .heading2),
            ("body", .body),
            ("caption", .caption)
        ]

        for (name, font) in styles {
            let label = UILabel()
            label.text = "Typography Sample"
            label.font = font
            label.sizeToFit()

            assertSnapshot(of: label, as: .image, named: name)
        }
    }
}
```
