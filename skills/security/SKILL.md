---
name: security
description: OWASP Top 10脆弱性、セキュアコーディングプラクティス、認証、暗号化、APIセキュリティ、セキュリティテストをカバーするアプリケーションセキュリティの専門知識。セキュリティ機能の実装、脆弱性の修正、セキュリティベストプラクティスの議論時に使用します。
allowed-tools: Read, Glob, Grep, WebSearch
model: opus
user-invocable: false
---

# Security Skill

## Overview
Comprehensive security expertise for building secure applications, covering common vulnerabilities, secure coding practices, and defense-in-depth strategies.

## OWASP Top 10 (2021基準)

> **版数について**: 本節は OWASP Top 10 **2021 版**の構造（A01-A10）に基づく。**2025 版**（2025-11 正式公開）では主に以下が再編された:
> - SSRF（2021 の A10）は A01: Broken Access Control に統合
> - 新カテゴリ「Software Supply Chain Failures」「Mishandling of Exceptional Conditions」が追加
>
> 最新版は https://owasp.org/Top10/ を参照（OWASP Top 10 は CC BY-SA 4.0 で提供されている）。

### A01: Broken Access Control
**Vulnerability**: Users can access resources/actions beyond their permissions

**Examples:**
- Accessing `/api/users/123` when should only access own profile
- Bypassing authorization checks by modifying URLs
- Privilege escalation

**Prevention:**
```javascript
// ✓ Good: Check authorization
async function getUser(req, res) {
  const userId = req.params.id
  const currentUser = req.user

  // Check if user can access this resource
  if (userId !== currentUser.id && !currentUser.isAdmin) {
    return res.status(403).json({ error: 'Forbidden' })
  }

  const user = await db.getUser(userId)
  return res.json(user)
}

// ✗ Bad: No authorization check
async function getUser(req, res) {
  const user = await db.getUser(req.params.id)
  return res.json(user)
}
```

**Best Practices:**
- Deny by default, allow explicitly
- Use centralized authorization
- Implement RBAC or ABAC
- Test authorization for all endpoints
- Don't rely on client-side checks

### A02: Cryptographic Failures
**Vulnerability**: Sensitive data exposed due to weak or missing encryption

**Prevention:**
```javascript
// ✓ Password hashing with bcrypt
const bcrypt = require('bcrypt')
const saltRounds = 12

async function hashPassword(password) {
  return await bcrypt.hash(password, saltRounds)
}

async function verifyPassword(password, hash) {
  return await bcrypt.compare(password, hash)
}

// ✓ Encrypt sensitive data at rest
const crypto = require('crypto')
const algorithm = 'aes-256-gcm'

function encrypt(text, key) {
  const iv = crypto.randomBytes(16)
  const cipher = crypto.createCipheriv(algorithm, key, iv)
  let encrypted = cipher.update(text, 'utf8', 'hex')
  encrypted += cipher.final('hex')
  const authTag = cipher.getAuthTag()
  return { encrypted, iv: iv.toString('hex'), authTag: authTag.toString('hex') }
}

// ✓ Use HTTPS everywhere
// Configure TLS 1.2+ only
// Use HSTS header
```

**Best Practices:**
- Use strong, proven algorithms (AES-256, RSA-2048+)
- Never implement your own crypto
- Use bcrypt/argon2 for passwords (not MD5/SHA1)
- Encrypt sensitive data in transit (TLS) and at rest
- Properly manage encryption keys
- Use secure random number generators

### A03: Injection
**Vulnerability**: Untrusted data sent to interpreter as part of command/query

**SQL Injection Prevention:**
```javascript
// ✓ Good: Parameterized queries
async function getUser(email) {
  return await db.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  )
}

// ✗ Bad: String concatenation
async function getUser(email) {
  return await db.query(
    `SELECT * FROM users WHERE email = '${email}'`
  )
  // Vulnerable: email = "' OR '1'='1"
}

// ✓ ORM usage
const user = await User.findOne({ where: { email } })
```

**NoSQL Injection Prevention:**
```javascript
// ✓ Good: Type validation
async function getUser(userId) {
  // Ensure userId is a number
  const id = parseInt(userId, 10)
  if (isNaN(id)) throw new Error('Invalid ID')

  return await db.collection('users').findOne({ _id: id })
}

// ✗ Bad: Direct object injection
async function getUser(query) {
  return await db.collection('users').findOne(query)
  // Vulnerable: query = { $ne: null } returns all users
}
```

**Command Injection Prevention:**
```javascript
// ✓ Good: Use libraries, validate input
const { exec } = require('child_process')

async function resizeImage(filename) {
  // Whitelist allowed filenames
  if (!/^[a-zA-Z0-9_-]+\.(jpg|png)$/.test(filename)) {
    throw new Error('Invalid filename')
  }

  // Better: Use a library instead of shell command
  await sharp(filename).resize(200, 200).toFile('output.jpg')
}

// ✗ Bad: Unsanitized input in shell command
async function resizeImage(filename) {
  exec(`convert ${filename} -resize 200x200 output.jpg`)
  // Vulnerable: filename = "file.jpg; rm -rf /"
}
```

### A04: Insecure Design
**Prevention:**
- Threat modeling during design phase
- Secure design patterns
- Input validation framework
- Defense in depth
- Principle of least privilege

### A05: Security Misconfiguration
**Common Issues:**
- Default credentials
- Unnecessary features enabled
- Verbose error messages
- Missing security headers
- Outdated software

