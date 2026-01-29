# API Key Management Complete Guide

**Purpose:** Complete guide to implementing enterprise-grade API key management systems  
**Based On:** GiDanc Health Check & VibeCoder API key implementations  
**Status:** ✅ Production-Ready  
**Last Updated:** November 25, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [When to Use API Keys](#when-to-use-api-keys)
3. [Security Architecture](#security-architecture)
4. [Phase 1: Database Schema Design](#phase-1-database-schema-design)
5. [Phase 2: Key Generation](#phase-2-key-generation)
6. [Phase 3: Key Validation](#phase-3-key-validation)
7. [Phase 4: Authentication Middleware](#phase-4-authentication-middleware)
8. [Phase 5: Key Management UI](#phase-5-key-management-ui)
9. [Phase 6: Audit & Monitoring](#phase-6-audit--monitoring)
10. [Phase 7: Key Rotation](#phase-7-key-rotation)
11. [Testing API Keys](#testing-api-keys)
12. [Production Deployment](#production-deployment)
13. [Common Pitfalls](#common-pitfalls)
14. [Appendix](#appendix)

---

## Overview

### What is an API Key?

An **API key** is a credential that allows external systems or automated services to authenticate with your API without user interaction (username/password or OAuth flow).

### Why Use API Keys?

**Use Cases:**
- ✅ **Server-to-Server Communication** - Microservices, integrations
- ✅ **CI/CD Pipelines** - Automated testing, deployments
- ✅ **SDK/Client Libraries** - Programmatic access
- ✅ **Startup Scripts** - Pre-flight health checks
- ✅ **Webhook Verification** - Secure callback endpoints

**Benefits:**
- **No User Interaction:** Headless authentication
- **Granular Permissions:** Scope keys to specific operations
- **Easy Rotation:** Replace keys without changing passwords
- **Rate Limiting:** Control usage per key
- **Audit Trail:** Track API usage by key

### Security Fundamentals

🔒 **CRITICAL SECURITY PRINCIPLES:**

1. **NEVER store raw API keys** - Only store bcrypt hashes (12+ rounds)
2. **Show keys only once** - During generation, then never again
3. **Use environment prefixes** - Prevent cross-environment usage
4. **Implement key rotation** - Replace keys every 30-90 days
5. **Audit everything** - Log all key operations (GDPR-compliant)
6. **Rate limit aggressively** - Prevent abuse
7. **Expire keys automatically** - Default 90-day expiration

---

## When to Use API Keys

### ✅ Use API Keys When:

1. **Building a Public API** - Third-party developers need access
2. **Server-to-Server Auth** - Microservices, background jobs
3. **SDK/Client Library** - Programmatic API access
4. **CI/CD Integration** - Automated testing, deployments
5. **Startup Health Checks** - Verify AI system ethical alignment before launch

### ❌ Don't Use API Keys When:

1. **User Authentication** - Use OAuth, sessions, or JWT instead
2. **Browser-Based Apps** - API keys exposed in client code (security risk!)
3. **Mobile Apps** - Keys can be extracted from app bundles
4. **Short-Lived Access** - Use temporary tokens instead
5. **Complex Permission Models** - Use OAuth with scopes

### Dual Authentication Pattern

**Best Practice:** Support BOTH session-based auth AND API keys:

```typescript
// Session-based (users in browser)
if (session?.user) {
  return handler(req, res);
}

// API key-based (automated systems, SDKs)
if (validApiKey) {
  return handler(req, res);
}

// No valid authentication
return res.status(401).json({ error: 'Authentication required' });
```

---

## Security Architecture

### Threat Model

**What We're Protecting Against:**

1. **Key Theft** - Attacker steals API key from logs, code, or database
2. **Key Exposure** - Developer accidentally commits key to git
3. **Brute Force** - Attacker tries to guess valid keys
4. **Replay Attacks** - Attacker reuses intercepted keys
5. **Environment Confusion** - Test keys used in production
6. **Over-Privileged Keys** - Keys with more access than needed

### Defense Layers

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: Format & Cryptographic Generation         │
│ - crypto.randomBytes(32) for unpredictability      │
│ - Environment prefix (live/test/dev isolation)     │
│ - 74-character format: prefix_env_64hexchars       │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Layer 2: Secure Storage                            │
│ - bcrypt hash with 12+ rounds (NEVER raw key!)    │
│ - UUID primary keys (non-guessable)               │
│ - Encrypted database backups                       │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Layer 3: Validation & Rate Limiting                │
│ - Environment prefix validation                    │
│ - Constant-time comparison (bcrypt handles this)   │
│ - Rate limiting (per-minute and per-hour)          │
│ - IP whitelisting (optional)                       │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Layer 4: Audit & Monitoring                        │
│ - GDPR-compliant audit logs (hashed IPs)           │
│ - Failed authentication monitoring                 │
│ - Usage statistics and anomaly detection           │
│ - Automatic expiration warnings                    │
└─────────────────────────────────────────────────────┘
```

---

## Phase 1: Database Schema Design

### Step 1.1: Core API Keys Table

```sql
-- api_keys table: Stores hashed API keys
CREATE TABLE api_keys (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Foreign keys
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES users(id),
  
  -- Key data (NEVER store raw key!)
  key_hash VARCHAR(255) NOT NULL UNIQUE,
  label VARCHAR(100) NOT NULL,
  last_four_chars VARCHAR(4) NOT NULL, -- e.g., "ab12" for display
  
  -- Environment isolation
  environment VARCHAR(10) NOT NULL DEFAULT 'live',
  CONSTRAINT valid_environment CHECK (environment IN ('live', 'test', 'dev')),
  
  -- Status tracking
  active BOOLEAN NOT NULL DEFAULT true,
  revoked_at TIMESTAMP,
  revoked_by UUID REFERENCES users(id),
  revocation_reason TEXT,
  
  -- Expiration
  expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '90 days'),
  expiry_warning_sent BOOLEAN DEFAULT false,
  
  -- Usage tracking
  last_used_at TIMESTAMP,
  usage_count INTEGER DEFAULT 0,
  
  -- Audit timestamps
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Performance indexes
CREATE INDEX idx_api_keys_org_env_active 
  ON api_keys(organization_id, environment, active);

CREATE INDEX idx_api_keys_key_hash 
  ON api_keys(key_hash) WHERE active = true;

CREATE INDEX idx_api_keys_expires 
  ON api_keys(expires_at) WHERE active = true;

-- Business rule: Max 10 keys per org per environment
CREATE UNIQUE INDEX idx_api_keys_limit 
  ON api_keys(organization_id, environment, label)
  WHERE active = true;

-- Update timestamp trigger
CREATE TRIGGER update_api_keys_updated_at
  BEFORE UPDATE ON api_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

### Step 1.2: Audit Log Table

```sql
-- api_key_audit_log: GDPR-compliant audit trail
CREATE TABLE api_key_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Relationships
  api_key_id UUID REFERENCES api_keys(id) ON DELETE SET NULL,
  organization_id UUID NOT NULL REFERENCES organizations(id),
  user_id UUID REFERENCES users(id),
  
  -- Event details
  action VARCHAR(50) NOT NULL,
  -- Actions: created, validated, revoked, expired, failed_validation, rate_limited
  
  success BOOLEAN DEFAULT true,
  error_code VARCHAR(50),
  error_message TEXT,
  
  -- Request metadata (GDPR-compliant)
  ip_address_hash VARCHAR(64), -- HMAC-SHA256 of IP (not raw IP!)
  user_agent TEXT,
  endpoint TEXT,
  http_method VARCHAR(10),
  response_code INTEGER,
  
  -- Additional metadata
  metadata JSONB,
  
  -- Timestamp
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for querying audit logs
CREATE INDEX idx_audit_log_api_key 
  ON api_key_audit_log(api_key_id, created_at DESC);

CREATE INDEX idx_audit_log_org_action 
  ON api_key_audit_log(organization_id, action, created_at DESC);

CREATE INDEX idx_audit_log_failed 
  ON api_key_audit_log(created_at DESC) 
  WHERE success = false;

-- Retention policy: Delete logs older than 1 year
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS void AS $$
BEGIN
  DELETE FROM api_key_audit_log
  WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '1 year';
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup (run monthly)
-- SELECT cron.schedule('cleanup-audit-logs', '0 0 1 * *', 'SELECT cleanup_old_audit_logs()');
```

### Step 1.3: Prisma Schema

```prisma
// schema.prisma
model ApiKey {
  id              String    @id @default(uuid()) @db.Uuid
  organizationId  String    @db.Uuid
  createdBy       String    @db.Uuid
  
  // Key data (hashed)
  keyHash         String    @unique @map("key_hash") @db.VarChar(255)
  label           String    @db.VarChar(100)
  lastFourChars   String    @map("last_four_chars") @db.VarChar(4)
  
  // Environment
  environment     String    @default("live") @db.VarChar(10)
  
  // Status
  active          Boolean   @default(true)
  revokedAt       DateTime? @map("revoked_at")
  revokedBy       String?   @map("revoked_by") @db.Uuid
  revocationReason String?  @map("revocation_reason")
  
  // Expiration
  expiresAt       DateTime  @default(dbgenerated("CURRENT_TIMESTAMP + INTERVAL '90 days'")) @map("expires_at")
  expiryWarningSent Boolean @default(false) @map("expiry_warning_sent")
  
  // Usage tracking
  lastUsedAt      DateTime? @map("last_used_at")
  usageCount      Int       @default(0) @map("usage_count")
  
  // Timestamps
  createdAt       DateTime  @default(now()) @map("created_at")
  updatedAt       DateTime  @updatedAt @map("updated_at")
  
  // Relations
  organization    Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  creator         User         @relation("ApiKeyCreator", fields: [createdBy], references: [id])
  revoker         User?        @relation("ApiKeyRevoker", fields: [revokedBy], references: [id])
  auditLogs       ApiKeyAuditLog[]
  
  @@index([organizationId, environment, active])
  @@index([keyHash], map: "idx_api_keys_key_hash", where: { active: true })
  @@index([expiresAt], where: { active: true })
  @@unique([organizationId, environment, label], where: { active: true })
  @@map("api_keys")
}

model ApiKeyAuditLog {
  id             String    @id @default(uuid()) @db.Uuid
  apiKeyId       String?   @map("api_key_id") @db.Uuid
  organizationId String    @map("organization_id") @db.Uuid
  userId         String?   @map("user_id") @db.Uuid
  
  // Event details
  action         String    @db.VarChar(50)
  success        Boolean   @default(true)
  errorCode      String?   @map("error_code") @db.VarChar(50)
  errorMessage   String?   @map("error_message")
  
  // Request metadata (GDPR-compliant)
  ipAddressHash  String?   @map("ip_address_hash") @db.VarChar(64)
  userAgent      String?   @map("user_agent")
  endpoint       String?
  httpMethod     String?   @map("http_method") @db.VarChar(10)
  responseCode   Int?      @map("response_code")
  
  // Additional metadata
  metadata       Json?
  
  // Timestamp
  createdAt      DateTime  @default(now()) @map("created_at")
  
  // Relations
  apiKey         ApiKey?   @relation(fields: [apiKeyId], references: [id], onDelete: SetNull)
  organization   Organization @relation(fields: [organizationId], references: [id])
  user           User?     @relation(fields: [userId], references: [id])
  
  @@index([apiKeyId, createdAt(sort: Desc)])
  @@index([organizationId, action, createdAt(sort: Desc)])
  @@index([createdAt(sort: Desc)], where: { success: false })
  @@map("api_key_audit_log")
}
```

---

## Phase 2: Key Generation

### Step 2.1: Key Format Design

**Format:** `{prefix}_{environment}_{secret}`

**Example:**
```
hck_live_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
│   │    │
│   │    └─ 64 hex characters (32 bytes of entropy)
│   └────── Environment: live, test, dev
└────────── Prefix: Unique to your product (e.g., "hck" for Health Check)
```

**Why This Format?**
- **Prefix identifies product** - Easy to recognize in logs
- **Environment prevents cross-usage** - Test keys can't be used in prod
- **64 hex chars = 256 bits entropy** - Cryptographically secure
- **Total length: 74 characters** - Easy to validate

### Step 2.2: Key Generation Implementation

```typescript
// lib/api-keys/generator.ts
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import { prisma } from '@/lib/db';

const KEY_PREFIX = 'hck'; // Change to your product prefix
const BCRYPT_ROUNDS = 12; // Security standard
const KEY_ENTROPY_BYTES = 32; // 256 bits

export interface GenerateKeyOptions {
  organizationId: string;
  userId: string;
  label: string;
  environment?: 'live' | 'test' | 'dev';
  expiresInDays?: number;
}

export interface GeneratedKey {
  keyId: string;
  apiKey: string; // ONLY RETURNED ONCE!
  label: string;
  environment: string;
  expiresAt: Date;
  lastFourChars: string;
}

export class ApiKeyGenerator {
  /**
   * Generate a new API key
   * 
   * SECURITY NOTES:
   * - Key is shown ONLY ONCE during generation
   * - Stored as bcrypt hash (12 rounds)
   * - Cryptographically secure random generation
   * - Environment prefix enforces isolation
   */
  static async generateApiKey(
    options: GenerateKeyOptions
  ): Promise<GeneratedKey> {
    const {
      organizationId,
      userId,
      label,
      environment = 'live',
      expiresInDays = 90,
    } = options;

    // 1. Validate organization has room for more keys
    const existingKeys = await prisma.apiKey.count({
      where: {
        organizationId,
        environment,
        active: true,
      },
    });

    if (existingKeys >= 10) {
      throw new Error(
        `Maximum API keys (10) reached for environment "${environment}". ` +
        `Please revoke unused keys before creating new ones.`
      );
    }

    // 2. Generate cryptographically secure key
    const secret = crypto.randomBytes(KEY_ENTROPY_BYTES).toString('hex');
    const apiKey = `${KEY_PREFIX}_${environment}_${secret}`;

    // 3. Create bcrypt hash for storage
    const keyHash = await bcrypt.hash(apiKey, BCRYPT_ROUNDS);

    // 4. Calculate expiration
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + expiresInDays);

    // 5. Store in database (only hash, NEVER raw key!)
    const savedKey = await prisma.apiKey.create({
      data: {
        organizationId,
        createdBy: userId,
        keyHash,
        label,
        lastFourChars: secret.slice(-4),
        environment,
        expiresAt,
        active: true,
      },
    });

    // 6. Audit log
    await prisma.apiKeyAuditLog.create({
      data: {
        apiKeyId: savedKey.id,
        organizationId,
        userId,
        action: 'created',
        success: true,
        metadata: {
          label,
          environment,
          expiresAt: expiresAt.toISOString(),
        },
      },
    });

    // 7. Return key (ONLY TIME IT'S VISIBLE!)
    return {
      keyId: savedKey.id,
      apiKey, // Store this securely!
      label: savedKey.label,
      environment: savedKey.environment,
      expiresAt: savedKey.expiresAt,
      lastFourChars: savedKey.lastFourChars,
    };
  }

  /**
   * Calculate last four characters for display
   */
  static getLastFourChars(apiKey: string): string {
    const parts = apiKey.split('_');
    const secret = parts[parts.length - 1];
    return secret.slice(-4);
  }

  /**
   * Validate API key format (before attempting validation)
   */
  static validateKeyFormat(apiKey: string): {
    valid: boolean;
    error?: string;
  } {
    // Format: prefix_environment_secret
    const parts = apiKey.split('_');

    if (parts.length !== 3) {
      return {
        valid: false,
        error: 'Invalid key format. Expected: prefix_environment_secret',
      };
    }

    const [prefix, environment, secret] = parts;

    if (prefix !== KEY_PREFIX) {
      return {
        valid: false,
        error: `Invalid key prefix. Expected "${KEY_PREFIX}"`,
      };
    }

    if (!['live', 'test', 'dev'].includes(environment)) {
      return {
        valid: false,
        error: 'Invalid environment. Must be: live, test, or dev',
      };
    }

    if (secret.length !== 64 || !/^[a-f0-9]+$/.test(secret)) {
      return {
        valid: false,
        error: 'Invalid secret format. Expected 64 hex characters',
      };
    }

    return { valid: true };
  }
}
```

---

## Phase 3: Key Validation

### Step 3.1: Validation Logic

```typescript
// lib/api-keys/validator.ts
import bcrypt from 'bcrypt';
import { prisma } from '@/lib/db';
import { ApiKeyGenerator } from './generator';

export interface ValidationResult {
  valid: boolean;
  apiKeyId?: string;
  organizationId?: string;
  environment?: string;
  userId?: string;
  error?: string;
  errorCode?: string;
}

export class ApiKeyValidator {
  /**
   * Validate API key and return associated data
   * 
   * SECURITY NOTES:
   * - Uses constant-time comparison (bcrypt)
   * - Checks environment prefix
   * - Verifies expiration
   * - Rate limits validation attempts
   * - Logs all validation attempts
   */
  static async validateApiKey(
    providedKey: string,
    options?: {
      ipAddress?: string;
      userAgent?: string;
      endpoint?: string;
    }
  ): Promise<ValidationResult> {
    // 1. Format validation (quick rejection)
    const formatCheck = ApiKeyGenerator.validateKeyFormat(providedKey);
    if (!formatCheck.valid) {
      await this.logValidationAttempt({
        success: false,
        errorCode: 'INVALID_FORMAT',
        errorMessage: formatCheck.error,
        ...options,
      });

      return {
        valid: false,
        error: formatCheck.error,
        errorCode: 'INVALID_FORMAT',
      };
    }

    // 2. Extract environment from key
    const environment = providedKey.split('_')[1];

    // 3. Find all active keys for this environment
    const activeKeys = await prisma.apiKey.findMany({
      where: {
        environment,
        active: true,
        expiresAt: {
          gt: new Date(), // Not expired
        },
      },
      include: {
        organization: {
          select: {
            id: true,
            name: true,
          },
        },
        creator: {
          select: {
            id: true,
            email: true,
          },
        },
      },
    });

    // 4. Try to match key against all active keys (constant-time)
    for (const key of activeKeys) {
      const isMatch = await bcrypt.compare(providedKey, key.keyHash);

      if (isMatch) {
        // 5. Update usage statistics
        await prisma.apiKey.update({
          where: { id: key.id },
          data: {
            lastUsedAt: new Date(),
            usageCount: {
              increment: 1,
            },
          },
        });

        // 6. Log successful validation
        await this.logValidationAttempt({
          apiKeyId: key.id,
          organizationId: key.organizationId,
          userId: key.createdBy,
          success: true,
          ...options,
        });

        // 7. Return validation result
        return {
          valid: true,
          apiKeyId: key.id,
          organizationId: key.organizationId,
          environment: key.environment,
          userId: key.createdBy,
        };
      }
    }

    // 8. No match found - log failed attempt
    await this.logValidationAttempt({
      success: false,
      errorCode: 'INVALID_KEY',
      errorMessage: 'API key not found or revoked',
      ...options,
    });

    return {
      valid: false,
      error: 'Invalid API key',
      errorCode: 'INVALID_KEY',
    };
  }

  /**
   * Check if API key is expired soon (warning threshold)
   */
  static async checkExpiringSoon(
    apiKeyId: string,
    warningDays: number = 14
  ): Promise<boolean> {
    const key = await prisma.apiKey.findUnique({
      where: { id: apiKeyId },
      select: { expiresAt: true, expiryWarningSent: true },
    });

    if (!key) return false;

    const daysUntilExpiry = Math.floor(
      (key.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24)
    );

    return daysUntilExpiry <= warningDays && !key.expiryWarningSent;
  }

  /**
   * Log validation attempt (GDPR-compliant)
   */
  private static async logValidationAttempt(data: {
    apiKeyId?: string;
    organizationId?: string;
    userId?: string;
    success: boolean;
    errorCode?: string;
    errorMessage?: string;
    ipAddress?: string;
    userAgent?: string;
    endpoint?: string;
  }) {
    // Hash IP address for GDPR compliance
    const ipAddressHash = data.ipAddress
      ? this.hashIpAddress(data.ipAddress)
      : null;

    await prisma.apiKeyAuditLog.create({
      data: {
        apiKeyId: data.apiKeyId,
        organizationId: data.organizationId,
        userId: data.userId,
        action: 'validated',
        success: data.success,
        errorCode: data.errorCode,
        errorMessage: data.errorMessage,
        ipAddressHash,
        userAgent: data.userAgent,
        endpoint: data.endpoint,
      },
    });
  }

  /**
   * Hash IP address using HMAC-SHA256 (GDPR-compliant)
   */
  private static hashIpAddress(ip: string): string {
    const salt = process.env.IP_HASH_SALT || 'change-in-production';
    return crypto
      .createHmac('sha256', salt)
      .update(ip)
      .digest('hex');
  }
}
```

---

## Phase 4: Authentication Middleware

### Step 4.1: Dual Authentication Middleware

```typescript
// lib/middleware/authenticate.ts
import { NextApiRequest, NextApiResponse } from 'next';
import { getSession } from 'next-auth/react';
import { ApiKeyValidator } from '../api-keys/validator';

export interface AuthenticatedRequest extends NextApiRequest {
  user: {
    id: string;
    organizationId: string;
    authType: 'session' | 'api_key';
    email?: string;
    apiKeyId?: string;
    environment?: string;
  };
}

export type NextApiHandler = (
  req: AuthenticatedRequest,
  res: NextApiResponse
) => Promise<void> | void;

/**
 * Authentication middleware supporting both sessions and API keys
 * 
 * Usage:
 * export default withAuth(async (req, res) => {
 *   // req.user is guaranteed to exist
 *   const { organizationId, authType } = req.user;
 * });
 */
export function withAuth(handler: NextApiHandler) {
  return async (req: NextApiRequest, res: NextApiResponse) => {
    // 1. Try API key authentication first
    const apiKey = extractApiKey(req);
    
    if (apiKey) {
      const validation = await ApiKeyValidator.validateApiKey(apiKey, {
        ipAddress: getClientIP(req),
        userAgent: req.headers['user-agent'],
        endpoint: req.url,
      });

      if (validation.valid) {
        (req as AuthenticatedRequest).user = {
          id: validation.userId!,
          organizationId: validation.organizationId!,
          authType: 'api_key',
          apiKeyId: validation.apiKeyId,
          environment: validation.environment,
        };

        return handler(req as AuthenticatedRequest, res);
      }

      // API key provided but invalid
      return res.status(401).json({
        error: 'Invalid API key',
        code: validation.errorCode,
        message: validation.error,
      });
    }

    // 2. Fall back to session authentication
    const session = await getSession({ req });

    if (session?.user) {
      (req as AuthenticatedRequest).user = {
        id: session.user.sub,
        organizationId: session.user.organizationId,
        authType: 'session',
        email: session.user.email,
      };

      return handler(req as AuthenticatedRequest, res);
    }

    // 3. No valid authentication
    return res.status(401).json({
      error: 'Authentication required',
      code: 'NO_AUTH',
      message: 'Provide valid API key or authenticate with session',
      hint: 'Include "Authorization: Bearer YOUR_API_KEY" header',
    });
  };
}

/**
 * Extract API key from request headers
 * Supports multiple header formats:
 * - Authorization: Bearer {key}
 * - X-API-Key: {key}
 */
function extractApiKey(req: NextApiRequest): string | null {
  // Check Authorization header
  const authHeader = req.headers.authorization;
  if (authHeader?.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }

  // Check X-API-Key header
  const apiKeyHeader = req.headers['x-api-key'];
  if (typeof apiKeyHeader === 'string') {
    return apiKeyHeader;
  }

  return null;
}

/**
 * Get client IP address (handles proxies)
 */
function getClientIP(req: NextApiRequest): string {
  // Check for proxy headers (Vercel, Cloudflare, etc.)
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string') {
    return forwarded.split(',')[0].trim();
  }

  const realIP = req.headers['x-real-ip'];
  if (typeof realIP === 'string') {
    return realIP;
  }

  // Fallback to connection remote address
  return req.socket.remoteAddress || 'unknown';
}
```

### Step 4.2: Rate Limiting Middleware

```typescript
// lib/middleware/rate-limit.ts
import { NextApiRequest, NextApiResponse } from 'next';
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_URL!,
  token: process.env.UPSTASH_REDIS_TOKEN!,
});

interface RateLimitConfig {
  perMinute?: number;
  perHour?: number;
  perDay?: number;
}

const DEFAULT_LIMITS: Record<string, RateLimitConfig> = {
  live: {
    perMinute: 60,
    perHour: 1000,
    perDay: 10000,
  },
  test: {
    perMinute: 120,
    perHour: 5000,
    perDay: 50000,
  },
  dev: {
    perMinute: 300,
    perHour: 10000,
    perDay: 100000,
  },
};

/**
 * Rate limit API requests by API key or IP
 */
export async function checkRateLimit(
  req: NextApiRequest,
  res: NextApiResponse,
  identifier: string, // API key ID or IP address
  environment: string = 'live'
): Promise<boolean> {
  const limits = DEFAULT_LIMITS[environment];
  const now = Date.now();

  // Check per-minute limit
  const minuteKey = `ratelimit:${identifier}:minute:${Math.floor(now / 60000)}`;
  const minuteCount = await redis.incr(minuteKey);
  await redis.expire(minuteKey, 60);

  if (minuteCount > limits.perMinute!) {
    res.setHeader('X-RateLimit-Limit', limits.perMinute!.toString());
    res.setHeader('X-RateLimit-Remaining', '0');
    res.setHeader('X-RateLimit-Reset', (Math.floor(now / 60000) * 60000 + 60000).toString());
    
    res.status(429).json({
      error: 'Rate limit exceeded',
      code: 'RATE_LIMIT_EXCEEDED',
      message: `Maximum ${limits.perMinute} requests per minute exceeded`,
      resetAt: Math.floor(now / 60000) * 60000 + 60000,
    });
    
    return false;
  }

  // Check per-hour limit
  const hourKey = `ratelimit:${identifier}:hour:${Math.floor(now / 3600000)}`;
  const hourCount = await redis.incr(hourKey);
  await redis.expire(hourKey, 3600);

  if (hourCount > limits.perHour!) {
    res.status(429).json({
      error: 'Rate limit exceeded',
      code: 'RATE_LIMIT_EXCEEDED',
      message: `Maximum ${limits.perHour} requests per hour exceeded`,
      resetAt: Math.floor(now / 3600000) * 3600000 + 3600000,
    });
    
    return false;
  }

  // Set rate limit headers
  res.setHeader('X-RateLimit-Limit', limits.perMinute!.toString());
  res.setHeader('X-RateLimit-Remaining', (limits.perMinute! - minuteCount).toString());
  res.setHeader('X-RateLimit-Reset', (Math.floor(now / 60000) * 60000 + 60000).toString());

  return true;
}
```

---

## Phase 5: Key Management UI

### Step 5.1: API Endpoints

```typescript
// pages/api/api-keys/index.ts
import { withAuth, AuthenticatedRequest } from '@/lib/middleware/authenticate';
import { ApiKeyGenerator } from '@/lib/api-keys/generator';
import { prisma } from '@/lib/db';
import { NextApiResponse } from 'next';

export default withAuth(async (req: AuthenticatedRequest, res: NextApiResponse) => {
  const { organizationId } = req.user;

  // GET: List all API keys for organization
  if (req.method === 'GET') {
    const keys = await prisma.apiKey.findMany({
      where: { organizationId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        label: true,
        lastFourChars: true,
        environment: true,
        active: true,
        expiresAt: true,
        lastUsedAt: true,
        usageCount: true,
        createdAt: true,
      },
    });

    return res.status(200).json({ keys });
  }

  // POST: Generate new API key
  if (req.method === 'POST') {
    const { label, environment, expiresInDays } = req.body;

    // Validation
    if (!label || label.length < 3 || label.length > 100) {
      return res.status(400).json({
        error: 'Invalid label',
        message: 'Label must be between 3 and 100 characters',
      });
    }

    if (environment && !['live', 'test', 'dev'].includes(environment)) {
      return res.status(400).json({
        error: 'Invalid environment',
        message: 'Environment must be: live, test, or dev',
      });
    }

    try {
      const generatedKey = await ApiKeyGenerator.generateApiKey({
        organizationId,
        userId: req.user.id,
        label,
        environment: environment || 'live',
        expiresInDays: expiresInDays || 90,
      });

      return res.status(201).json(generatedKey);
    } catch (error: any) {
      return res.status(400).json({
        error: 'Key generation failed',
        message: error.message,
      });
    }
  }

  res.setHeader('Allow', ['GET', 'POST']);
  return res.status(405).json({ error: `Method ${req.method} not allowed` });
});
```

```typescript
// pages/api/api-keys/[id].ts
import { withAuth, AuthenticatedRequest } from '@/lib/middleware/authenticate';
import { prisma } from '@/lib/db';
import { NextApiResponse } from 'next';

export default withAuth(async (req: AuthenticatedRequest, res: NextApiResponse) => {
  const { id } = req.query;
  const { organizationId, id: userId } = req.user;

  // Verify key belongs to organization
  const key = await prisma.apiKey.findFirst({
    where: {
      id: id as string,
      organizationId,
    },
  });

  if (!key) {
    return res.status(404).json({
      error: 'API key not found',
      message: 'Key does not exist or you do not have permission to access it',
    });
  }

  // DELETE: Revoke API key
  if (req.method === 'DELETE') {
    const { reason } = req.body;

    await prisma.apiKey.update({
      where: { id: key.id },
      data: {
        active: false,
        revokedAt: new Date(),
        revokedBy: userId,
        revocationReason: reason || 'Revoked by user',
      },
    });

    // Audit log
    await prisma.apiKeyAuditLog.create({
      data: {
        apiKeyId: key.id,
        organizationId,
        userId,
        action: 'revoked',
        success: true,
        metadata: { reason },
      },
    });

    return res.status(200).json({
      message: 'API key revoked successfully',
    });
  }

  res.setHeader('Allow', ['DELETE']);
  return res.status(405).json({ error: `Method ${req.method} not allowed` });
});
```

### Step 5.2: React UI Component

```typescript
// components/ApiKeyManager.tsx
'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';

interface ApiKey {
  id: string;
  label: string;
  lastFourChars: string;
  environment: string;
  active: boolean;
  expiresAt: string;
  lastUsedAt?: string;
  usageCount: number;
  createdAt: string;
}

export function ApiKeyManager() {
  const [keys, setKeys] = useState<ApiKey[]>([]);
  const [newKeyLabel, setNewKeyLabel] = useState('');
  const [newKeyEnvironment, setNewKeyEnvironment] = useState<'live' | 'test' | 'dev'>('live');
  const [generatedKey, setGeneratedKey] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // Load existing keys
  useEffect(() => {
    fetchKeys();
  }, []);

  const fetchKeys = async () => {
    const res = await fetch('/api/api-keys');
    const data = await res.json();
    setKeys(data.keys);
  };

  const generateKey = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/api-keys', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          label: newKeyLabel,
          environment: newKeyEnvironment,
        }),
      });

      const data = await res.json();
      
      if (res.ok) {
        setGeneratedKey(data.apiKey);
        setNewKeyLabel('');
        fetchKeys();
      } else {
        alert(`Error: ${data.message}`);
      }
    } finally {
      setLoading(false);
    }
  };

  const revokeKey = async (keyId: string, label: string) => {
    if (!confirm(`Are you sure you want to revoke "${label}"? This cannot be undone.`)) {
      return;
    }

    await fetch(`/api/api-keys/${keyId}`, {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        reason: 'Revoked via UI',
      }),
    });

    fetchKeys();
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">API Key Management</h2>

      {/* Generated Key Display (show only once!) */}
      {generatedKey && (
        <Card className="p-4 bg-yellow-50 border-yellow-200">
          <h3 className="font-semibold text-yellow-900 mb-2">
            ⚠️ Save Your API Key - It Won't Be Shown Again!
          </h3>
          <div className="font-mono bg-white p-3 rounded border border-yellow-300 break-all">
            {generatedKey}
          </div>
          <div className="mt-2 flex gap-2">
            <Button
              size="sm"
              onClick={() => {
                navigator.clipboard.writeText(generatedKey);
                alert('API key copied to clipboard!');
              }}
            >
              Copy to Clipboard
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setGeneratedKey(null)}
            >
              I've Saved It
            </Button>
          </div>
        </Card>
      )}

      {/* Generate New Key */}
      <Card className="p-4">
        <h3 className="font-semibold mb-4">Generate New API Key</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">
              Label
            </label>
            <Input
              value={newKeyLabel}
              onChange={(e) => setNewKeyLabel(e.target.value)}
              placeholder="e.g., Production Server, CI/CD Pipeline"
              maxLength={100}
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              Environment
            </label>
            <select
              value={newKeyEnvironment}
              onChange={(e) => setNewKeyEnvironment(e.target.value as any)}
              className="w-full border rounded p-2"
            >
              <option value="live">Live (Production)</option>
              <option value="test">Test (Staging)</option>
              <option value="dev">Dev (Development)</option>
            </select>
          </div>

          <Button
            onClick={generateKey}
            disabled={loading || !newKeyLabel || newKeyLabel.length < 3}
          >
            {loading ? 'Generating...' : 'Generate API Key'}
          </Button>
        </div>
      </Card>

      {/* Existing Keys */}
      <div className="space-y-3">
        <h3 className="font-semibold">Existing API Keys ({keys.length}/10)</h3>
        
        {keys.length === 0 ? (
          <Card className="p-4 text-center text-gray-500">
            No API keys yet. Generate one above to get started.
          </Card>
        ) : (
          keys.map((key) => (
            <Card key={key.id} className="p-4">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h4 className="font-semibold">{key.label}</h4>
                    <span className={`text-xs px-2 py-1 rounded ${
                      key.environment === 'live' 
                        ? 'bg-green-100 text-green-800'
                        : key.environment === 'test'
                        ? 'bg-blue-100 text-blue-800'
                        : 'bg-gray-100 text-gray-800'
                    }`}>
                      {key.environment}
                    </span>
                    {!key.active && (
                      <span className="text-xs px-2 py-1 rounded bg-red-100 text-red-800">
                        Revoked
                      </span>
                    )}
                  </div>

                  <div className="text-sm text-gray-600 mt-1 space-y-1">
                    <div className="font-mono">
                      hck_{key.environment}_••••{key.lastFourChars}
                    </div>
                    <div>
                      Created: {new Date(key.createdAt).toLocaleDateString()}
                    </div>
                    <div>
                      Expires: {new Date(key.expiresAt).toLocaleDateString()}
                    </div>
                    {key.lastUsedAt && (
                      <div>
                        Last used: {new Date(key.lastUsedAt).toLocaleDateString()} 
                        ({key.usageCount} total requests)
                      </div>
                    )}
                  </div>
                </div>

                {key.active && (
                  <Button
                    size="sm"
                    variant="destructive"
                    onClick={() => revokeKey(key.id, key.label)}
                  >
                    Revoke
                  </Button>
                )}
              </div>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
```

---

## Phase 6: Audit & Monitoring

### Step 6.1: Audit Log Viewer

```typescript
// pages/api/api-keys/audit-logs.ts
import { withAuth, AuthenticatedRequest } from '@/lib/middleware/authenticate';
import { prisma } from '@/lib/db';
import { NextApiResponse } from 'next';

export default withAuth(async (req: AuthenticatedRequest, res: NextApiResponse) => {
  const { organizationId } = req.user;
  const { action, success, limit = 100, offset = 0 } = req.query;

  const logs = await prisma.apiKeyAuditLog.findMany({
    where: {
      organizationId,
      ...(action && { action: action as string }),
      ...(success !== undefined && { success: success === 'true' }),
    },
    orderBy: { createdAt: 'desc' },
    take: parseInt(limit as string),
    skip: parseInt(offset as string),
    include: {
      apiKey: {
        select: {
          label: true,
          lastFourChars: true,
        },
      },
      user: {
        select: {
          email: true,
        },
      },
    },
  });

  const total = await prisma.apiKeyAuditLog.count({
    where: {
      organizationId,
      ...(action && { action: action as string }),
      ...(success !== undefined && { success: success === 'true' }),
    },
  });

  return res.status(200).json({
    logs,
    pagination: {
      total,
      limit: parseInt(limit as string),
      offset: parseInt(offset as string),
    },
  });
});
```

### Step 6.2: Monitoring Dashboards

```typescript
// components/ApiKeyMonitoring.tsx
'use client';

import { useState, useEffect } from 'react';
import { Card } from '@/components/ui/card';

interface AuditLog {
  id: string;
  action: string;
  success: boolean;
  errorCode?: string;
  errorMessage?: string;
  createdAt: string;
  apiKey?: {
    label: string;
    lastFourChars: string;
  };
  user?: {
    email: string;
  };
}

export function ApiKeyMonitoring() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [filter, setFilter] = useState<'all' | 'success' | 'failed'>('all');

  useEffect(() => {
    fetchLogs();
  }, [filter]);

  const fetchLogs = async () => {
    const params = new URLSearchParams();
    if (filter === 'success') params.set('success', 'true');
    if (filter === 'failed') params.set('success', 'false');
    params.set('limit', '50');

    const res = await fetch(`/api/api-keys/audit-logs?${params.toString()}`);
    const data = await res.json();
    setLogs(data.logs);
  };

  const getActionColor = (action: string) => {
    const colors: Record<string, string> = {
      created: 'bg-green-100 text-green-800',
      validated: 'bg-blue-100 text-blue-800',
      revoked: 'bg-red-100 text-red-800',
      failed_validation: 'bg-yellow-100 text-yellow-800',
    };
    return colors[action] || 'bg-gray-100 text-gray-800';
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">API Key Activity Log</h3>
        
        <div className="flex gap-2">
          <button
            onClick={() => setFilter('all')}
            className={`px-3 py-1 rounded text-sm ${
              filter === 'all' ? 'bg-blue-500 text-white' : 'bg-gray-200'
            }`}
          >
            All
          </button>
          <button
            onClick={() => setFilter('success')}
            className={`px-3 py-1 rounded text-sm ${
              filter === 'success' ? 'bg-green-500 text-white' : 'bg-gray-200'
            }`}
          >
            Success
          </button>
          <button
            onClick={() => setFilter('failed')}
            className={`px-3 py-1 rounded text-sm ${
              filter === 'failed' ? 'bg-red-500 text-white' : 'bg-gray-200'
            }`}
          >
            Failed
          </button>
        </div>
      </div>

      <div className="space-y-2">
        {logs.map((log) => (
          <Card key={log.id} className="p-3">
            <div className="flex justify-between items-start">
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className={`text-xs px-2 py-1 rounded ${getActionColor(log.action)}`}>
                    {log.action}
                  </span>
                  {!log.success && (
                    <span className="text-xs text-red-600">
                      ❌ {log.errorCode}
                    </span>
                  )}
                </div>

                <div className="text-sm mt-1">
                  {log.apiKey && (
                    <span className="font-mono">
                      {log.apiKey.label} (•••• {log.apiKey.lastFourChars})
                    </span>
                  )}
                  {log.user && (
                    <span className="text-gray-600 ml-2">
                      by {log.user.email}
                    </span>
                  )}
                </div>

                {log.errorMessage && (
                  <div className="text-xs text-red-600 mt-1">
                    {log.errorMessage}
                  </div>
                )}
              </div>

              <div className="text-xs text-gray-500">
                {new Date(log.createdAt).toLocaleString()}
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
```

---

## Phase 7: Key Rotation

### Step 7.1: Automated Expiration Warnings

```typescript
// scripts/check-expiring-keys.ts
import { prisma } from '../lib/db';
import { sendEmail } from '../lib/email';

/**
 * Check for expiring API keys and send warnings
 * Run this daily via cron job
 */
async function checkExpiringKeys() {
  const fourteenDaysFromNow = new Date();
  fourteenDaysFromNow.setDate(fourteenDaysFromNow.getDate() + 14);

  const expiringKeys = await prisma.apiKey.findMany({
    where: {
      active: true,
      expiresAt: {
        lte: fourteenDaysFromNow,
      },
      expiryWarningSent: false,
    },
    include: {
      organization: true,
      creator: true,
    },
  });

  for (const key of expiringKeys) {
    const daysUntilExpiry = Math.ceil(
      (key.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24)
    );

    // Send email warning
    await sendEmail({
      to: key.creator.email,
      subject: `API Key "${key.label}" Expiring in ${daysUntilExpiry} Days`,
      html: `
        <h2>API Key Expiration Warning</h2>
        <p>Your API key is expiring soon:</p>
        <ul>
          <li><strong>Label:</strong> ${key.label}</li>
          <li><strong>Environment:</strong> ${key.environment}</li>
          <li><strong>Expires:</strong> ${key.expiresAt.toLocaleDateString()}</li>
          <li><strong>Days Remaining:</strong> ${daysUntilExpiry}</li>
        </ul>
        <p>Please rotate your API key before expiration to avoid service disruption.</p>
        <a href="https://yourapp.com/settings/api-keys">Manage API Keys</a>
      `,
    });

    // Mark warning as sent
    await prisma.apiKey.update({
      where: { id: key.id },
      data: { expiryWarningSent: true },
    });

    console.log(`✅ Warning sent for key: ${key.label} (expires in ${daysUntilExpiry} days)`);
  }

  console.log(`✅ Checked ${expiringKeys.length} expiring keys`);
}

checkExpiringKeys().catch(console.error);
```

### Step 7.2: Key Rotation Guide for Users

```markdown
# API Key Rotation Guide

## Why Rotate API Keys?

- **Security Best Practice:** Limits damage if key is compromised
- **Compliance:** Many security standards require regular rotation
- **Access Control:** Remove keys that are no longer needed

## Rotation Schedule

- **Production Keys:** Every 30-90 days
- **Test Keys:** Every 90-180 days
- **Compromised Keys:** Immediately

## Zero-Downtime Rotation Process

### Step 1: Generate New Key

1. Go to Settings → API Keys
2. Click "Generate New API Key"
3. Label: "Production Server V2"
4. Environment: "live"
5. **Copy and save the key immediately!**

### Step 2: Update Your Systems (Parallel)

1. Add new key to your system (alongside old key)
2. Deploy updated configuration
3. Verify both keys work

### Step 3: Monitor

1. Watch for any errors
2. Check audit logs for old key usage
3. Wait 24-48 hours to ensure stability

### Step 4: Revoke Old Key

1. Once new key is stable, revoke old key
2. Remove old key from your systems
3. Update documentation

### Step 5: Confirm

1. Check that services still work
2. Verify only new key appears in audit logs
```

---

## Testing API Keys

### Step 8.1: Unit Tests

```typescript
// __tests__/api-key-generation.test.ts
/**
 * SCHEMA VALIDATION:
 * - Checked: ./.cursor/tools/inspect-model.sh ApiKey
 * - Fields: keyHash, label, lastFourChars, environment, organizationId
 * - Generated Prisma types imported
 */

import { ApiKeyGenerator } from '@/lib/api-keys/generator';
import { prisma } from '@/lib/db';
import bcrypt from 'bcrypt';

// Mock Prisma
jest.mock('@/lib/db', () => ({
  prisma: {
    apiKey: {
      count: jest.fn(),
      create: jest.fn(),
    },
    apiKeyAuditLog: {
      create: jest.fn(),
    },
  },
}));

// Mock bcrypt
jest.mock('bcrypt');

describe('ApiKeyGenerator', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('generateApiKey()', () => {
    it('should generate key with correct format', async () => {
      const mockOrgId = crypto.randomUUID();
      const mockUserId = crypto.randomUUID();

      (prisma.apiKey.count as jest.Mock).mockResolvedValue(0);
      (bcrypt.hash as jest.Mock).mockResolvedValue('$2b$12$mockedhash');
      (prisma.apiKey.create as jest.Mock).mockResolvedValue({
        id: 'key-123',
        keyHash: '$2b$12$mockedhash',
        label: 'Test Key',
        lastFourChars: 'ab12',
        environment: 'test',
        expiresAt: new Date('2025-03-01'),
        createdAt: new Date(),
      });
      (prisma.apiKeyAuditLog.create as jest.Mock).mockResolvedValue({});

      const result = await ApiKeyGenerator.generateApiKey({
        organizationId: mockOrgId,
        userId: mockUserId,
        label: 'Test Key',
        environment: 'test',
      });

      // Verify key format
      expect(result.apiKey).toMatch(/^hck_test_[a-f0-9]{64}$/);
      expect(result.label).toBe('Test Key');
      expect(result.environment).toBe('test');

      // Verify bcrypt was called with 12 rounds
      expect(bcrypt.hash).toHaveBeenCalledWith(
        expect.stringMatching(/^hck_test_/),
        12
      );

      // Verify database create was called
      expect(prisma.apiKey.create).toHaveBeenCalledTimes(1);
      expect(prisma.apiKeyAuditLog.create).toHaveBeenCalledTimes(1);
    });

    it('should reject when max keys reached', async () => {
      (prisma.apiKey.count as jest.Mock).mockResolvedValue(10);

      await expect(
        ApiKeyGenerator.generateApiKey({
          organizationId: crypto.randomUUID(),
          userId: crypto.randomUUID(),
          label: 'Test',
          environment: 'live',
        })
      ).rejects.toThrow('Maximum API keys (10) reached');
    });
  });

  describe('validateKeyFormat()', () => {
    it('should validate correct format', () => {
      const validKey = 'hck_live_' + 'a'.repeat(64);
      const result = ApiKeyGenerator.validateKeyFormat(validKey);
      expect(result.valid).toBe(true);
    });

    it('should reject invalid prefix', () => {
      const invalidKey = 'invalid_live_' + 'a'.repeat(64);
      const result = ApiKeyGenerator.validateKeyFormat(invalidKey);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid key prefix');
    });

    it('should reject invalid environment', () => {
      const invalidKey = 'hck_invalid_' + 'a'.repeat(64);
      const result = ApiKeyGenerator.validateKeyFormat(invalidKey);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid environment');
    });

    it('should reject invalid secret length', () => {
      const invalidKey = 'hck_live_abc123'; // Too short
      const result = ApiKeyGenerator.validateKeyFormat(invalidKey);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid secret format');
    });
  });
});
```

### Step 8.2: Integration Tests

```typescript
// __tests__/api-key-validation.integration.test.ts
import { ApiKeyGenerator } from '@/lib/api-keys/generator';
import { ApiKeyValidator } from '@/lib/api-keys/validator';
import { prisma } from '@/lib/db';

describe('API Key Validation (Integration)', () => {
  let testOrgId: string;
  let testUserId: string;
  let testApiKey: string;

  beforeAll(async () => {
    // Create test org and user
    testOrgId = crypto.randomUUID();
    testUserId = crypto.randomUUID();
  });

  afterAll(async () => {
    // Cleanup
    await prisma.apiKey.deleteMany({ where: { organizationId: testOrgId } });
    await prisma.apiKeyAuditLog.deleteMany({ where: { organizationId: testOrgId } });
  });

  test('should generate and validate key successfully', async () => {
    // Generate key
    const generated = await ApiKeyGenerator.generateApiKey({
      organizationId: testOrgId,
      userId: testUserId,
      label: 'Integration Test Key',
      environment: 'test',
    });

    testApiKey = generated.apiKey;

    // Validate key
    const validation = await ApiKeyValidator.validateApiKey(testApiKey);

    expect(validation.valid).toBe(true);
    expect(validation.organizationId).toBe(testOrgId);
    expect(validation.environment).toBe('test');
  });

  test('should reject invalid key', async () => {
    const invalidKey = 'hck_test_' + 'invalid'.repeat(16);
    const validation = await ApiKeyValidator.validateApiKey(invalidKey);

    expect(validation.valid).toBe(false);
    expect(validation.errorCode).toBe('INVALID_KEY');
  });

  test('should reject wrong environment', async () => {
    // Try to use test key in live environment
    const liveKey = testApiKey.replace('_test_', '_live_');
    const validation = await ApiKeyValidator.validateApiKey(liveKey);

    expect(validation.valid).toBe(false);
  });

  test('should track usage statistics', async () => {
    // Validate key multiple times
    await ApiKeyValidator.validateApiKey(testApiKey);
    await ApiKeyValidator.validateApiKey(testApiKey);
    await ApiKeyValidator.validateApiKey(testApiKey);

    // Check usage count
    const key = await prisma.apiKey.findFirst({
      where: {
        organizationId: testOrgId,
        environment: 'test',
      },
    });

    expect(key?.usageCount).toBeGreaterThanOrEqual(3);
    expect(key?.lastUsedAt).toBeTruthy();
  });
});
```

---

## Production Deployment

### Step 9.1: Pre-Deployment Checklist

```markdown
## API Key System Deployment Checklist

### Database
- [ ] Migrations applied to production database
- [ ] Indexes created for performance
- [ ] Constraints validated
- [ ] Backup verified

### Environment Variables
- [ ] IP_HASH_SALT configured (unique, secure)
- [ ] UPSTASH_REDIS_URL configured (for rate limiting)
- [ ] UPSTASH_REDIS_TOKEN configured
- [ ] Email service configured (for expiration warnings)

### Security
- [ ] Bcrypt rounds = 12 (minimum)
- [ ] API key format validated
- [ ] Rate limiting configured
- [ ] Audit logging enabled
- [ ] IP hashing tested (GDPR-compliant)

### Testing
- [ ] Unit tests passing (80%+ coverage)
- [ ] Integration tests passing
- [ ] End-to-end tests passing
- [ ] Load testing completed

### Monitoring
- [ ] Error tracking configured (Sentry, etc.)
- [ ] Audit log dashboard created
- [ ] Failed auth alerts set up
- [ ] Key expiration warnings automated

### Documentation
- [ ] API documentation updated
- [ ] User rotation guide created
- [ ] Support team trained
- [ ] Runbook for key compromise created
```

### Step 9.2: Monitoring & Alerts

```typescript
// scripts/monitor-api-keys.ts
import { prisma } from '../lib/db';

/**
 * Monitor API key health and security
 * Run this hourly via cron job
 */
async function monitorApiKeys() {
  const now = new Date();
  const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

  // Check failed validations
  const failedValidations = await prisma.apiKeyAuditLog.count({
    where: {
      action: 'validated',
      success: false,
      createdAt: {
        gte: oneHourAgo,
      },
    },
  });

  if (failedValidations > 100) {
    console.error(`🚨 HIGH ALERT: ${failedValidations} failed validations in last hour!`);
    // Send alert to on-call team
  }

  // Check for keys expiring in < 7 days
  const sevenDaysFromNow = new Date();
  sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);

  const soonToExpire = await prisma.apiKey.count({
    where: {
      active: true,
      expiresAt: {
        lte: sevenDaysFromNow,
      },
    },
  });

  if (soonToExpire > 0) {
    console.warn(`⚠️  ${soonToExpire} API keys expiring within 7 days`);
  }

  // Check for very old keys (> 1 year)
  const oneYearAgo = new Date();
  oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);

  const veryOldKeys = await prisma.apiKey.count({
    where: {
      active: true,
      createdAt: {
        lte: oneYearAgo,
      },
    },
  });

  if (veryOldKeys > 0) {
    console.warn(`⚠️  ${veryOldKeys} API keys are over 1 year old (should rotate)`);
  }

  console.log('✅ API key monitoring complete');
}

monitorApiKeys().catch(console.error);
```

---

## Common Pitfalls

### ❌ Pitfall 1: Storing Raw API Keys

**Problem:**
```typescript
// ❌ NEVER DO THIS!
await prisma.apiKey.create({
  data: {
    apiKey: generatedKey, // Raw key stored!
  },
});
```

**Solution:**
```typescript
// ✅ ALWAYS hash keys
const keyHash = await bcrypt.hash(generatedKey, 12);
await prisma.apiKey.create({
  data: {
    keyHash, // Only hash stored
  },
});
```

### ❌ Pitfall 2: Weak Key Generation

**Problem:**
```typescript
// ❌ Predictable, not cryptographically secure
const apiKey = `key_${Date.now()}_${Math.random()}`;
```

**Solution:**
```typescript
// ✅ Cryptographically secure
const secret = crypto.randomBytes(32).toString('hex');
const apiKey = `hck_live_${secret}`;
```

### ❌ Pitfall 3: No Environment Isolation

**Problem:**
```typescript
// ❌ Test keys can be used in production!
const isValid = await bcrypt.compare(providedKey, storedHash);
```

**Solution:**
```typescript
// ✅ Validate environment prefix
const environment = providedKey.split('_')[1];
if (key.environment !== environment) {
  return { valid: false, error: 'Wrong environment' };
}
const isValid = await bcrypt.compare(providedKey, storedHash);
```

### ❌ Pitfall 4: Logging Raw Keys

**Problem:**
```typescript
// ❌ API key exposed in logs!
console.log('Generated key:', apiKey);
logger.info({ apiKey }, 'Key created');
```

**Solution:**
```typescript
// ✅ Log only safe metadata
console.log('Generated key ID:', keyId);
logger.info({ keyId, lastFourChars }, 'Key created');
```

### ❌ Pitfall 5: No Rate Limiting

**Problem:**
```typescript
// ❌ Attacker can brute force keys
if (isValid) {
  return { valid: true };
}
```

**Solution:**
```typescript
// ✅ Rate limit validation attempts
if (!await checkRateLimit(req, res, getClientIP(req))) {
  return; // 429 Too Many Requests
}
if (isValid) {
  return { valid: true };
}
```

---

## Appendix

### A. Environment Variables

```bash
# .env.example

# API Key Hashing
IP_HASH_SALT=your_random_salt_change_in_production_min_32_chars

# Rate Limiting (Upstash Redis)
UPSTASH_REDIS_URL=https://your-redis.upstash.io
UPSTASH_REDIS_TOKEN=your_redis_token_here

# Email (for expiration warnings)
EMAIL_FROM=noreply@yourapp.com
SENDGRID_API_KEY=your_sendgrid_key # or your email provider

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/myapp
```

### B. Time Estimates

| Phase | Task | Estimated Time |
|-------|------|----------------|
| Phase 1 | Database Schema Design | 2-3 hours |
| Phase 2 | Key Generation | 3-4 hours |
| Phase 3 | Key Validation | 3-4 hours |
| Phase 4 | Authentication Middleware | 4-6 hours |
| Phase 5 | Key Management UI | 6-8 hours |
| Phase 6 | Audit & Monitoring | 4-6 hours |
| Phase 7 | Key Rotation | 3-4 hours |
| Phase 8 | Testing | 8-12 hours |
| Phase 9 | Deployment | 2-3 hours |
| **Total** | | **35-50 hours** |

### C. Security Standards

**Compliance:**
- **GDPR:** IP address hashing, right to erasure
- **SOC 2:** Audit logging, access controls
- **PCI DSS:** Key rotation, secure storage
- **ISO 27001:** Encryption at rest, secure transmission

**Best Practices:**
- **OWASP:** Cryptographic storage, authentication
- **NIST:** Key management lifecycle
- **CIS:** Secure configuration, monitoring

---

**Related Rules:**
- @373-api-key-system-design.mdc - Design patterns and architecture
- @372-api-key-testing-standards.mdc - Testing requirements
- @224-secrets-management.mdc - Secrets lifecycle management
- @012-api-security.mdc - API security best practices
- @011-env-var-security.mdc - Environment variable security

**Related Guides:**
- `guides/api-key-management/Complete-API-Key-System-Documentation.md` - Reference documentation
- `guides/Secrets-Management-Complete-Guide.md` - Secrets management
- `guides/Multi-Tenant-Architecture-Complete-Guide.md` - Multi-tenancy patterns

**Reference Implementation:**
- GiDanc Health Check SDK - Production API key system
- VibeCoder API Keys - Enterprise-grade implementation

---

**Last Updated:** November 25, 2025  
**Status:** ✅ Production-Ready  
**Based On:** Real-world implementations with 1000+ API keys in production

