---
name: test-driven-development
description: テスト駆動開発（TDD）の専門知識。Red-Green-Refactorサイクル、テストファーストアプローチ、Fake it till you make it、三角測量、TODO List Driven Development、テスト容易性の原則。TDDによる新機能実装、テストセーフティネットでのリファクタリング、テスト品質改善時に使用します。
model: opus
allowed-tools: Read, Glob, Edit, Write, Grep, Bash
user-invocable: false
---

# Test-Driven Development (TDD)

## Evidence-First TDD

**Core Belief**: "Test-first achieves both quality and speed; a discipline for writing working, clean code quickly"

### Standards Compliance
- Red-Green-Refactor cycle methodology
- Test-first development practices
- xUnit testing patterns
- Refactoring under test safety net

### Proven Patterns
- Red-Green-Refactor cycle
- Fake It → Triangulation → Obvious Implementation
- TODO List Driven Development
- Testable Design

## Discussion Characteristics

### Discussion Stance
- **Test-First**: Write tests before implementation
- **Small Steps**: Progress in small steps
- **Refactoring with Confidence**: Tests enable safe refactoring

### Key Discussion Points
- Value of test-first (design improvement, documentation, safety net)
- TDD rhythm (Red→Green→Refactor)
- Test granularity and speed
- Appropriate use of mocks and stubs

### Evidence Sources
- Industry-standard TDD practices
- xUnit testing patterns and best practices
- Refactoring techniques with test coverage
- Object-oriented design guided by tests

### Strengths
- Early bug prevention
- Improved design (testability = good design)
- Safe refactoring
- Executable documentation

### Potential Biases
- Initial learning cost
- Difficult to apply to legacy code
- Requires extra effort for UI and DB with many external dependencies

---

## TDD Basic Cycle

### Red-Green-Refactor

The basic TDD rhythm consists of 3 steps:

```
🔴 Red (Write a failing test)
    ↓
🟢 Green (Minimal implementation to pass the test)
    ↓
♻️  Refactor (Remove duplication, improve design)
    ↓
   (Repeat)
```

**Key Principles:**
- **Red**: Always verify the failure (proof that the test is working)
- **Green**: Get to green as quickly as possible (even fake implementation is OK)
- **Refactor**: Remove duplication and clarify intent

---

## Three TDD Implementation Strategies

### 1. Fake It Till You Make It

The simplest approach: return hard-coded values.

**Example: FizzBuzz**

```typescript
// ❌ Don't implement without tests first

// 🔴 Red: Write the test first
describe('FizzBuzz', () => {
  it('should return "1" when given 1', () => {
    expect(fizzBuzz(1)).toBe('1');
  });
});

// 🟢 Green: Fake implementation (hard-coded)
function fizzBuzz(n: number): string {
  return '1'; // Fake it!
}

// ✅ Test passes

// 🔴 Red: Add next test
describe('FizzBuzz', () => {
  it('should return "1" when given 1', () => {
    expect(fizzBuzz(1)).toBe('1');
  });

  it('should return "2" when given 2', () => {
    expect(fizzBuzz(2)).toBe('2');
  });
});

// 🟢 Green: Still fake it
function fizzBuzz(n: number): string {
  if (n === 1) return '1';
  return '2';
}

// ♻️ Refactor: Generalize when pattern emerges
function fizzBuzz(n: number): string {
  return String(n);
}
```

**Value of Fake Implementation:**
- Immediately get to Green (sense of achievement)
- Confirm the test is working correctly
- Next step becomes clear

### 2. Triangulation

Derive general code from multiple test cases.

```typescript
// 🔴 Red: First test
it('should calculate total for single item', () => {
  const cart = new ShoppingCart();
  cart.addItem('Apple', 100);
  expect(cart.getTotal()).toBe(100);
});

// 🟢 Green: Fake implementation
class ShoppingCart {
  getTotal(): number {
    return 100; // Fake it
  }
}

// 🔴 Red: Test from different angle (triangulation)
it('should calculate total for different item', () => {
  const cart = new ShoppingCart();
  cart.addItem('Orange', 150);
  expect(cart.getTotal()).toBe(150);
});

// 🟢 Green: Generalization becomes necessary
class ShoppingCart {
  private items: Array<{ name: string; price: number }> = [];

  addItem(name: string, price: number): void {
    this.items.push({ name, price });
  }

  getTotal(): number {
    return this.items.reduce((sum, item) => sum + item.price, 0);
  }
}

// 🔴 Red: Yet another angle (multiple items)
it('should calculate total for multiple items', () => {
  const cart = new ShoppingCart();
  cart.addItem('Apple', 100);
  cart.addItem('Orange', 150);
  expect(cart.getTotal()).toBe(250);
});

// ✅ Existing implementation passes!
```

