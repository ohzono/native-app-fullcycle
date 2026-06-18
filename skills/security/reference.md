# Security 詳細リファレンス

このドキュメントは [security SKILL.md](SKILL.md) の詳細リファレンスです。

## API Security

### Authentication
```javascript
// JWT with proper validation
const jwt = require('jsonwebtoken')

function generateToken(user) {
  return jwt.sign(
    { userId: user.id, email: user.email },
    process.env.JWT_SECRET,
    {
      expiresIn: '15m',
      issuer: 'api.example.com',
      audience: 'example.com'
    }
  )
}

function verifyToken(token) {
  try {
    return jwt.verify(token, process.env.JWT_SECRET, {
      issuer: 'api.example.com',
      audience: 'example.com'
    })
  } catch (err) {
    throw new Error('Invalid token')
  }
}
```

### CORS Configuration
```javascript
const cors = require('cors')

app.use(cors({
  origin: ['https://app.example.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}))
```

### Input Validation
```javascript
const Joi = require('joi')

const userSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(12).required(),
  age: Joi.number().integer().min(0).max(150),
  username: Joi.string().alphanum().min(3).max(30).required()
})

async function createUser(req, res) {
  try {
    const validated = await userSchema.validateAsync(req.body)
    // Use validated data
  } catch (err) {
    return res.status(400).json({ error: err.details })
  }
}
```

## Mobile App Security

### iOS Security
```swift
// Keychain storage for sensitive data
import Security

func saveToKeychain(key: String, data: Data) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    SecItemAdd(query as CFDictionary, nil)
}

// Certificate pinning
let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

func urlSession(_ session: URLSession,
                didReceive challenge: URLAuthenticationChallenge,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    // Implement certificate pinning
}

// Detect jailbreak
func isJailbroken() -> Bool {
    // Check for common jailbreak files/paths
    // Use obfuscation in production
}
```

### Android Security
```kotlin
// Encrypted SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val encryptedPrefs = EncryptedSharedPreferences.create(
    context,
    "secret_prefs",
    masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)

// Certificate pinning with OkHttp
val certificatePinner = CertificatePinner.Builder()
    .add("api.example.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    .build()

val client = OkHttpClient.Builder()
    .certificatePinner(certificatePinner)
    .build()

// ProGuard/R8 obfuscation
// Enable in build.gradle
```

## Security Testing

### Tools
- **Static Analysis**: SonarQube, Semgrep, ESLint security plugins
- **Dependency Scanning**: Snyk, OWASP Dependency-Check
- **Dynamic Analysis**: OWASP ZAP, Burp Suite
- **Secrets Detection**: GitGuardian, TruffleHog
- **Container Scanning**: Trivy, Clair

### Penetration Testing Checklist
- [ ] Authentication bypass attempts
- [ ] Authorization testing (horizontal/vertical privilege escalation)
- [ ] Input validation (SQL injection, XSS, command injection)
- [ ] Session management
- [ ] CSRF protection
- [ ] API security
- [ ] File upload vulnerabilities
- [ ] Rate limiting
- [ ] Information disclosure

## Best Practices

### Secure Development Lifecycle
1. **Design**: Threat modeling, secure architecture
2. **Development**: Secure coding practices, code review
3. **Testing**: Security testing, penetration testing
4. **Deployment**: Secure configuration, secrets management
5. **Monitoring**: Logging, alerting, incident response

### Defense in Depth
- Multiple layers of security controls
- Assume breach mentality
- Principle of least privilege
- Fail securely
- Keep security simple

### Secrets Management
```bash
# Never commit secrets to version control
# Use .gitignore for sensitive files
echo ".env" >> .gitignore

# Use environment variables
# Or secret management tools:
# - AWS Secrets Manager
# - HashiCorp Vault
# - Azure Key Vault
# - Google Secret Manager

# Rotate secrets regularly
# Use different secrets per environment
```

## When to Use This Skill
- Implementing authentication and authorization
- Fixing security vulnerabilities
- Code review with security focus
- Designing secure architectures
- API security implementation
- Mobile app security
- Security testing and auditing
- Incident response
- Security best practices questions
