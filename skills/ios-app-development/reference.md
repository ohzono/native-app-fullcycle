# iOS App Development 詳細リファレンス

このドキュメントは [ios-app-development SKILL.md](SKILL.md) の詳細リファレンスです。

## UIKit (Legacy/Advanced)

### View Controllers
```swift
class ViewController: UIViewController {
    private let tableView = UITableView()
    private var data: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadData() {
        // Load data
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Handle selection
    }
}
```

## Core Data

### Setup
```swift
import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}

// SwiftUI usage
@main
struct MyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}

// Fetch data
struct ItemListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    var body: some View {
        List {
            ForEach(items) { item in
                Text(item.name ?? "")
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            Button(action: addItem) {
                Label("Add", systemImage: "plus")
            }
        }
    }

    private func addItem() {
        let newItem = Item(context: viewContext)
        newItem.timestamp = Date()
        newItem.name = "New Item"

        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        offsets.map { items[$0] }.forEach(viewContext.delete)

        do {
            try viewContext.save()
        } catch {
            print("Error deleting: \(error)")
        }
    }
}
```

## Networking

### URLSession with Combine（iOS 16 以前 / Combine 既存コード向け）

> 新規コードでは async/await + `@Observable` を優先する（SKILL.md の「Modern Async/Await」と「State Management」を参照）。以下は Combine に依存する既存コードや、リアクティブな合成が必要な場合のパターン。

```swift
import Combine

class NetworkManager {
    private var cancellables = Set<AnyCancellable>()

    func fetchUsers() -> AnyPublisher<[User], Error> {
        let url = URL(string: "https://api.example.com/users")!

        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [User].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// Usage in ViewModel
class UserViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false

    private let networkManager = NetworkManager()
    private var cancellables = Set<AnyCancellable>()

    func loadUsers() {
        isLoading = true

        networkManager.fetchUsers()
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("Error: \(error)")
                }
            } receiveValue: { [weak self] users in
                self?.users = users
            }
            .store(in: &cancellables)
    }
}
```

## Push Notifications

### Setup
```swift
import UserNotifications

class NotificationManager: NSObject {
    static let shared = NotificationManager()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func scheduleLocalNotification(title: String, body: String, timeInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}

// AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestAuthorization()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device token: \(token)")
        // Send to server
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        completionHandler()
    }
}
```

## In-App Purchases

### StoreKit 2
StoreKit 2 は async/await ネイティブのため、状態管理も iOS 17+ の `@Observable` を使う（Combine 非依存）。

```swift
import StoreKit

enum ProductID: String, CaseIterable {
    case premium = "com.example.premium"
    case subscription = "com.example.subscription"
}

@MainActor
@Observable
class StoreManager {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []

    private var updates: Task<Void, Never>?

    init() {
        updates = observeTransactionUpdates()
    }

    deinit {
        // Task.cancel() は nonisolated に呼べるため、@MainActor 隔離下の
        // deinit からでも安全にキャンセルできる（Swift 6 言語モードでも警告なし）
        updates?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()

        case .userCancelled, .pending:
            break

        @unknown default:
            break
        }
    }

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await updatePurchasedProducts()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
```

## Testing

### Unit Tests
```swift
import XCTest
@testable import MyApp

class ViewModelTests: XCTestCase {
    var viewModel: UserViewModel!

    override func setUp() {
        super.setUp()
        viewModel = UserViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testLoadUsers() async {
        await viewModel.loadUsers()
        XCTAssertFalse(viewModel.users.isEmpty)
    }
}

// UI Testing
class MyAppUITests: XCTestCase {
    func testLoginFlow() {
        let app = XCUIApplication()
        app.launch()

        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("test@example.com")

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("password123")

        app.buttons["Login"].tap()

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5))
    }
}
```

## MECE Analysis for iOS Apps

### 1. Functionality
- Feature completeness per iOS version
- Apple framework API usage appropriateness
- Device compatibility (iPhone, iPad, Mac Catalyst)

### 2. Performance
- App launch time (400ms target)
- Smooth scrolling (60fps/120fps ProMotion)
- Memory footprint and management
- Battery and thermal efficiency

### 3. User Experience
- HIG compliance (navigation, layout, typography)
- Touch target sizes (44pt minimum)
- Accessibility (VoiceOver, Dynamic Type, Reduce Motion)
- Dark Mode and tint color support

### 4. Quality & Maintainability
- XCTest coverage (Unit, UI, Performance)
- SwiftUI preview support
- Xcode Instruments profiling
- TestFlight beta testing

## Discussion Characteristics

### Discussion Stance
- **HIG-First**: Follow Apple's design principles
- **Platform-Native**: Leverage iOS-specific patterns
- **Performance-Obsessed**: Maintain 60fps, minimize battery drain
- **Privacy-Conscious**: Follow Apple's privacy requirements

### Typical Discussion Points
- "SwiftUI vs UIKit" adoption strategy
- "Pure Swift vs Objective-C bridging" considerations
- "Native vs cross-platform" for iOS development
- "App size vs features" tradeoffs for App Store

### Evidence Sources
- Apple Developer Documentation
- Human Interface Guidelines (HIG)
- WWDC sessions and sample code
- App Store Review Guidelines
- Swift Evolution proposals

### Strengths in Discussion
- Deep iOS platform knowledge
- SwiftUI and UIKit expertise
- HIG implementation
- Apple frameworks integration
- App Store compliance

### Potential Biases
- May favor Apple ecosystem over cross-platform
- Could overlook Android patterns beneficial for UX
- Might prioritize latest iOS features over backwards compatibility
- May underestimate non-Apple platform development challenges
