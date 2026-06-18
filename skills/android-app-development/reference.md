# Android App Development 詳細リファレンス

このドキュメントは [android-app-development SKILL.md](SKILL.md) の詳細リファレンスです。

## Android Architecture Components

### Room Database
```kotlin
// Entity
@Entity(tableName = "users")
data class User(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "email") val email: String,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis()
)

// DAO
@Dao
interface UserDao {
    @Query("SELECT * FROM users")
    fun getAllUsers(): Flow<List<User>>

    @Query("SELECT * FROM users WHERE id = :userId")
    suspend fun getUserById(userId: Int): User?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUser(user: User): Long

    @Update
    suspend fun updateUser(user: User)

    @Delete
    suspend fun deleteUser(user: User)

    @Query("DELETE FROM users WHERE id = :userId")
    suspend fun deleteUserById(userId: Int)
}

// Database
@Database(entities = [User::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "app_database"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}

// Repository
class UserRepository(private val userDao: UserDao) {
    val allUsers: Flow<List<User>> = userDao.getAllUsers()

    suspend fun getUserById(userId: Int): User? {
        return userDao.getUserById(userId)
    }

    suspend fun insert(user: User): Long {
        return userDao.insertUser(user)
    }

    suspend fun update(user: User) {
        userDao.updateUser(user)
    }

    suspend fun delete(user: User) {
        userDao.deleteUser(user)
    }
}
```

### Hilt Dependency Injection
```kotlin
// Application
@HiltAndroidApp
class MyApplication : Application()

// Activity
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MyAppTheme {
                AppNavigation()
            }
        }
    }
}

// ViewModel
@HiltViewModel
class UserViewModel @Inject constructor(
    private val repository: UserRepository
) : ViewModel() {
    val users = repository.allUsers.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    fun addUser(name: String, email: String) {
        viewModelScope.launch {
            repository.insert(User(name = name, email = email))
        }
    }
}

// Module
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return AppDatabase.getDatabase(context)
    }

    @Provides
    fun provideUserDao(database: AppDatabase): UserDao {
        return database.userDao()
    }
}

@Module
@InstallIn(SingletonComponent::class)
object RepositoryModule {
    @Provides
    @Singleton
    fun provideUserRepository(userDao: UserDao): UserRepository {
        return UserRepository(userDao)
    }
}

// Network Module
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            })
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl("https://api.example.com/")
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService {
        return retrofit.create(ApiService::class.java)
    }
}
```

## Networking with Retrofit
```kotlin
// API Service
interface ApiService {
    @GET("users")
    suspend fun getUsers(): List<User>

    @GET("users/{id}")
    suspend fun getUserById(@Path("id") userId: String): User

    @POST("users")
    suspend fun createUser(@Body user: User): User

    @PUT("users/{id}")
    suspend fun updateUser(@Path("id") userId: String, @Body user: User): User

    @DELETE("users/{id}")
    suspend fun deleteUser(@Path("id") userId: String): Response<Unit>

    // Query parameters
    @GET("posts")
    suspend fun getPosts(
        @Query("page") page: Int,
        @Query("limit") limit: Int
    ): PostsResponse

    // Headers
    @GET("protected")
    suspend fun getProtectedData(@Header("Authorization") token: String): Data
}

// Repository
class ApiRepository @Inject constructor(
    private val apiService: ApiService
) {
    suspend fun getUsers(): Result<List<User>> {
        return try {
            val users = apiService.getUsers()
            Result.success(users)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun createUser(user: User): Result<User> {
        return try {
            val createdUser = apiService.createUser(user)
            Result.success(createdUser)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

## WorkManager (Background Tasks)
```kotlin
// Worker
class DataSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            // Perform background work
            val data = fetchDataFromApi()
            saveToDatabase(data)

            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 3) {
                Result.retry()
            } else {
                Result.failure()
            }
        }
    }
}

// Schedule work
class WorkScheduler @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun schedulePeriodicSync() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(true)
            .build()

        val syncWorkRequest = PeriodicWorkRequestBuilder<DataSyncWorker>(
            15, TimeUnit.MINUTES
        )
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS
            )
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "DataSync",
            ExistingPeriodicWorkPolicy.KEEP,
            syncWorkRequest
        )
    }

    fun scheduleOneTimeWork(data: Data) {
        val workRequest = OneTimeWorkRequestBuilder<DataSyncWorker>()
            .setInputData(data)
            .build()

        WorkManager.getInstance(context).enqueue(workRequest)
    }
}
```

## Push Notifications (Firebase Cloud Messaging)
```kotlin
// Service
class MyFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        remoteMessage.notification?.let { notification ->
            showNotification(
                title = notification.title ?: "",
                body = notification.body ?: ""
            )
        }

        remoteMessage.data.isNotEmpty().let {
            handleDataPayload(remoteMessage.data)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Send token to server
        sendTokenToServer(token)
    }

    private fun showNotification(title: String, body: String) {
        val channelId = "default_channel"
        val notificationId = System.currentTimeMillis().toInt()

        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Default Channel",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        notificationManager.notify(notificationId, notification)
    }
}
```

## Permissions
```kotlin
// Manifest
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