**Value of Triangulation:**
- Clear timing for abstraction
- Prevents over-generalization (YAGNI: You Aren't Gonna Need It)
- Confident refactoring

### 3. Obvious Implementation

When implementation is self-evident, write it directly.

```typescript
// 🔴 Red
it('should add two numbers', () => {
  expect(add(2, 3)).toBe(5);
});

// 🟢 Green: Obvious implementation
function add(a: number, b: number): number {
  return a + b; // Nothing else makes sense
}
```

**When to Use:**
- **Fake It**: When implementation is unclear, when new to TDD
- **Triangulation**: When abstraction timing is uncertain
- **Obvious Implementation**: When implementation is self-evident

---

## TODO List Driven Development

An important practice for maintaining focus and visualizing progress during TDD.

### How to Use TODO Lists

```
TODO:
- [ ] Return string "1" when given 1
- [ ] Return string "2" when given 2
- [ ] Return "Fizz" for multiples of 3
- [ ] Return "Buzz" for multiples of 5
- [ ] Return "FizzBuzz" for multiples of both 3 and 5
- [ ] Return sequence from 1 to 100
```

**TODO List Principles:**
1. **Write before starting work**: Think about what to test
2. **Break into small pieces**: Each TODO should complete in 5-15 minutes
3. **Cross off when done**: Sense of achievement and progress visibility
4. **Add new ideas**: Include insights discovered during refactoring
5. **Prioritize**: Start with easy ones

### Benefits of TODO Lists

- **Free up working memory**: Organize your thoughts
- **Maintain focus**: Concentrate only on current task
- **Visualize progress**: Maintain motivation
- **Improve design**: Thinking about test cases improves design

---

## Value of Test-First

### 1. Design Improvement

Code that is easy to test is well-designed.

```typescript
// ❌ Hard to test design
class OrderService {
  processOrder(orderId: string): void {
    // Direct DB access
    const order = db.query('SELECT * FROM orders WHERE id = ?', [orderId]);

    // Direct external API call
    const payment = fetch('https://payment-api.com/charge', {
      method: 'POST',
      body: JSON.stringify({ orderId, amount: order.total })
    });

    // Direct email sending
    sendEmail(order.customerEmail, 'Order confirmed');
  }
}

// ✅ Easy to test design (Dependency Injection)
class OrderService {
  constructor(
    private orderRepository: OrderRepository,
    private paymentGateway: PaymentGateway,
    private emailService: EmailService
  ) {}

  async processOrder(orderId: string): Promise<void> {
    const order = await this.orderRepository.findById(orderId);
    await this.paymentGateway.charge(orderId, order.total);
    await this.emailService.send(order.customerEmail, 'Order confirmed');
  }
}

// Inject mocks in tests
describe('OrderService', () => {
  it('should process order successfully', async () => {
    const mockRepository = createMockRepository();
    const mockPayment = createMockPaymentGateway();
    const mockEmail = createMockEmailService();

    const service = new OrderService(mockRepository, mockPayment, mockEmail);
    await service.processOrder('123');

    expect(mockPayment.charge).toHaveBeenCalledWith('123', 1000);
  });
});
```

### 2. Executable Documentation

Tests are the best documentation showing how to use the code.

```typescript
describe('ShoppingCart', () => {
  describe('addItem', () => {
    it('should add item to cart', () => {
      const cart = new ShoppingCart();
      cart.addItem('Apple', 100, 2);

      expect(cart.getItemCount()).toBe(1);
      expect(cart.getTotal()).toBe(200);
    });

    it('should increase quantity if same item added again', () => {
      const cart = new ShoppingCart();
      cart.addItem('Apple', 100, 2);
      cart.addItem('Apple', 100, 1);

      expect(cart.getItemCount()).toBe(1);
      expect(cart.getTotal()).toBe(300);
    });
  });

  describe('removeItem', () => {
    it('should remove item from cart', () => {
      const cart = new ShoppingCart();
      cart.addItem('Apple', 100, 2);
      cart.removeItem('Apple');

      expect(cart.getItemCount()).toBe(0);
    });

    it('should throw error when removing non-existent item', () => {
      const cart = new ShoppingCart();

      expect(() => cart.removeItem('Apple')).toThrow('Item not found');
    });
  });
});
```

### 3. Safety Net

Guarantees existing functionality is not broken during refactoring or bug fixes.

```typescript
// Before refactoring
function calculateDiscount(price: number, customerType: string): number {
  if (customerType === 'premium') {
    return price * 0.2;
  } else if (customerType === 'regular') {
    return price * 0.1;
  } else {
    return 0;
  }
}

// Tests enable safe refactoring
describe('calculateDiscount', () => {
  it('should return 20% for premium customers', () => {
    expect(calculateDiscount(1000, 'premium')).toBe(200);
  });

  it('should return 10% for regular customers', () => {
    expect(calculateDiscount(1000, 'regular')).toBe(100);
  });

  it('should return 0 for guest customers', () => {
    expect(calculateDiscount(1000, 'guest')).toBe(0);
  });
});

// After refactoring (Polymorphism)
interface DiscountStrategy {
  calculate(price: number): number;
}

class PremiumDiscount implements DiscountStrategy {
  calculate(price: number): number {
    return price * 0.2;
  }
}

class RegularDiscount implements DiscountStrategy {
  calculate(price: number): number {
    return price * 0.1;
  }
}

class NoDiscount implements DiscountStrategy {
  calculate(price: number): number {
    return 0;
  }
}

// ✅ Confirm all tests pass
```

---

## Test Structure

### AAA Pattern (Arrange-Act-Assert)

```typescript
describe('User registration', () => {
  it('should create new user with valid data', () => {
    // Arrange: Set up test data and mocks
    const userRepository = new InMemoryUserRepository();
    const emailService = new MockEmailService();
    const service = new UserService(userRepository, emailService);

    const userData = {
      email: 'test@example.com',
      password: 'SecurePass123',
      name: 'Test User'
    };

    // Act: Execute the operation under test
    const user = service.register(userData);

    // Assert: Verify expected results
    expect(user.email).toBe('test@example.com');
    expect(user.name).toBe('Test User');
    expect(userRepository.findByEmail('test@example.com')).toBeDefined();
    expect(emailService.sentEmails).toHaveLength(1);
  });
});
```

### Given-When-Then (BDD Style)

```typescript
describe('Shopping Cart Total Calculation', () => {
  it('should apply discount when total exceeds threshold', () => {
    // Given: Empty cart and products
    const cart = new ShoppingCart();
    const expensiveItem = { name: 'Laptop', price: 1500 };
    const cheapItem = { name: 'Mouse', price: 30 };

    // When: Add products exceeding threshold
    cart.addItem(expensiveItem);
    cart.addItem(cheapItem);

    // Then: Discount is applied
    expect(cart.getTotal()).toBe(1377); // 10% discount applied
    expect(cart.getDiscount()).toBe(153);
  });
});
```

---

## Test Types and Granularity

### Test Pyramid

```
        /\
       /  \
      / UI \         Few (slow, fragile)
     /------\
    /        \
   /  Integ   \      Medium
  /------------\
 /              \
/   Unit Tests   \    Many (fast, stable)
------------------
```

**Test Types Summary:**
1. **Unit Tests**: Test only one class/function, fast (milliseconds), external dependencies mocked
2. **Integration Tests**: Collaborative behavior of multiple components, medium speed (seconds)
3. **E2E Tests**: Test from user perspective, slow (minutes), uses entire system

---

## Listening to the Tests（テストの声を聴く）

テストが書きにくいとき、それはテスト自体の問題ではなく**設計の問題シグナル**。

### テストからの設計フィードバック

| テストの声（症状） | 設計上の問題 | 対処 |
|---|---|---|
| セットアップが長い・複雑 | クラスの責務が多すぎる（SRP違反） | クラスを分割する |
| コンストラクタ引数が多い（4つ以上） | 依存が多すぎる | ファサードの導入、責務の再分割 |
| テスト名が長くなる | メソッドが複数の振る舞いを持っている | メソッド分割 |
| モックの設定が複雑 | 結合度が高すぎる | インターフェース抽出、依存逆転 |
| テストが頻繁に壊れる | 実装詳細に依存している | 振る舞いベースのテストに変更 |
| プライベートメソッドをテストしたくなる | 責務が隠れている | 別クラスに抽出して公開メソッドとしてテスト |

### 実践例

```typescript
// ❌ テストの声: セットアップが長すぎる → クラスの責務が多い
describe('OrderService', () => {
  it('should process order', () => {
    const db = new MockDatabase();
    const payment = new MockPaymentGateway();
    const inventory = new MockInventoryService();
    const email = new MockEmailService();
    const logger = new MockLogger();
    const analytics = new MockAnalytics();
    // → 6つの依存 = 設計の問題

    const service = new OrderService(db, payment, inventory, email, logger, analytics);
    // ...
  });
});

// ✅ テストの声に従って設計を改善
describe('OrderProcessor', () => {
  it('should process payment for order', () => {
    const orders = new InMemoryOrderRepository();
    const payment = new MockPaymentGateway();

    const processor = new OrderProcessor(orders, payment);
    // → 責務を分割し、依存を2つに削減
  });
});
```

---

## Mock Usage Guidelines（モックの適切な使い方）

### モック過剰使用の警告

**モック過剰使用の原則:**

モックを使いすぎると：
- テストがリファクタリングの障壁になる（実装詳細に依存）
- テストが脆くなる（内部構造の変更で壊れる）
- テストの信頼性が下がる（実際の動作と乖離）

### 状態検証 vs 振る舞い検証

```typescript
// 状態検証（State Verification） - 優先すべき
it('should add item to cart', () => {
  const cart = new ShoppingCart();
  cart.addItem('Apple', 100);

  // 結果の状態を検証
  expect(cart.getTotal()).toBe(100);
  expect(cart.getItemCount()).toBe(1);
});

// 振る舞い検証（Behavior Verification） - 必要なときだけ
it('should send email when order is placed', () => {
  const mockEmail = { send: jest.fn() };
  const service = new OrderService(mockEmail);

  service.placeOrder(order);

  // 副作用の発生を検証（他に検証手段がない場合）
  expect(mockEmail.send).toHaveBeenCalledWith(
    order.customerEmail,
    expect.any(String)
  );
});
```

### モック使用の判断基準

| 状況 | 推奨 |
|------|------|
| 戻り値で結果を検証できる | 状態検証（モック不要） |
| コレクションの中身で検証できる | 状態検証（モック不要） |
| 外部サービスへの副作用 | 振る舞い検証（モック使用） |
| 非決定的な依存（時刻、乱数） | Stub使用 |
| I/O操作（DB、ファイル、ネットワーク） | Fake or Stub |

---

## Test Smells（テストの不吉なにおい）

テストコードの問題を示す兆候。早期に検出して対処する。

### Fragile Tests（脆いテスト）

実装の小さな変更で壊れるテスト。

```typescript
// ❌ 脆いテスト: 内部構造に依存
it('should store user in database', () => {
  service.registerUser(userData);

  // SQL文やテーブル構造に依存 → 内部変更で壊れる
  expect(db.query).toHaveBeenCalledWith(
    'INSERT INTO users (name, email) VALUES (?, ?)',
    ['John', 'john@example.com']
  );
});

// ✅ 振る舞いベース: 結果を検証
it('should be able to find registered user by email', () => {
  service.registerUser(userData);

  const user = service.findByEmail('john@example.com');
  expect(user.name).toBe('John');
});
```

### Slow Tests（遅いテスト）

```
⚠ 兆候:
- テストスイート全体の実行に数分以上かかる
- 開発者がテスト実行を避けるようになる

対処:
- DB/ネットワーク依存をインメモリ実装で置き換え
- テストピラミッドのバランスを見直す
- 並列実行の導入
```

### Test Coupling（テスト間結合）

```typescript
// ❌ テスト間で状態を共有
let sharedUser: User;

it('should create user', () => {
  sharedUser = service.createUser(data);  // 他のテストが依存
  expect(sharedUser).toBeDefined();
});

it('should find created user', () => {
  // ↑のテストが失敗するとこれも失敗 → 独立性がない
  const found = service.findById(sharedUser.id);
  expect(found).toBeDefined();
});

// ✅ 各テストが独立
it('should find user by id', () => {
  const user = service.createUser(data);  // 各テスト内で準備
  const found = service.findById(user.id);
  expect(found.email).toBe(data.email);
});
```

### その他のTest Smells

| Smell | 症状 | 対処 |
|-------|------|------|
| **Mystery Guest** | テストデータがどこから来るか不明 | テスト内でデータを明示的に準備 |
| **Eager Test** | 1つのテストで複数の振る舞いを検証 | 1テスト1アサーション（論理的に） |
| **Conditional Test Logic** | テスト内にif文やループ | テストケースを分割 |
| **Hard-Coded Test Data** | マジックナンバーの散在 | テストヘルパーやファクトリーを活用 |

---

## Summary: TDD Guidelines

**Core Principles:**

1. **Test-First**: Write tests before implementation
2. **Small Steps**: Short Red→Green→Refactor cycles (2-5 minutes each)
3. **TODO List**: Organize thoughts, visualize progress
4. **Fake It→Triangulation→Obvious Implementation**: Use appropriately
5. **Don't Skip Refactor**: Don't be satisfied with Green, improve design
6. **Quality and Speed**: Internal quality generates speed
7. **Working Clean Code**: The goal of TDD
8. **Listening to the Tests**: Hard-to-write tests signal design problems
9. **No Batch Writing**: Write one test at a time, not all tests upfront

**TDD is a Discipline:**
- Feels difficult at first
- Requires practice
- Becomes natural once it's a habit
- Big returns in the long run

## 詳細リファレンス

より詳細な技術リファレンス、コード例、チェックリストは [reference.md](reference.md) を参照してください。
