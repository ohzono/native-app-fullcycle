# Android Visual Regression Testing 詳細リファレンス

このドキュメントは [android-visual-regression-testing SKILL.md](SKILL.md) の詳細リファレンスです。

## Compose Preview Screenshot Testing Detailed Examples

### Installation
```kotlin
// settings.gradle.kts
pluginManagement {
    plugins {
        // 最新安定 alpha は release notes で確認:
        // https://developer.android.com/studio/preview/compose-screenshot-testing-release-notes
        id("com.android.compose.screenshot") version "0.0.1-alpha15"
    }
}

// app/build.gradle.kts
plugins {
    id("com.android.compose.screenshot")
}

android {
    experimentalProperties["android.experimental.enableScreenshotTest"] = true
}

dependencies {
    screenshotTestImplementation("androidx.compose.ui:ui-tooling")
}
```

### Basic Usage
```kotlin
// src/screenshotTest/kotlin/com/example/snapshots/ProductCardPreview.kt
import android.content.res.Configuration.UI_MODE_NIGHT_YES
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Preview(name = "Default", showBackground = true)
@Composable
fun ProductCardDefaultPreview() {
    AppTheme {
        ProductCard(product = Product.sample())
    }
}

@Preview(name = "On Sale", showBackground = true)
@Composable
fun ProductCardOnSalePreview() {
    AppTheme {
        ProductCard(product = Product.sample(isOnSale = true))
    }
}

@Preview(name = "Out of Stock", showBackground = true)
@Composable
fun ProductCardOutOfStockPreview() {
    AppTheme {
        ProductCard(product = Product.sample(inStock = false))
    }
}
```

### Dark Mode Testing
```kotlin
// src/screenshotTest/kotlin/com/example/snapshots/ThemePreview.kt
import android.content.res.Configuration.UI_MODE_NIGHT_YES
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Preview(name = "Light", showBackground = true)
@Composable
fun SampleCardLightPreview() {
    AppTheme(darkTheme = false) {
        SampleCard()
    }
}

@Preview(name = "Dark", showBackground = true, uiMode = UI_MODE_NIGHT_YES)
@Composable
fun SampleCardDarkPreview() {
    AppTheme(darkTheme = true) {
        SampleCard()
    }
}
```

### Font Scale Testing
```kotlin
// src/screenshotTest/kotlin/com/example/snapshots/AccessibilityPreview.kt
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Preview(name = "Default Font", showBackground = true)
@Composable
fun ButtonDefaultFontPreview() {
    AppTheme {
        AppButton(text = "Click Me")
    }
}

@Preview(name = "Large Font", fontScale = 1.5f, showBackground = true)
@Composable
fun ButtonLargeFontPreview() {
    AppTheme {
        AppButton(text = "Click Me")
    }
}

@Preview(name = "Extra Large Font", fontScale = 2.0f, showBackground = true)
@Composable
fun ButtonExtraLargeFontPreview() {
    AppTheme {
        AppButton(text = "Click Me")
    }
}
```

### Multiple Device Configurations
```kotlin
// src/screenshotTest/kotlin/com/example/snapshots/MultiDevicePreview.kt
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Preview(name = "Phone", widthDp = 360, heightDp = 800, showBackground = true)
@Composable
fun HomeScreenPhonePreview() {
    AppTheme {
        HomeScreen()
    }
}

@Preview(name = "Phone Large", widthDp = 411, heightDp = 891, showBackground = true)
@Composable
fun HomeScreenPhoneLargePreview() {
    AppTheme {
        HomeScreen()
    }
}

@Preview(name = "Foldable", widthDp = 673, heightDp = 841, showBackground = true)
@Composable
fun HomeScreenFoldablePreview() {
    AppTheme {
        HomeScreen()
    }
}

@Preview(name = "Tablet", widthDp = 600, heightDp = 1024, showBackground = true)
@Composable
fun HomeScreenTabletPreview() {
    AppTheme {
        HomeScreen()
    }
}

@Preview(name = "Small", widthDp = 320, heightDp = 568, showBackground = true)
@Composable
fun HomeScreenSmallPreview() {
    AppTheme {
        HomeScreen()
    }
}
```

