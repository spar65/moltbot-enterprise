# Database Testing - Quick Start Guide

## 🚀 5-Minute Setup

### 1. Run Database Tests

```bash
npx jest __tests__/database-focused.test.ts --config=jest.database.config.js --verbose
```

### 2. Copy This Template for New Tests

```typescript
/**
 * Your New Database Test
 */
import { ApiKeyManager } from "../src/lib/api-keys";

// Import the mocked SQL function (proven pattern)
const { sql: mockSql } = require("../src/lib/database");

describe("Your Feature Tests", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Set up bcrypt mocks (proven pattern)
    const bcrypt = require("bcryptjs");
    bcrypt.hash.mockResolvedValue("$2b$12$hashedkey");
    bcrypt.compare.mockResolvedValue(true);
  });

  test("✅ Your test description", async () => {
    console.log("🧪 Testing your feature");

    // Explicit mock setup (proven pattern)
    (mockSql as jest.Mock)
      .mockResolvedValueOnce([{ count: 0 }]) // Mock response 1
      .mockResolvedValueOnce([{ id: "test-123", created_at: new Date() }]) // Mock response 2
      .mockResolvedValueOnce([]); // Mock response 3

    const result = await YourManager.yourMethod("param1", { option: "value" });

    console.log("📊 Result:", result);

    expect(result.id).toBe("test-123");
    expect(result.success).toBe(true);

    console.log("✅ Test completed successfully");
  });
});
```

### 3. Name Your Test File

- **Pattern**: `__tests__/database-your-feature.test.ts`
- **Auto-detected** by `jest.database.config.js`

---

## 🧪 Common Test Patterns

### API Key Generation

```typescript
(mockSql as jest.Mock)
  .mockResolvedValueOnce([{ count: 0 }]) // Count check
  .mockResolvedValueOnce([{ id: "key-123", created_at: new Date() }]) // Insert
  .mockResolvedValueOnce([]); // Audit log

const result = await ApiKeyManager.generateApiKey(userId, options);
```

### API Key Validation

```typescript
(mockSql as jest.Mock).mockResolvedValueOnce([
  {
    id: "key-123",
    user_id: "user-123",
    key_hash: "$2b$12$hashedkey",
    environment: "test",
    is_active: true,
    expires_at: null,
  },
]);

const result = await ApiKeyManager.validateApiKey(
  "vibe_test_" + "a".repeat(64)
);
```

### User Data Retrieval

```typescript
(mockSql as jest.Mock).mockResolvedValueOnce([
  {
    id: "key-1",
    key_name: "Test Key",
    usage_count: 42,
    created_at: new Date(),
  },
]);

const result = await ApiKeyManager.getApiKeyInfo(userId);
```

---

## 🔧 Debug Tips

### 1. Add Console Logging

```typescript
console.log("🧪 Testing feature X");
console.log("📊 Result:", result);
console.log("✅ Test passed");
```

### 2. Check Mock Call Count

```typescript
expect(mockSql).toHaveBeenCalledTimes(3);
```

### 3. Inspect Mock Calls

```typescript
console.log("Mock calls:", mockSql.mock.calls);
```

---

## ✅ Success Checklist

- [ ] Test file named `__tests__/database-*.test.ts`
- [ ] Uses `jest.database.config.js`
- [ ] Calls `jest.clearAllMocks()` in `beforeEach`
- [ ] Uses explicit mock setup pattern
- [ ] Includes console logging for debugging
- [ ] Expects specific values, not just truthy

---

## 🆘 Quick Fixes

### Test Hanging?

```javascript
// In jest.database.config.js
testTimeout: 30000; // Increase timeout
```

### Mock Not Working?

```typescript
// Clear and reset
jest.clearAllMocks();
(mockSql as jest.Mock).mockReset();
```

### TypeScript Errors?

```typescript
// Cast the mock
const { sql: mockSql } = require('../src/lib/database');
(mockSql as jest.Mock).mockResolvedValueOnce([...]);
```

---

**Need help?** Check [Database-Testing-Infrastructure-Guide.md](./Database-Testing-Infrastructure-Guide.md) for complete documentation.
