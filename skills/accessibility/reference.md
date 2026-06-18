# Accessibility Reference

WCAG基準値、プラットフォーム別API、監査チェックリストの詳細リファレンス。

## WCAG 2.1 / 2.2 達成基準サマリー（モバイル重点）

### 1. Perceivable（知覚可能）
| 基準 | レベル | 内容 | モバイル実装 |
|------|------|------|-------------|
| 1.1.1 Non-text Content | A | 非テキストコンテンツに代替テキスト | `accessibilityLabel` / `contentDescription` |
| 1.3.1 Info and Relationships | A | 情報・構造をプログラム的に判別可能 | Semantics / Accessibility Traits |
| 1.3.4 Orientation | AA | 縦横どちらでも利用可能 | 回転制限を避ける（必須の場合を除く） |
| 1.3.5 Identify Input Purpose | AA | 入力フィールドの目的を識別可能 | `textContentType` / `autofillHints` |
| 1.4.3 Contrast (Minimum) | AA | テキスト 4.5:1（大文字 3:1） | デザイントークンで保証 |
| 1.4.4 Resize Text | AA | 200%まで拡大可能 | Dynamic Type / sp単位 |
| 1.4.10 Reflow | AA | 320 CSS px幅で横スクロール不要 | レスポンシブ設計 |
| 1.4.11 Non-text Contrast | AA | UI要素・グラフィカル要素 3:1 | アイコン・ボーダーのコントラスト |
| 1.4.12 Text Spacing | AA | 行間/文字間を調整しても情報損失なし | 固定行高を避ける |
| 1.4.13 Content on Hover or Focus | AA | ホバー/フォーカスで現れる内容を制御可能 | ツールチップは閉じやすく |

### 2. Operable（操作可能）
| 基準 | レベル | 内容 | モバイル実装 |
|------|------|------|-------------|
| 2.1.1 Keyboard | A | キーボードで全機能利用可能 | 外部キーボード対応 |
| 2.4.3 Focus Order | A | フォーカス順序が論理的 | レイアウトに沿った順序 |
| 2.4.6 Headings and Labels | AA | 見出し・ラベルが内容を説明 | `accessibilityAddTraits(.isHeader)` |
| 2.4.7 Focus Visible | AA | フォーカス位置が視認可能 | カスタムフォーカスインジケータ |
| **2.4.11 Focus Not Obscured** | **AA (2.2)** | フォーカス要素が他に隠れない | キーボード表示時のスクロール |
| 2.5.1 Pointer Gestures | A | マルチタッチ/パスジェスチャに代替 | ピンチズームに+/-ボタン |
| 2.5.3 Label in Name | A | アクセシブル名に視覚ラベルを含む | `accessibilityLabel` ≒ 表示テキスト |
| **2.5.7 Dragging Movements** | **AA (2.2)** | ドラッグに単一ポインタ代替 | スワイプ削除に削除ボタンを併設 |
| **2.5.8 Target Size (Minimum)** | **AA (2.2)** | タッチターゲット 24×24 CSS px以上 | Material 48dp / iOS 44pt |

### 3. Understandable（理解可能）
| 基準 | レベル | 内容 | モバイル実装 |
|------|------|------|-------------|
| 3.2.4 Consistent Identification | AA | 同一機能を一貫して識別 | アイコン/ラベルの統一 |
| 3.3.1 Error Identification | A | エラーをテキストで識別 | エラーメッセージ + フィールド特定 |
| 3.3.3 Error Suggestion | AA | 修正提案を提示 | 「@マークが必要です」など具体的に |
| **3.3.7 Redundant Entry** | **A (2.2)** | 同セッション内の再入力を避ける | 入力済み情報の自動入力 |
| **3.3.8 Accessible Authentication** | **AA (2.2)** | 認知機能テストに依存しない認証 | パスワード貼付許可、生体認証 |

### 4. Robust（堅牢）
| 基準 | レベル | 内容 | モバイル実装 |
|------|------|------|-------------|
| 4.1.2 Name, Role, Value | A | 名前・役割・値がプログラム的に判別可能 | 標準コントロール優先、Semantics |
| 4.1.3 Status Messages | AA | ステータスをフォーカス変更なしで通知 | LiveRegion / Announcement |

## コントラスト比早見表

| 前景 / 背景 | 比率 | AA通常 | AA大 | AAA通常 | AAA大 |
|-----------|------|------|-----|--------|------|
| #000 / #FFF | 21:1 | ✓ | ✓ | ✓ | ✓ |
| #595959 / #FFF | 7:1 | ✓ | ✓ | ✓ | ✓ |
| #767676 / #FFF | 4.54:1 | ✓ | ✓ | ✗ | ✓ |
| #949494 / #FFF | 3:1 | ✗ | ✓ | ✗ | ✗ |
| #777 / #000 | 4.48:1 | ✗ (惜しい) | ✓ | ✗ | ✗ |

**計算式**: `(L1 + 0.05) / (L2 + 0.05)` （L1: 明るい方の相対輝度、L2: 暗い方）

## iOS Accessibility API リファレンス