### Localization Testing
```kotlin
// src/screenshotTest/kotlin/com/example/snapshots/LocalizationPreview.kt
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Preview(name = "English", locale = "en", showBackground = true)
@Composable
fun WelcomeScreenEnglishPreview() {
    AppTheme {
        WelcomeScreen()
    }
}

@Preview(name = "Japanese", locale = "ja", showBackground = true)
@Composable
fun WelcomeScreenJapanesePreview() {
    AppTheme {
        WelcomeScreen()
    }
}

@Preview(name = "Arabic RTL", locale = "ar", showBackground = true)
@Composable
fun WelcomeScreenArabicPreview() {
    AppTheme {
        WelcomeScreen()
    }
}
```

## CI/CD Integration

### GitHub Actions with Compose Preview Screenshot Testing
```yaml
name: Visual Regression Tests

on:
  pull_request:
    branches: [main, develop]

jobs:
  snapshot-tests:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: gradle

      - name: Run Snapshot Tests
        run: ./gradlew validateDebugScreenshotTest

      - name: Upload Failed Snapshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: failed-snapshots
          path: |
            **/build/outputs/screenshotTest-results/
          retention-days: 7
```

### Snapshot Update Workflow
```yaml
name: Update Snapshots

on:
  workflow_dispatch:
  push:
    branches:
      - 'snapshot-update/**'

jobs:
  update:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Record Snapshots
        run: ./gradlew updateDebugScreenshotTest

      - name: Commit Updated Snapshots
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add '**/snapshots/**'
          git diff --staged --quiet || git commit -m "Update snapshots"
          git push
```

## Directory Structure

```
app/
├── src/
│   ├── main/
│   └── screenshotTest/
│       └── kotlin/
│           └── com/example/
│               └── snapshots/
│                   ├── components/
│                   │   ├── ButtonPreview.kt
│                   │   └── CardPreview.kt
│                   ├── screens/
│                   │   ├── HomeScreenPreview.kt
│                   │   └── ProfileScreenPreview.kt
│                   └── themes/
│                       └── ThemePreview.kt
└── build/
    └── outputs/
        └── screenshotTest-results/
            └── debug/
                └── com.example.snapshots.components/
                    └── ButtonPreview/
                        └── ButtonDefaultFontPreview.png
```

## Handling Dynamic Content

```kotlin
// Use Preview Parameter Provider for consistent test data
class UserPreviewProvider : PreviewParameterProvider<User> {
    override val values = sequenceOf(
        User.sample(name = "John Doe"),
        User.sample(name = "Very Long Name That Might Truncate"),
        User.sample(isPremium = true)
    )
}

@Preview(name = "User Profile", showBackground = true)
@Composable
fun UserProfilePreview(
    @PreviewParameter(UserPreviewProvider::class) user: User
) {
    AppTheme {
        UserProfileCard(user = user)
    }
}
```

## Shared Test Configurations

```kotlin
// Custom multi-preview annotations for reusable configurations
@Preview(name = "Phone", widthDp = 360, showBackground = true)
@Preview(name = "Foldable", widthDp = 673, showBackground = true)
@Preview(name = "Tablet", widthDp = 600, showBackground = true)
annotation class DevicePreview

@Preview(name = "Default Font", fontScale = 1.0f, showBackground = true)
@Preview(name = "Large Font", fontScale = 1.5f, showBackground = true)
@Preview(name = "Extra Large Font", fontScale = 2.0f, showBackground = true)
annotation class FontScalePreview

@Preview(name = "Light", showBackground = true)
@Preview(name = "Dark", showBackground = true, uiMode = UI_MODE_NIGHT_YES)
annotation class ThemePreview

// Usage with custom annotations
@DevicePreview
@Composable
fun HomeScreenDevicePreview() {
    AppTheme { HomeScreen() }
}

@FontScalePreview
@Composable
fun ButtonFontScalePreview() {
    AppTheme { AppButton(text = "Click Me") }
}

@ThemePreview
@Composable
fun CardThemePreview() {
    AppTheme { SampleCard() }
}
```

