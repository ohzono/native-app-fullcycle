---
name: accessibility
description: WCAG 2.1/2.2 と iOS（VoiceOver/Dynamic Type）・Android（TalkBack/フォントスケール）のアクセシビリティ基準、共通UIパターン、a11yテスト手法をカバー。仕様検討・デザイン/コードレビュー・実装時のa11y要件確認に使用。
allowed-tools: Read, Glob, Grep, WebSearch
model: opus
user-invocable: false
---

# Accessibility Skill

## 概要
WCAG 2.1/2.2 およびモバイルプラットフォーム固有のアクセシビリティガイドラインに基づき、誰もが使えるアプリを設計・実装・検証するための専門知識を提供します。仕様チェック、計画、デザインレビュー、コードレビュー、VRT、E2Eテストの各フェーズで参照されます。

詳細な基準値テーブル・チェックリストは `reference.md` を参照してください。

## WCAG 2.1 / 2.2 標準規格

### 4つの原則（POUR）
| 原則 | 意味 | モバイルでの代表例 |
|------|------|-------------------|
| Perceivable（知覚可能） | 情報・UIをユーザーが知覚できる | 代替テキスト、十分なコントラスト、字幕 |
| Operable（操作可能） | 操作可能なUIとナビゲーション | タッチターゲット、キーボード操作、十分な操作時間 |
| Understandable（理解可能） | 情報とUI操作が理解可能 | 一貫したナビゲーション、エラー特定と修正提案 |
| Robust（堅牢） | 支援技術を含む多様な環境で解釈可能 | 適切なARIA/Semantics、標準コントロールの活用 |

### 適合レベル
- **A**: 最低限満たすべき
- **AA**: 一般的な目標水準（**プロダクトの既定目標**）
- **AAA**: 最高水準（コンテンツ全体への適用は通常困難）

### 主要な数値基準（AA基準）
| 項目 | 基準 |
|------|------|
| テキストコントラスト比（通常） | **4.5:1** 以上 |
| テキストコントラスト比（大文字 18pt以上 / 14pt太字以上） | **3:1** 以上 |
| 非テキストコントラスト（UIコンポーネント、グラフィカル要素） | **3:1** 以上 |
| 文字サイズ拡大耐性 | **200%** までレイアウト破綻なし |
| タッチターゲット（WCAG 2.2 Target Size Minimum） | **24×24 CSS px** 以上（推奨 44×44） |

### WCAG 2.2 で追加された主な達成基準（モバイル関連）
- **2.4.11 Focus Not Obscured (Minimum)**: フォーカス時のUI要素が他のコンテンツに隠されない
- **2.5.7 Dragging Movements**: ドラッグ操作には単一ポインタの代替手段を提供
- **2.5.8 Target Size (Minimum)**: 24×24 CSS px以上
- **3.3.7 Redundant Entry**: 一度入力した情報の再入力を避ける
- **3.3.8 Accessible Authentication**: 認知機能テスト（パスワードの記憶など）に依存しない認証手段の提供

## iOS アクセシビリティ

### VoiceOver
```swift
// SwiftUI
Image(systemName: "trash")
    .accessibilityLabel("削除")
    .accessibilityHint("選択中のアイテムを削除します")
    .accessibilityAddTraits(.isButton)

// グルーピング: 関連要素をまとめて1つのアクセシビリティ要素に
HStack {
    Image("user-avatar")
    VStack {
        Text("山田太郎")
        Text("オンライン")
    }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("山田太郎、オンライン")

// UIKit
button.accessibilityLabel = "削除"
button.accessibilityHint = "選択中のアイテムを削除します"
button.accessibilityTraits = .button
```

**ラベル付けの原則**:
- **何を**（ラベル）と**何が起きるか**（ヒント）を分離
- 「ボタン」「画像」など要素タイプを含めない（traitsで自動付与される）
- 装飾画像は `.accessibilityHidden(true)` で除外

### Dynamic Type
```swift
// SwiftUI: 自動でDynamic Type対応
Text("見出し")
    .font(.headline)  // システムフォントスタイルを使う

// カスタムサイズ: @ScaledMetric で拡大に追従
@ScaledMetric var iconSize: CGFloat = 24
Image(systemName: "star")
    .frame(width: iconSize, height: iconSize)

// UIKit: UIFontMetrics で拡大に追従
let font = UIFontMetrics(forTextStyle: .body)
    .scaledFont(for: UIFont.systemFont(ofSize: 17))
label.font = font
label.adjustsFontForContentSizeCategory = true
```

**チェックポイント**:
- 固定 `font(.system(size:))` を避け、`font(.body)` 等のテキストスタイルを使う
- 拡大時にレイアウト崩れがないか（XL3 / AccessibilityXL までテスト）
- アイコンサイズも `@ScaledMetric` で追従

### Reduce Motion / Differentiate Without Color
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiate

withAnimation(reduceMotion ? nil : .spring()) {
    isExpanded.toggle()
}

// 色 + 形/アイコンで状態を伝える
HStack {
    Image(systemName: status.iconName)  // 形でも区別
    Text(status.label).foregroundColor(status.color)
}
```

### その他
- **Switch Control / Voice Control**: 標準コントロール（`Button`, `Toggle`等）を使えば自動対応
- **SF Symbols**: 意味のあるシンボルには `accessibilityLabel` を付与（装飾は隠す）
- **VoiceOverのローター**: 見出し階層は `.accessibilityAddTraits(.isHeader)` で示す
- **動的コンテンツ通知**: `UIAccessibility.post(notification: .announcement, argument: "保存しました")`

## Android アクセシビリティ

### TalkBack
```kotlin
// Jetpack Compose
Icon(
    imageVector = Icons.Default.Delete,
    contentDescription = "削除"  // null を渡すと装飾要素扱い
)