### Trait一覧（主要）
| Trait | 用途 |
|-------|------|
| `.button` | タップ可能なボタン |
| `.link` | リンク（外部遷移） |
| `.header` | セクション見出し |
| `.image` | 装飾でない画像 |
| `.selected` | 選択状態 |
| `.notEnabled` | 無効状態 |
| `.adjustable` | スライダー等の調整可能要素 |
| `.summaryElement` | 画面のサマリー |
| `.updatesFrequently` | 頻繁に更新（タイマー等） |

### Environment Values
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
@Environment(\.accessibilityInvertColors) var invertColors
@Environment(\.accessibilityVoiceOverEnabled) var voiceOver
@Environment(\.dynamicTypeSize) var dynamicTypeSize  // .xSmall ... .accessibility5
```

### 通知
```swift
UIAccessibility.post(notification: .announcement, argument: "保存しました")
UIAccessibility.post(notification: .screenChanged, argument: nil)
UIAccessibility.post(notification: .layoutChanged, argument: focusedView)
```

## Android Accessibility API リファレンス

### Compose Semantics プロパティ
| プロパティ | 用途 |
|-----------|------|
| `contentDescription` | 要素の説明（読み上げテキスト） |
| `role` | `Role.Button` / `Checkbox` / `Image` 等 |
| `stateDescription` | 状態の説明（「オン」「3個選択中」） |
| `liveRegion` | `Polite` / `Assertive` で動的更新を通知 |
| `heading()` | 見出し |
| `error(description)` | エラー状態と説明 |
| `disabled()` | 無効状態 |
| `selected` | 選択状態 |
| `onClick(label)` | クリックアクションのラベル |

### View System
```kotlin
view.contentDescription = "..."
view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
view.announceForAccessibility("...")
ViewCompat.setAccessibilityHeading(view, true)
ViewCompat.setAccessibilityLiveRegion(view, ACCESSIBILITY_LIVE_REGION_POLITE)
```

### フォントスケール
- API 34+ で最大200%（システム設定）
- アプリ単位で `Configuration.fontScale` を確認
- `dimensionResource` + `sp` で密度・スケール対応

## 監査チェックリスト

### 仕様レビュー段階
- [ ] アクセシビリティの目標水準（AA推奨）が明記されている
- [ ] スクリーンリーダー対応の要件がある
- [ ] Dynamic Type / フォントスケール対応範囲が定義されている
- [ ] 色覚多様性への配慮が盛り込まれている
- [ ] 動画/音声コンテンツがある場合、字幕・代替手段を検討

### デザインレビュー段階
- [ ] テキストコントラスト比が AA 基準（4.5:1 / 3:1）以上
- [ ] UIコンポーネント・アイコンのコントラスト比が 3:1 以上
- [ ] タッチターゲットが 44pt (iOS) / 48dp (Android) 以上
- [ ] 色だけで情報を伝える箇所がない（アイコン/形/テキストで補強）
- [ ] フォーカス順序が論理的に設計されている
- [ ] 200% 拡大時のレイアウトが破綻しない

### 実装レビュー段階

#### iOS
- [ ] すべてのインタラクティブ要素に `accessibilityLabel`
- [ ] 装飾画像は `.accessibilityHidden(true)`
- [ ] 関連要素は `.accessibilityElement(children: .combine)` でグルーピング
- [ ] フォントは `font(.body)` 等のテキストスタイル、または `@ScaledMetric`
- [ ] アニメーションは `accessibilityReduceMotion` を尊重
- [ ] 動的更新時に `UIAccessibility.post(notification:argument:)` で通知
- [ ] カスタムコントロールに適切な `accessibilityTraits`

#### Android
- [ ] インタラクティブ要素に `contentDescription` または Semantics
- [ ] 装飾アイコンは `contentDescription = null`
- [ ] テキストサイズは `sp` 単位
- [ ] タッチターゲット 48dp 以上（`Modifier.minimumInteractiveComponentSize()`）
- [ ] 動的更新には `liveRegion` または `announceForAccessibility`
- [ ] エラーフィールドに `error()` Semantics
- [ ] Accessibility Scanner で警告ゼロ

### テスト
- [ ] 実機 VoiceOver / TalkBack で主要フローが完走できる
- [ ] Dynamic Type 最大 / フォントスケール 200% でレイアウト確認
- [ ] Reduce Motion ON でアニメーションが過剰でない
- [ ] 自動 a11y チェック（`performAccessibilityAudit` / `AccessibilityChecks`）が CI で動作
- [ ] VRT に拡大版・コントラスト確認版が含まれる

## エージェント別の使い分け

| エージェント | このスキルの主な活用ポイント |
|------------|---------------------------|
| spec-analyzer | 仕様にa11y要件が不在でないか検出、AAレベル目標の確認 |
| feature-planner | 実装計画にa11yタスク（ラベル設計、Dynamic Type対応、テスト）を含める |
| design-reviewer | コントラスト比、タッチターゲット、色依存、フォーカス順序の確認 |
| implementation-lead | 実装時のSemantics/accessibilityLabel/sp単位の徹底 |
| app-reviewer | コードレビュー時のa11yチェックリスト適用 |
| vrt-engineer | Dynamic Type/フォントスケール拡大版スナップショットの追加 |
| guideline-checker | App Store / Google Play のa11y関連ガイドライン違反検出 |
