# API Key Generation & Management - Complete Testing Guide

**Created**: August 2, 2025  
**Status**: ✅ **Production Ready**  
**Infrastructure**: Database Testing (Neon + Jest)

---

## 🎯 **Overview**

This guide covers comprehensive testing patterns for VibeCoder's API key management system, built on our bulletproof database testing infrastructure. API keys enable CLI authentication and programmatic access with enterprise-grade security.

---

## 📦 **API Key System Architecture**

### **🔧 Core Components**

1. **`ApiKeyManager` Class** (`src/lib/api-keys.ts`)

   - ✅ Secure key generation (vibe*{env}*{64_hex})
   - ✅ bcrypt hash validation
   - ✅ CRUD operations with audit trails
   - ✅ Rate limiting and expiry management

2. **Database Tables** (`migrations/007_user_api_keys.sql`)

   - ✅ `user_api_keys` - Secure key storage
   - ✅ `api_key_audit_log` - GDPR-compliant audit trail

3. **Authentication Middleware** (`src/middleware/api-auth.ts`)

   - ✅ Dual auth (Auth0 sessions + API keys)
   - ✅ Environment validation
   - ✅ Rate limiting enforcement

4. **API Endpoints** (`pages/api/user/api-keys.ts`)
   - ✅ Self-service key management
   - ✅ Validation and error handling

---

## 🧪 **Testing Patterns**

### **✅ Foundation Pattern (Copy This)**

```typescript
// __tests__/api-key-{feature}.test.ts
import { ApiKeyManager } from '../src/lib/api-keys';

const { sql: mockSql } = require('../src/lib/database');

describe('API Key {Feature} Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Standard bcrypt mocks
    const bcrypt = require('bcryptjs');
    bcrypt.hash.mockResolvedValue('$2b$12$hashedkey');
    bcrypt.compare.mockResolvedValue(true);
  });

  test('✅ Should {specific behavior}', async () => {
    // Explicit mock setup
    (mockSql as jest.Mock)
      .mockResolvedValueOnce([{ /* first db call */ }])
      .mockResolvedValueOnce([{ /* second db call */ }]);

    // Execute test
    const result = await ApiKeyManager.{method}(params);

    // Verify behavior
    expect(result).toBeDefined();
    expect(mockSql).toHaveBeenCalledTimes(2);
  });
});
```

---

## 🔧 **Testing Each API Key Feature**

### **1. ✅ Key Generation (COVERED)**

**Current Tests**: `database-focused.test.ts`, `database-integration-implementation-based.test.ts`

```typescript
test("✅ API Key Generation Works", async () => {
  const userId = "user-123";

  (mockSql as jest.Mock)
    .mockResolvedValueOnce([{ count: 0 }]) // Count check
    .mockResolvedValueOnce([{ id: "key-123", created_at: new Date() }]) // Insert
    .mockResolvedValueOnce([]); // Audit log

  const result = await ApiKeyManager.generateApiKey(userId, {
    keyName: "Test Key",
    environment: "test",
  });

  expect(result.keyId).toBe("key-123");
  expect(result.apiKey).toMatch(/^vibe_test_/);
  expect(result.environment).toBe("test");
});
```

### **2. ❌ Key Rotation (MISSING - HIGH PRIORITY)**

**Method**: `ApiKeyManager.rotateApiKey(userId, keyId)`  
**Should Test**:

- ✅ Generates new key with updated name
- ✅ Marks old key as rotated
- ✅ Maintains grace period
- ✅ Logs rotation audit event
- ❌ Handles rotation failures