Modifier.semantics {
    contentDescription = "山田太郎、オンライン"
    role = Role.Button
    onClick(label = "プロフィールを開く") { /* ... */ true }
}

// View System
button.contentDescription = "削除"
view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO  // 装飾を除外
```

**原則**:
- 装飾アイコン: `contentDescription = null`
- グルーピング: `Modifier.semantics(mergeDescendants = true)`
- 「ボタン」等の役割名は `Role` で指定（contentDescriptionに含めない）

### フォントスケール対応
```kotlin
// Compose: sp 単位を使う
Text(
    text = "本文",
    fontSize = 16.sp,  // dp ではなく sp
    style = MaterialTheme.typography.bodyLarge
)

// XML
android:textSize="16sp"  // dp や px は使わない
```

**チェックポイント**:
- 拡大率 200% でレイアウトが破綻しないこと（API 34 以降は最大200%）
- `TextView` 系は `sp`、アイコンは `dp` を使い分け
- 固定高さの行に `sp` テキストを入れない

### タッチターゲット
- **48×48 dp 以上**（Material Design 推奨、WCAG AAA は 44 CSS px）
- 視覚的に小さくても、`Modifier.minimumInteractiveComponentSize()` や `padding` で確保
- リスト要素間のスペースで隣接ターゲットの誤タップを防ぐ

### Compose Semantics
```kotlin
Modifier.semantics {
    heading()                           // 見出し
    liveRegion = LiveRegionMode.Polite  // 動的更新通知
    stateDescription = "オン"           // 状態を説明
    error("メールアドレスが不正です")    // エラー伝達
}
```

### Accessibility Scanner / 動的通知
- **Accessibility Scanner**（Google製アプリ）でリリース前にスキャン
- 動的通知: `view.announceForAccessibility("保存しました")`
- フォーカス制御: `view.requestFocus()` / `Modifier.focusRequester`

## 共通パターン

### 色だけに依存しない
- エラー: 赤色 + アイコン + テキストで伝達
- グラフ: 色 + パターン/形で系列を区別
- リンク: 色 + 下線

### キーボード/外部入力対応
- フォーカス順序が論理的（左→右、上→下）
- すべてのインタラクションがキーボードで実行可能（iPad/Chromebook対応）
- フォーカスインジケータが視認可能（コントラスト比 3:1 以上）

### モーダル/ダイアログ
- フォーカストラップ: モーダル外にフォーカスが移動しない
- 開いた直後にモーダル内の最初の要素にフォーカス
- 閉じた後は元のトリガー要素にフォーカスを戻す

### エラーハンドリング
- エラーを **テキスト** で明示（色だけ NG）
- どのフィールドのエラーか明確にする（`labelledBy` / `accessibilityLabel`）
- 修正方法を提案する

### スクリーンリーダー通知
- 非同期処理完了、トースト、リスト更新時は明示的にアナウンス
- iOS: `UIAccessibility.post(notification: .announcement, ...)`
- Android: `view.announceForAccessibility(...)` / `liveRegion`

## テスト手法

### 手動検証ツール
| プラットフォーム | ツール | 用途 |
|--------------|------|-----|
| iOS | Accessibility Inspector (Xcode) | 要素のラベル/トレイト確認、コントラスト測定、Audit実行 |
| iOS | VoiceOver (実機) | 実際の読み上げ・操作体験を確認 |
| Android | Accessibility Scanner | 自動スキャン、改善提案 |
| Android | TalkBack (実機) | 実際の読み上げ・操作体験を確認 |
| 共通 | Stark / Contrast (Figma) | デザイン段階でコントラスト比検証 |

### 自動テスト

**iOS (XCTest)**:
```swift
func testAccessibility() throws {
    let app = XCUIApplication()
    app.launch()
    try app.performAccessibilityAudit()  // Xcode 15+
}

// 個別要素
XCTAssertEqual(button.label, "削除")
XCTAssertTrue(button.isAccessibilityElement)
```

**Android (Espresso)**:
```kotlin
@Before fun enableA11yChecks() {
    AccessibilityChecks.enable()
        .setRunChecksFromRootView(true)
}

@Test fun testButton() {
    onView(withId(R.id.delete_btn))
        .check(matches(withContentDescription("削除")))
}
```

### CI統合
- VRT（Visual Regression Test）に Dynamic Type / フォントスケール拡大版を含める
- iOS: `performAccessibilityAudit()` を E2E テストに組み込む
- Android: `AccessibilityChecks.enable()` で全テストに自動チェックを適用

### アクセシビリティ監査チェックリスト
詳細は `reference.md` の「監査チェックリスト」を参照。

## フェーズ別の活用

| フェーズ | a11y で確認すべきこと |
|---------|---------------------|
| Phase 2 (仕様チェック) | a11y 要件が仕様に含まれているか（不在検出） |
| Phase 5 (計画) | a11y 対応をタスクに含める（ラベル設計、Dynamic Type、コントラスト） |
| Phase 8-11 (実装) | コードレベルでラベル/Semantics/sp単位/タッチターゲットを実装 |
| Phase 16 (デザインレビュー) | コントラスト比、タッチターゲット、色依存、フォーカス順序を確認 |
| VRT / E2E | Dynamic Type/フォントスケール拡大版のスナップショット、自動a11yチェック |

## 参考資料
- WCAG 2.1: https://www.w3.org/TR/WCAG21/
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- Apple HIG - Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Material Design - Accessibility: https://m3.material.io/foundations/accessible-design
- Android Accessibility: https://developer.android.com/guide/topics/ui/accessibility
