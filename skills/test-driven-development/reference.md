# TDD コード例リファレンス

このドキュメントは [SKILL.md](SKILL.md) の補足として、プラットフォーム別のコード例を提供します。
概念・原則については SKILL.md を参照してください。

---

## iOS (Swift) TDD セッション例

### ユニットテスト: ViewModel のテスト

```swift
// 🔴 Red: テストを先に書く
import XCTest
@testable import MyApp

final class UserViewModelTests: XCTestCase {
    func test_fetchUser_success_updatesUserName() async {
        // Arrange
        let stubRepository = StubUserRepository(result: .success(User(name: "Alice")))
        let viewModel = UserViewModel(repository: stubRepository)

        // Act
        await viewModel.fetchUser(id: "123")

        // Assert
        XCTAssertEqual(viewModel.userName, "Alice")
    }

    func test_fetchUser_failure_setsErrorMessage() async {
        // Arrange
        let stubRepository = StubUserRepository(result: .failure(NSError(domain: "", code: 0)))
        let viewModel = UserViewModel(repository: stubRepository)

        // Act
        await viewModel.fetchUser(id: "123")

        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
```

### Fake It → Triangulation の流れ

```swift
// 🔴 Red
func test_discount_forPremiumUser_returns20Percent() {
    let calculator = DiscountCalculator()
    XCTAssertEqual(calculator.calculate(price: 1000, userType: .premium), 200)
}

// 🟢 Green: Fake it
struct DiscountCalculator {
    func calculate(price: Int, userType: UserType) -> Int {
        return 200 // Fake it!
    }
}

// 🔴 Red: Triangulation（別の角度からテスト）
func test_discount_forRegularUser_returns10Percent() {
    let calculator = DiscountCalculator()
    XCTAssertEqual(calculator.calculate(price: 1000, userType: .regular), 100)
}

// 🟢 Green: 一般化が必要になる
struct DiscountCalculator {
    func calculate(price: Int, userType: UserType) -> Int {
        switch userType {
        case .premium: return price * 20 / 100
        case .regular: return price * 10 / 100
        case .guest:   return 0
        }
    }
}
```

### Repository パターンでのテストダブル

```swift
// Protocol 定義
protocol UserRepository {
    func findById(_ id: String) async throws -> User
    func save(_ user: User) async throws
}

// Stub: 事前定義した値を返す
final class StubUserRepository: UserRepository {
    let result: Result<User, Error>

    init(result: Result<User, Error>) {
        self.result = result
    }

    func findById(_ id: String) async throws -> User {
        try result.get()
    }

    func save(_ user: User) async throws {}
}

// Fake: インメモリ実装（状態を保持）
final class FakeUserRepository: UserRepository {
    private var storage: [String: User] = [:]

    func findById(_ id: String) async throws -> User {
        guard let user = storage[id] else {
            throw RepositoryError.notFound
        }
        return user
    }

    func save(_ user: User) async throws {
        storage[user.id] = user
    }
}

// Spy: 呼び出しを記録
final class SpyUserRepository: UserRepository {
    private(set) var savedUsers: [User] = []
    private(set) var findByIdCallCount = 0

    func findById(_ id: String) async throws -> User {
        findByIdCallCount += 1
        return User(id: id, name: "Test")
    }

    func save(_ user: User) async throws {
        savedUsers.append(user)
    }
}
```

---

## Android (Kotlin) TDD セッション例

### ユニットテスト: ViewModel のテスト

```kotlin
// 🔴 Red: テストを先に書く
class UserViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun `fetchUser success updates userName`() = runTest {
        // Arrange
        val stubRepository = StubUserRepository(Result.success(User(name = "Alice")))
        val viewModel = UserViewModel(stubRepository)

        // Act
        viewModel.fetchUser("123")

        // Assert
        assertEquals("Alice", viewModel.uiState.value.userName)
    }

    @Test
    fun `fetchUser failure sets errorMessage`() = runTest {
        // Arrange
        val stubRepository = StubUserRepository(Result.failure(Exception("Network error")))
        val viewModel = UserViewModel(stubRepository)

        // Act
        viewModel.fetchUser("123")

        // Assert
        assertNotNull(viewModel.uiState.value.errorMessage)
    }
}
```

### Fake It → Triangulation の流れ

```kotlin
// 🔴 Red
@Test
fun `discount for premium user returns 20 percent`() {
    val calculator = DiscountCalculator()
    assertEquals(200, calculator.calculate(price = 1000, userType = UserType.PREMIUM))
}

// 🟢 Green: Fake it
class DiscountCalculator {
    fun calculate(price: Int, userType: UserType): Int {
        return 200 // Fake it!
    }
}

// 🔴 Red: Triangulation
@Test
fun `discount for regular user returns 10 percent`() {
    val calculator = DiscountCalculator()
    assertEquals(100, calculator.calculate(price = 1000, userType = UserType.REGULAR))
}

// 🟢 Green: 一般化
class DiscountCalculator {
    fun calculate(price: Int, userType: UserType): Int = when (userType) {
        UserType.PREMIUM -> price * 20 / 100
        UserType.REGULAR -> price * 10 / 100
        UserType.GUEST -> 0
    }
}
```

### Repository パターンでのテストダブル

```kotlin
// Interface 定義
interface UserRepository {
    suspend fun findById(id: String): User
    suspend fun save(user: User)
}

// Stub: 事前定義した値を返す
class StubUserRepository(
    private val result: Result<User>
) : UserRepository {
    override suspend fun findById(id: String): User = result.getOrThrow()
    override suspend fun save(user: User) {}
}

// Fake: インメモリ実装（状態を保持）
class FakeUserRepository : UserRepository {
    private val storage = mutableMapOf<String, User>()

    override suspend fun findById(id: String): User =
        storage[id] ?: throw NotFoundException("User not found: $id")

    override suspend fun save(user: User) {
        storage[user.id] = user
    }
}

// Spy: 呼び出しを記録
class SpyUserRepository : UserRepository {
    val savedUsers = mutableListOf<User>()
    var findByIdCallCount = 0
        private set

    override suspend fun findById(id: String): User {
        findByIdCallCount++
        return User(id = id, name = "Test")
    }

    override suspend fun save(user: User) {
        savedUsers.add(user)
    }
}
```

---

## テストダブル使い分けガイド

| 種類 | 目的 | 使用場面 |
|------|------|----------|
| **Stub** | 事前定義した値を返す | 外部依存の戻り値を制御したいとき |
| **Fake** | 簡易的な動作実装（インメモリDB等） | 状態を持つ依存を軽量に再現したいとき |
| **Spy** | 呼び出しを記録する | 副作用（メール送信等）の発生を検証したいとき |
| **Mock** | 期待する呼び出しを事前定義し検証 | 複雑なインタラクションを検証したいとき（使いすぎ注意） |

### 判断フローチャート

```
戻り値で結果を検証できる？
  ├─ Yes → Stub（またはテストダブル不要）
  └─ No → 副作用の発生を検証したい？
           ├─ Yes → Spy（呼び出し記録）
           └─ No → 状態を保持する必要がある？
                    ├─ Yes → Fake（インメモリ実装）
                    └─ No → Mock（最終手段）
```