## Troubleshooting

### 1. Flaky tests due to animations
```kotlin
// Disable animations in Compose previews
@Preview(showBackground = true)
@Composable
fun AnimatedComponentPreview() {
    CompositionLocalProvider(
        LocalInspectionMode provides true  // Disables animations
    ) {
        AppTheme {
            MyAnimatedComponent()
        }
    }
}
```

### 2. Font rendering differences
```kotlin
// Use consistent font configuration
android {
    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}
```

### 3. Image loading in tests
```kotlin
// Replace with synchronous image loader in preview
@Preview(showBackground = true)
@Composable
fun ProfileImagePreview() {
    CompositionLocalProvider(
        LocalImageLoader provides FakeImageLoader()
    ) {
        AppTheme {
            ProfileImage(url = "https://example.com/image.jpg")
        }
    }
}

class FakeImageLoader : ImageLoader {
    override fun enqueue(request: ImageRequest) = TODO()

    override suspend fun execute(request: ImageRequest): ImageResult {
        return SuccessResult(
            drawable = ColorDrawable(Color.GRAY),
            request = request,
            dataSource = DataSource.MEMORY
        )
    }
}
```

### 4. Theme not applied correctly
```kotlin
// Ensure theme is properly wrapped in preview
@Preview(name = "Light", showBackground = true)
@Preview(name = "Dark", showBackground = true, uiMode = UI_MODE_NIGHT_YES)
@Composable
fun ThemedComponentPreview() {
    AppTheme {
        MyComponent()
    }
}
```

## Integration with Design Systems

### Material 3 Component Testing
```kotlin
// src/screenshotTest/kotlin/com/example/snapshots/Material3Preview.kt
@Preview(name = "Filled Button", showBackground = true)
@Composable
fun FilledButtonPreview() {
    AppTheme {
        Button(onClick = {}) {
            Text("Filled Button")
        }
    }
}

@Preview(name = "Outlined Button", showBackground = true)
@Composable
fun OutlinedButtonPreview() {
    AppTheme {
        OutlinedButton(onClick = {}) {
            Text("Outlined Button")
        }
    }
}

@Preview(name = "Text Button", showBackground = true)
@Composable
fun TextButtonPreview() {
    AppTheme {
        TextButton(onClick = {}) {
            Text("Text Button")
        }
    }
}
```

### Design Token Verification
```kotlin
// src/screenshotTest/kotlin/com/example/snapshots/DesignTokenPreview.kt
@Preview(name = "Color Palette", showBackground = true)
@Composable
fun ColorPalettePreview() {
    AppTheme {
        Column {
            ColorSwatch(name = "Primary", color = MaterialTheme.colorScheme.primary)
            ColorSwatch(name = "Secondary", color = MaterialTheme.colorScheme.secondary)
            ColorSwatch(name = "Tertiary", color = MaterialTheme.colorScheme.tertiary)
            ColorSwatch(name = "Error", color = MaterialTheme.colorScheme.error)
        }
    }
}

@Preview(name = "Typography Scale", showBackground = true)
@Composable
fun TypographyScalePreview() {
    AppTheme {
        Column {
            Text("Display Large", style = MaterialTheme.typography.displayLarge)
            Text("Headline Medium", style = MaterialTheme.typography.headlineMedium)
            Text("Body Large", style = MaterialTheme.typography.bodyLarge)
            Text("Label Small", style = MaterialTheme.typography.labelSmall)
        }
    }
}
```