```typescript
test("🔄 Key Rotation Should Work", async () => {
  const userId = "user-123";
  const oldKeyId = "old-key-123";

  // Mock existing key lookup
  (mockSql as jest.Mock)
    .mockResolvedValueOnce([
      {
        environment: "live",
        key_name: "Production Key",
      },
    ]) // Get existing key
    .mockResolvedValueOnce([{ count: 1 }]) // Count check for new key
    .mockResolvedValueOnce([
      {
        id: "new-key-456",
        created_at: new Date(),
      },
    ]) // Insert new key
    .mockResolvedValueOnce([]) // Audit log for new key
    .mockResolvedValueOnce([{ id: oldKeyId }]) // Update old key
    .mockResolvedValueOnce([]); // Audit log for rotation

  const result = await ApiKeyManager.rotateApiKey(userId, oldKeyId);

  expect(result.keyId).toBe("new-key-456");
  expect(result.apiKey).toMatch(/^vibe_live_/);
  expect(mockSql).toHaveBeenCalledTimes(6);
});
```

### **3. ❌ Expiry Management (MISSING - HIGH PRIORITY)**

**Method**: `ApiKeyManager.checkKeyExpiry(userId)`  
**Should Test**:

- ✅ Detects keys expiring within 14 days
- ✅ Returns accurate days remaining
- ✅ Handles no expiring keys
- ❌ Handles database errors gracefully

```typescript
test("⏰ Key Expiry Detection Should Work", async () => {
  const userId = "user-123";

  // Mock key expiring in 7 days
  (mockSql as jest.Mock).mockResolvedValueOnce([
    {
      min_days_left: 7,
    },
  ]);

  const result = await ApiKeyManager.checkKeyExpiry(userId);

  expect(result.expiringSoon).toBe(true);
  expect(result.daysLeft).toBe(7);
});
```

### **4. ❌ Maximum Key Limit (MISSING - MEDIUM PRIORITY)**

**Business Rule**: Max 2 keys per user per environment  
**Should Test**:

- ✅ Enforces 2-key limit
- ✅ Returns clear error message
- ✅ Suggests revocation workflow
- ❌ Allows generation when under limit

```typescript
test("🚫 Should Enforce Maximum Key Limit", async () => {
  const userId = "user-123";

  // Mock already at max keys
  (mockSql as jest.Mock).mockResolvedValueOnce([{ count: 2 }]);

  await expect(
    ApiKeyManager.generateApiKey(userId, { environment: "live" })
  ).rejects.toThrow("Maximum API keys (2) already exist");
});
```

### **5. ❌ Security Validation (MISSING - HIGH PRIORITY)**

**Methods**: `validateEnvironmentPrefix`, `hashIpAddress`  
**Should Test**:

- ✅ Environment prefix validation
- ✅ GDPR-compliant IP hashing
- ✅ Key format validation
- ❌ Handles malformed keys

```typescript
test("🛡️ Environment Prefix Validation Should Work", async () => {
  const liveKey = "vibe_live_" + "a".repeat(64);
  const testKey = "vibe_test_" + "b".repeat(64);

  expect(ApiKeyManager.validateEnvironmentPrefix(liveKey, "live")).toBe(true);
  expect(ApiKeyManager.validateEnvironmentPrefix(liveKey, "test")).toBe(false);
  expect(ApiKeyManager.validateEnvironmentPrefix(testKey, "test")).toBe(true);
});

test("🛡️ IP Address Hashing Should Be GDPR Compliant", async () => {
  const ip = "192.168.1.100";
  const hashedIp = ApiKeyManager.hashIpAddress(ip);

  expect(hashedIp).toBeDefined();
  expect(hashedIp).not.toBe(ip); // Should be hashed
  expect(hashedIp.length).toBe(64); // SHA256 hex length
});
```

---

## 🌐 **API Endpoint Testing Patterns**

### **✅ Using Our API Testing Infrastructure**