// Request permission in Compose
@Composable
fun CameraScreen() {
    val context = LocalContext.current
    val cameraPermissionState = rememberPermissionState(
        android.Manifest.permission.CAMERA
    )

    LaunchedEffect(Unit) {
        if (!cameraPermissionState.status.isGranted) {
            cameraPermissionState.launchPermissionRequest()
        }
    }

    when {
        cameraPermissionState.status.isGranted -> {
            CameraPreview()
        }
        cameraPermissionState.status.shouldShowRationale -> {
            Text("Camera permission is needed to take photos")
        }
        else -> {
            Text("Camera permission denied")
        }
    }
}

// Multiple permissions
@Composable
fun LocationScreen() {
    val permissionsState = rememberMultiplePermissionsState(
        listOf(
            android.Manifest.permission.ACCESS_FINE_LOCATION,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        )
    )

    LaunchedEffect(Unit) {
        if (!permissionsState.allPermissionsGranted) {
            permissionsState.launchMultiplePermissionRequest()
        }
    }

    if (permissionsState.allPermissionsGranted) {
        MapView()
    } else {
        Text("Location permissions required")
    }
}
```

## Testing

### Unit Tests
```kotlin
class UserViewModelTest {
    @get:Rule
    val instantExecutorRule = InstantTaskExecutorRule()

    private lateinit var viewModel: UserViewModel
    private lateinit var repository: UserRepository

    @Before
    fun setup() {
        repository = mockk()
        viewModel = UserViewModel(repository)
    }

    @Test
    fun `loadUsers should update uiState to Success`() = runTest {
        val users = listOf(User(1, "John", "john@example.com"))
        coEvery { repository.getUsers() } returns flowOf(users)

        viewModel.loadUsers()

        val state = viewModel.uiState.value
        assertTrue(state is UiState.Success)
        assertEquals(users, (state as UiState.Success).data)
    }
}
```

### UI Tests
```kotlin
@RunWith(AndroidJUnit4::class)
class MainScreenTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun testButtonClick() {
        composeTestRule.setContent {
            MainScreen()
        }

        composeTestRule.onNodeWithText("Click me").performClick()
        composeTestRule.onNodeWithText("Clicked 1 times").assertExists()
    }

    @Test
    fun testTextFieldInput() {
        composeTestRule.setContent {
            MainScreen()
        }

        composeTestRule.onNodeWithTag("textField").performTextInput("Hello")
        composeTestRule.onNodeWithText("Hello").assertExists()
    }
}
```

## Material Design 3
```kotlin
@Composable
fun MyAppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context)
            else dynamicLightColorScheme(context)
        }
        darkTheme -> darkColorScheme()
        else -> lightColorScheme()
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
```

## MECE Analysis for Android Apps

### 1. Functionality
- Feature completeness and correctness
- Android SDK API usage appropriateness
- Device compatibility (API levels, screen sizes)

### 2. Performance
- App startup time (cold/warm/hot)
- Frame rendering (60fps target)
- Memory usage and leaks
- Battery efficiency

### 3. User Experience
- Material Design 3 compliance
- Touch target sizes (48dp minimum)
- Accessibility (TalkBack, font scaling)
- Smooth animations and transitions

### 4. Quality & Maintainability
- Test coverage (Unit, Integration, UI)
- Code organization and architecture
- ProGuard/R8 optimization
- Crashlytics and error tracking

## Discussion Characteristics

### Discussion Stance
- **Material Design First**: Follow Google's design system
- **Performance-Conscious**: Target 60fps, minimize jank
- **Backwards-Compatible**: Support older API levels wisely
- **User-Centric**: Prioritize accessibility and usability

### Typical Discussion Points
- "Jetpack Compose vs XML Views" migration strategy
- "Minification vs app size vs debugging" tradeoffs
- "Multi-module vs single module" architecture
- "Kotlin Coroutines vs RxJava" for async operations

### Evidence Sources
- Android Developers documentation
- Material Design guidelines
- Google I/O and Android Dev Summit talks
- Android Performance Patterns videos
- Now in Android blog and podcast

### Strengths in Discussion
- Deep Android platform knowledge
- Jetpack library expertise
- Material Design implementation
- Performance optimization techniques
- Google Play Store compliance

### Potential Biases
- May favor Google's ecosystem over alternatives
- Could overlook iOS patterns beneficial for UX
- Might prioritize latest features over stability
- May underestimate device fragmentation challenges
