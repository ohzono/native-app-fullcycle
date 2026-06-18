---
name: android-app-development
description: Jetpack Compose、Material Design、Androidアーキテクチャの専門知識。MVVM/MVI、Hilt、Room、Retrofit等のモダンAndroid開発パターンを提供します。
model: opus
allowed-tools: Read, Glob, Edit, Write, WebSearch, Bash
user-invocable: false
---

# Android App Development Skill

## Overview
Comprehensive expertise in developing native Android applications using Jetpack Compose, Android SDK, and modern Android architecture following Material Design guidelines.

## Jetpack Compose

### Basic Composables
```kotlin
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun MainScreen() {
    var text by remember { mutableStateOf("") }
    var count by remember { mutableStateOf(0) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Text
        Text(
            text = "Hello, Android!",
            style = MaterialTheme.typography.headlineMedium
        )

        // TextField
        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            label = { Text("Enter text") },
            modifier = Modifier.fillMaxWidth()
        )

        // Button
        Button(
            onClick = { count++ },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Clicked $count times")
        }

        // Image
        Image(
            painter = painterResource(id = R.drawable.icon),
            contentDescription = "Icon",
            modifier = Modifier.size(100.dp)
        )

        // LazyColumn (similar to RecyclerView)
        LazyColumn {
            items(20) { index ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                ) {
                    Text(
                        text = "Item $index",
                        modifier = Modifier.padding(16.dp)
                    )
                }
            }
        }
    }
}
```

### State Management
```kotlin
// Remember - Local state
@Composable
fun Counter() {
    var count by remember { mutableStateOf(0) }

    Button(onClick = { count++ }) {
        Text("Count: $count")
    }
}

// rememberSaveable - Survives configuration changes
@Composable
fun PersistentCounter() {
    var count by rememberSaveable { mutableStateOf(0) }

    Button(onClick = { count++ }) {
        Text("Count: $count")
    }
}

// ViewModel
class MainViewModel : ViewModel() {
    private val _uiState = MutableStateFlow<UiState>(UiState.Loading)
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<Event>()
    val events: SharedFlow<Event> = _events.asSharedFlow()

    fun loadData() {
        viewModelScope.launch {
            try {
                val data = repository.fetchData()
                _uiState.value = UiState.Success(data)
            } catch (e: Exception) {
                _uiState.value = UiState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun onItemClick(item: Item) {
        viewModelScope.launch {
            _events.emit(Event.NavigateToDetail(item.id))
        }
    }
}

sealed class UiState {
    object Loading : UiState()
    data class Success(val data: List<Item>) : UiState()
    data class Error(val message: String) : UiState()
}

sealed class Event {
    data class NavigateToDetail(val id: String) : Event()
}

// Usage in Composable
@Composable
fun MainScreen(
    viewModel: MainViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadData()
    }

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is Event.NavigateToDetail -> {
                    // Navigate
                }
            }
        }
    }

    when (val state = uiState) {
        is UiState.Loading -> {
            CircularProgressIndicator()
        }
        is UiState.Success -> {
            ItemList(items = state.data, onItemClick = viewModel::onItemClick)
        }
        is UiState.Error -> {
            Text("Error: ${state.message}")
        }
    }
}
```

### Navigation

Navigation の実装には `android-navigation3` skill を参照してください（Navigation 3 への移行ガイドとパターン集を含む）。

## Best Practices

### Architecture
- **MVVM**: Recommended architecture pattern
- **Clean Architecture**: For complex apps
- **Repository Pattern**: Abstract data sources
- **Use Cases/Interactors**: Business logic layer

### Performance
- Use `remember` for expensive calculations
- Implement pagination for large lists
- Use `LazyColumn` instead of `Column` for lists
- Cache images with Coil or Glide
- Profile with Android Profiler

### Security
- Use EncryptedSharedPreferences for sensitive data
- Implement certificate pinning
- Validate all user input
- Use ProGuard/R8 for code obfuscation（詳細は `android-r8-analyzer` skill を参照）
- Implement biometric authentication

## Evidence-First Android Development

**Core Belief**: "Android platform guidelines ensure quality; user-centric design drives engagement"

### Standards Compliance
- Android Developers official documentation and API guidelines
- Material Design 3 (Material You) specifications
- Google Play Store policies and best practices
- Android architecture components best practices
- Jetpack Compose guidelines

### Proven Patterns Application
- Modern Android Development (MAD) skills
- Official architecture patterns (MVVM, MVI)
- Android testing pyramid
- Performance best practices from Android Performance Patterns

## Trigger Phrases

This skill activates for:
- "Android", "Jetpack Compose", "Material Design"
- "Android SDK", "Android app", "native Android"
- "Room", "Retrofit", "WorkManager", "Hilt"
- "Google Play", "APK", "Android testing"

## When to Use This Skill
- Building Android applications with Jetpack Compose
- Implementing Android features and frameworks
- Working with Room, Retrofit, WorkManager
- Material Design implementation
- Android architecture patterns
- Push notifications and background tasks
- Google Play Store submission
- Android testing strategies

## 詳細リファレンス

より詳細な技術リファレンス、コード例、チェックリストは [reference.md](reference.md) を参照してください。

## Google 公式 Android skill（バンドル）

本プラグインには Google 公式の [android/skills](https://github.com/android/skills)（Apache 2.0, © Google LLC）を `vendor/android-skills/` に vendored copy としてバンドルしています（marketplace インストールでもそのまま同梱されます）。以下のトピックは該当するラッパー skill を呼び出して参照してください:

- **AGP 9 アップグレード**: `android-agp-upgrade`
- **XML → Jetpack Compose マイグレーション**: `android-compose-migration`
- **Navigation 3**: `android-navigation3`
- **R8 最適化**: `android-r8-analyzer`
- **Play Billing Library アップグレード**: `android-play-billing`
- **Edge-to-edge**: `android-edge-to-edge`