```typescript
// __tests__/api-key-endpoints.test.ts
import {
  createAPITest,
  mockAuth,
  dbTestUtils,
} from "../tests/helpers/api-test-helpers";

describe("API Key Endpoints", () => {
  let mockSql: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mockSql = dbTestUtils.setupMocks();
    mockAuth.session({ sub: "user-123" });
  });

  test("✅ POST /api/user/api-keys - Should Generate Key", async () => {
    // Mock database responses
    mockSql
      .mockResolvedValueOnce([{ count: 0 }]) // Count check
      .mockResolvedValueOnce([{ id: "key-123", created_at: new Date() }]) // Insert
      .mockResolvedValueOnce([]); // Audit log

    const response = await createAPITest({
      method: "POST",
      url: "/api/user/api-keys",
      body: { keyName: "Test Key", environment: "test" },
    });

    expect(response.status).toBe(201);
    expect(response.data.keyId).toBe("key-123");
    expect(response.data.apiKey).toMatch(/^vibe_test_/);
  });

  test("❌ POST /api/user/api-keys - Should Reject Invalid Environment", async () => {
    const response = await createAPITest({
      method: "POST",
      url: "/api/user/api-keys",
      body: { keyName: "Test Key", environment: "invalid" },
    });

    expect(response.status).toBe(400);
    expect(response.data.code).toBe("INVALID_ENVIRONMENT");
  });
});
```

---

## 🛡️ **Security Testing Requirements**

### **✅ Essential Security Tests**

1. **Hash Verification**

   ```typescript
   test("🔐 bcrypt Hash Verification", async () => {
     const plainKey = "vibe_test_" + "a".repeat(64);
     const hashedKey = await bcrypt.hash(plainKey, 12);

     const isValid = await bcrypt.compare(plainKey, hashedKey);
     expect(isValid).toBe(true);
   });
   ```

2. **Environment Isolation**

   ```typescript
   test("🏢 Environment Isolation", async () => {
     const liveKey = "vibe_live_abc123";
     const testValidation = await ApiKeyManager.validateApiKey(liveKey);
     // Should not validate in test environment
   });
   ```

3. **Rate Limiting**
   ```typescript
   test("🚦 Rate Limit Enforcement", async () => {
     // Test rate limiting middleware
   });
   ```

---

## 📋 **Testing Checklist**

### **✅ Current (Working)**

- [x] Basic key generation
- [x] Key validation
- [x] Key revocation
- [x] Key info retrieval
- [x] Audit logging
- [x] Database integration
- [x] Mock isolation

### **❌ Missing (High Priority)**

- [ ] **Key rotation workflow**
- [ ] **Expiry detection and warnings**
- [ ] **Maximum key limit enforcement**
- [ ] **Security validation functions**
- [ ] **Error scenario coverage**
- [ ] **API endpoint integration tests**

### **❌ Missing (Medium Priority)**

- [ ] **Usage tracking updates**
- [ ] **GDPR compliance testing**
- [ ] **Rate limiting integration**
- [ ] **Cross-environment validation**

### **❌ Missing (Low Priority)**

- [ ] **Performance under load**
- [ ] **Concurrent operation handling**
- [ ] **Migration testing**

---

## 🚀 **Next Steps**

### **1. Immediate (This Session)**

Create missing high-priority tests using our bulletproof database testing infrastructure:

```bash
# Create new test files
__tests__/api-key-rotation.test.ts
__tests__/api-key-security.test.ts
__tests__/api-key-limits.test.ts
__tests__/api-key-endpoints.test.ts
```

### **2. Copy-Paste Templates**

Use `database-focused.test.ts` as the foundation pattern for all new API key tests.

### **3. Integration Strategy**

- ✅ **Database tests**: Use `jest.database.config.js`
- ✅ **API tests**: Use `jest.api.config.js`
- ✅ **Combined tests**: Test business logic + endpoints together

---

## 💡 **Best Practices**

### **✅ DO**

- Use explicit mock setup (no chaining)
- Test one responsibility per test
- Include both success and error cases
- Follow existing naming patterns
- Use our proven testing infrastructure

### **❌ DON'T**

- Create complex mock chains
- Test implementation details
- Mix multiple concerns in one test
- Skip error scenario testing
- Ignore audit trail verification

---

**Ready to implement the missing tests with our bulletproof database infrastructure!** 🎯