**Prevention:**
```javascript
// ✓ Security headers
const helmet = require('helmet')
app.use(helmet())

app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'", "'unsafe-inline'"],
    styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", "data:", "https:"],
  }
}))

// ✓ Disable unnecessary features
app.disable('x-powered-by')

// ✓ Environment-specific error handling
if (process.env.NODE_ENV === 'production') {
  app.use((err, req, res, next) => {
    console.error(err) // Log full error server-side
    res.status(500).json({ error: 'Internal server error' })
  })
} else {
  app.use((err, req, res, next) => {
    res.status(500).json({ error: err.message, stack: err.stack })
  })
}
```

### A06: Vulnerable and Outdated Components
**Prevention:**
```bash
# Regular dependency audits
npm audit
npm audit fix

# Automated dependency updates
# Use Dependabot, Renovate, or Snyk

# Check for known vulnerabilities
npm install -g snyk
snyk test
snyk monitor
```

**Best Practices:**
- Keep dependencies up to date
- Use tools to track vulnerabilities
- Remove unused dependencies
- Review security advisories
- Pin dependency versions
- Use lock files (package-lock.json)

### A07: Identification and Authentication Failures
**Prevention:**
```javascript
// ✓ Strong password requirements
function validatePassword(password) {
  const minLength = 12
  const hasUppercase = /[A-Z]/.test(password)
  const hasLowercase = /[a-z]/.test(password)
  const hasNumber = /[0-9]/.test(password)
  const hasSpecial = /[!@#$%^&*]/.test(password)

  if (password.length < minLength) {
    throw new Error(`Password must be at least ${minLength} characters`)
  }

  if (!hasUppercase || !hasLowercase || !hasNumber || !hasSpecial) {
    throw new Error('Password must contain uppercase, lowercase, number, and special character')
  }
}

// ✓ Rate limiting for login attempts
const rateLimit = require('express-rate-limit')

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts
  message: 'Too many login attempts, please try again later'
})

app.post('/login', loginLimiter, loginHandler)

// ✓ Multi-factor authentication
async function verifyMFA(userId, code) {
  const user = await db.getUser(userId)
  const isValid = speakeasy.totp.verify({
    secret: user.mfaSecret,
    encoding: 'base32',
    token: code,
    window: 2
  })

  if (!isValid) {
    throw new Error('Invalid MFA code')
  }
}

// ✓ Session management
const session = require('express-session')
const RedisStore = require('connect-redis').default

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: true, // HTTPS only
    httpOnly: true, // No client-side access
    maxAge: 3600000, // 1 hour
    sameSite: 'strict' // CSRF protection
  }
}))
```

### A08: Software and Data Integrity Failures
**Prevention:**
- Verify digital signatures
- Use trusted repositories
- Implement CI/CD security
- Code signing
- Integrity checks for updates

```javascript
// Verify npm package integrity
// npm uses package-lock.json integrity hashes automatically

// Subresource Integrity (SRI) for CDN
<script
  src="https://cdn.example.com/lib.js"
  integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/ux..."
  crossorigin="anonymous"
></script>
```

### A09: Security Logging and Monitoring Failures
**Prevention:**
```javascript
// ✓ Comprehensive security logging
const winston = require('winston')

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'security.log' })
  ]
})

// Log security events
function logSecurityEvent(event, details) {
  logger.warn('Security event', {
    event,
    ...details,
    timestamp: new Date(),
    ip: details.ip,
    userId: details.userId,
  })
}

// Examples of events to log
// - Login attempts (success and failure)
// - Authorization failures
// - Input validation failures
// - Rate limit violations
// - Suspicious patterns

// ✓ Alerting for critical events
async function handleFailedLogin(userId, ip) {
  const recentFailures = await countRecentFailures(userId, ip)

  if (recentFailures > 5) {
    await sendAlert({
      type: 'SUSPICIOUS_ACTIVITY',
      message: `Multiple failed login attempts for user ${userId} from ${ip}`,
      severity: 'HIGH'
    })
  }
}
```

### A10: Server-Side Request Forgery (SSRF)
**Vulnerability**: Application fetches remote resource without validating URL

**Prevention:**
```javascript
// ✓ Good: Validate and whitelist URLs
async function fetchUrl(url) {
  const parsed = new URL(url)

  // Whitelist allowed domains
  const allowedDomains = ['api.example.com', 'cdn.example.com']
  if (!allowedDomains.includes(parsed.hostname)) {
    throw new Error('Domain not allowed')
  }

  // Prevent access to internal networks
  const hostname = parsed.hostname
  if (
    hostname === 'localhost' ||
    hostname.startsWith('127.') ||
    hostname.startsWith('192.168.') ||
    hostname.startsWith('10.') ||
    hostname.startsWith('172.')
  ) {
    throw new Error('Internal network access not allowed')
  }

  return await fetch(url)
}

// ✗ Bad: No validation
async function fetchUrl(url) {
  return await fetch(url)
  // Vulnerable: url = "http://localhost:8080/admin"
}
```

## 詳細リファレンス

より詳細な技術リファレンス、コード例、チェックリストは [reference.md](reference.md) を参照してください。

## 参考資料

- OWASP Top 10: https://owasp.org/Top10/ （CC BY-SA 4.0。本 skill の OWASP 由来の内容は 2021 版に基づき、2025 版の主要変更は冒頭の注記参照）
