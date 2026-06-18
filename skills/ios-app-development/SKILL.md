---
name: ios-app-development
description: SwiftUI、UIKit、iOSフレームワーク、App Storeガイドライン、iOS固有パターンを使用したiOSアプリケーション開発の専門知識。Human Interface Guidelines、宣言的UI、iOSプラットフォームのベストプラクティス。iOSアプリの設計・実装、SwiftUI/UIKitでのUI構築、iOSフレームワーク活用時に使用します。
model: opus
allowed-tools: Read, Glob, Edit, Write, WebSearch, Bash
user-invocable: false
---

# iOS App Development Skill

## Overview
Comprehensive expertise in developing native iOS applications using SwiftUI, UIKit, and iOS frameworks following Apple's best practices and Human Interface Guidelines.

## SwiftUI

### Basic Views
```swift
import SwiftUI

struct ContentView: View {
    @State private var name = ""
    @State private var isPresented = false

    var body: some View {
        VStack(spacing: 20) {
            // Text
            Text("Hello, World!")
                .font(.title)
                .foregroundColor(.blue)

            // Image
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.yellow)

            // TextField
            TextField("Enter name", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding()

            // Button
            Button("Show Sheet") {
                isPresented = true
            }
            .buttonStyle(.borderedProminent)

            // List
            List(0..<5) { index in
                Text("Item \(index)")
            }
        }
        .padding()
        .sheet(isPresented: $isPresented) {
            DetailView()
        }
    }
}
```

### State Management
```swift
// @State - Local view state
struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") {
                count += 1
            }
        }
    }
}

// @Binding - Two-way binding
struct ChildView: View {
    @Binding var text: String

    var body: some View {
        TextField("Enter text", text: $text)
    }
}

struct ParentView: View {
    @State private var text = ""

    var body: some View {
        ChildView(text: $text)
    }
}

// =============================================================
// 推奨（iOS 17+）: Observation framework — @Observable
// 新規コードの参照型状態は @Observable クラスを第一選択にする。
// @Published / objectWillChange は不要で、view が実際に参照した
// プロパティだけが更新をトリガーするため再レンダリングが最小化される。
// =============================================================

// @Observable クラスは @MainActor を付ける
// （プロジェクトが Main Actor default isolation でない限り必須）
@MainActor
@Observable
class ViewModel {
    var items: [String] = []
    var query = ""
    var isLoading = false

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        // Fetch data
    }
}

// @State - @Observable インスタンスの「所有」（生成して保持する）
struct RootView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        DataView(viewModel: viewModel)
    }
}

// 子 view へは素のプロパティとして渡す（@ObservedObject 注釈は不要）
struct DataView: View {
    let viewModel: ViewModel

    var body: some View {
        List(viewModel.items, id: \.self) { item in
            Text(item)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

// @Bindable - 双方向バインド（$ で binding を取り出す）
struct SearchView: View {
    @Bindable var viewModel: ViewModel

    var body: some View {
        TextField("Search", text: $viewModel.query)
    }
}

// @Environment - view 階層で共有（@EnvironmentObject の後継）
// 共有する型（AppSettings）も @Observable クラスにする
@main
struct MyApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        // binding が必要な場合はローカルで @Bindable 化する
        @Bindable var settings = settings
        Toggle("Dark Mode", isOn: $settings.isDarkMode)
    }
}

// =============================================================
// iOS 16 以前 / 既存コードのメンテナンス向け: ObservableObject
// iOS 17 未満をサポートする場合や、Combine 連携など @Observable へ
// 移行しづらい既存コードでのみ使用する。新規コードでは上記の
// @Observable + @State / @Bindable / @Environment を優先すること。
// =============================================================

// @ObservedObject - 外部から渡される参照型（iOS 16 以前）
class LegacyViewModel: ObservableObject {
    @Published var items: [String] = []
    @Published var isLoading = false

    func loadData() async {
        isLoading = true
        // Fetch data
        isLoading = false
    }
}

struct LegacyDataView: View {
    @ObservedObject var viewModel: LegacyViewModel

    var body: some View {
        List(viewModel.items, id: \.self) { item in
            Text(item)
        }
    }
}

// @StateObject - ObservableObject を生成して所有（iOS 16 以前）
struct LegacyRootView: View {
    @StateObject private var viewModel = LegacyViewModel()

    var body: some View {
        LegacyDataView(viewModel: viewModel)
    }
}

// @EnvironmentObject - view 階層で共有（iOS 16 以前）
struct LegacySettingsView: View {
    @EnvironmentObject var settings: LegacyAppSettings

    var body: some View {
        Toggle("Dark Mode", isOn: $settings.isDarkMode)
    }
}

// @AppStorage - UserDefaults
struct PreferencesView: View {
    @AppStorage("username") private var username = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        Form {
            TextField("Username", text: $username)
            Toggle("Notifications", isOn: $notificationsEnabled)
        }
    }
}
```

### Navigation
```swift
// NavigationStack (iOS 16+)
struct NavigationExample: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(1...10, id: \.self) { number in
                NavigationLink(value: number) {
                    Text("Item \(number)")
                }
            }
            .navigationDestination(for: Int.self) { number in
                DetailView(number: number)
            }
            .navigationTitle("Items")
        }
    }
}

// TabView
struct TabViewExample: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}
```

### Modern Async/Await
```swift
struct UserListView: View {
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        List(users) { user in
            UserRow(user: user)
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadUsers()
        }
        .refreshable {
            await loadUsers()
        }
    }

    func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            users = try await APIClient.shared.fetchUsers()
        } catch {
            self.error = error
        }
    }
}

// API Client with async/await
actor APIClient {
    static let shared = APIClient()

    func fetchUsers() async throws -> [User] {
        let url = URL(string: "https://api.example.com/users")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([User].self, from: data)
    }

    func createUser(_ user: User) async throws -> User {
        let url = URL(string: "https://api.example.com/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(user)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(User.self, from: data)
    }
}
```

## Best Practices

### Architecture
- **MVVM**: Recommended for SwiftUI apps
- **Clean Architecture**: For complex apps
- **Coordinator Pattern**: For navigation management
- **Repository Pattern**: For data access

### Performance
- 参照型の状態管理は iOS 17+ では `@Observable` クラス + `@State`（所有）を優先する。`@StateObject` は iOS 16 以前の `ObservableObject` を生成・所有する場合に使う
- Prefer `LazyVStack`/`LazyHStack` for large lists
- Implement pagination for large data sets
- Use `Task` for async operations
- Cache images and network responses
- Profile with Instruments

### Security
- Store sensitive data in Keychain
- Use App Transport Security (HTTPS)
- Implement certificate pinning for critical APIs
- Validate user input
- Use biometric authentication (Face ID/Touch ID)

### App Store Guidelines
- Follow Human Interface Guidelines
- Provide privacy policy
- Implement App Tracking Transparency (ATT)
- Use Sign in with Apple if offering third-party login
- Optimize for all device sizes
- Support dark mode
- Provide app icons for all required sizes
- Write clear app description and screenshots

## Evidence-First iOS Development

**Core Belief**: "Apple's ecosystem coherence ensures premium user experience; HIG compliance drives platform consistency"

### Standards Compliance
- Apple Developer Documentation and official guidelines
- Human Interface Guidelines (HIG) for iOS, iPadOS, watchOS
- App Store Review Guidelines
- SwiftUI and UIKit best practices
- Swift API Design Guidelines

### Proven Patterns Application
- Apple's recommended architecture patterns (MVVM, TCA)
- Official Swift concurrency (async/await, actors)
- Combine framework reactive patterns（リアクティブな合成が必要な特定ケース向け。標準の状態管理は iOS 17+ の Observation = `@Observable` を使う）
- iOS accessibility best practices (VoiceOver, Dynamic Type)

## Trigger Phrases

This skill activates for:
- "iOS", "SwiftUI", "UIKit", "Xcode"
- "Human Interface Guidelines", "HIG", "App Store"
- "Combine", "Core Data", "CloudKit", "WidgetKit"
- "TestFlight", "App Store Connect", "iOS testing"

## When to Use This Skill
- Building iOS applications with SwiftUI or UIKit
- Implementing iOS-specific features
- Working with iOS frameworks (Core Data, Combine, etc.)
- App Store submission and guidelines
- iOS performance optimization
- iOS app architecture decisions
- Push notifications and in-app purchases
- iOS testing strategies

## 詳細リファレンス

より詳細な技術リファレンス、コード例、チェックリストは [reference.md](reference.md) を参照してください。
