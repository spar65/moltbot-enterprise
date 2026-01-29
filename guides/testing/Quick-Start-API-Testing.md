# API Testing - Quick Start Guide

## 🚀 5-Minute Setup

### 1. Run API Tests

```bash
npx jest __tests__/api-*.test.ts --config=jest.api.config.js --verbose
```

### 2. Copy This Template for New API Tests

```typescript
/**
 * API Test Template
 */
import yourHandler from "../pages/api/your/endpoint";
import {
  createAPITest,
  mockAuth,
  dbTestUtils,
  responseAssertions,
} from "../tests/helpers/api-test-helpers";

describe("API: Your Endpoint", () => {
  let mockSql: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mockSql = dbTestUtils.setupMocks();
  });

  test("✅ POST /api/your/endpoint - Success scenario", async () => {
    console.log("🧪 Testing your API endpoint");

    // Set up authentication
    mockAuth.session({ sub: "user-123", email: "test@example.com" });

    // Set up database mocks
    mockSql
      .mockResolvedValueOnce([{ count: 0 }]) // Mock response 1
      .mockResolvedValueOnce([{ id: "result-123", created_at: new Date() }]) // Mock response 2
      .mockResolvedValueOnce([]); // Mock response 3

    // Create API request
    const { req, res } = createAPITest({
      method: "POST",
      body: { key: "value" },
    });

    // Execute API handler
    await yourHandler(req, res);

    // Assert response
    const data = responseAssertions.success(res, 201);
    expect(data.id).toBe("result-123");

    console.log("✅ API endpoint test passed");
  });

  test("❌ POST /api/your/endpoint - Unauthorized", async () => {
    mockAuth.failed();

    const { req, res } = createAPITest({
      method: "POST",
      body: { key: "value" },
    });

    await yourHandler(req, res);

    responseAssertions.error(res, 401, "Unauthorized");
  });
});
```

### 3. Name Your Test File

- **Pattern**: `__tests__/api-your-feature.test.ts`
- **Auto-detected** by `jest.api.config.js`

---

## 🧪 Common API Test Patterns

### Session Authentication (Web Users)

```typescript
test("Web user access", async () => {
  mockAuth.session({ sub: "web-user-123", email: "user@example.com" });

  const { req, res } = createAPITest({ method: "GET" });
  await handler(req, res);

  responseAssertions.success(res, 200);
});
```

### API Key Authentication (CLI Users)

```typescript
test("CLI user access", async () => {
  mockAuth.apiKey({ userId: "cli-user-123", environment: "test" });

  const { req, res } = createAPITest({
    method: "POST",
    headers: { "x-api-key": "vibe_test_" + "a".repeat(64) },
  });

  await handler(req, res);
  responseAssertions.success(res, 200);
});
```

### Rate Limiting Tests

```typescript
test("Rate limit exceeded", async () => {
  mockAuth.apiKey();
  middlewareUtils.rateLimitExceeded();

  const { req, res } = createAPITest({ method: "GET" });
  await handler(req, res);

  responseAssertions.error(res, 429, "Rate limit exceeded");
});
```

### Database Operations

```typescript
test("Database interaction", async () => {
  mockAuth.session();

  // Set up database responses
  mockSql
    .mockResolvedValueOnce([{ count: 0 }])
    .mockResolvedValueOnce([{ id: "new-id", created_at: new Date() }]);

  const { req, res } = createAPITest({
    method: "POST",
    body: { name: "Test Item" },
  });

  await handler(req, res);

  const data = responseAssertions.success(res, 201);
  expect(data.id).toBe("new-id");
});
```

---

## 🔧 Quick Helpers

### Authentication Setup

```typescript
// Session auth
mockAuth.session({ sub: "user-123", email: "test@example.com" });

// API key auth
mockAuth.apiKey({ userId: "cli-user-123", environment: "test" });

// No auth (should fail)
mockAuth.failed();
```

### Request Creation

```typescript
// GET request
const { req, res } = createAPITest({ method: "GET" });

// POST with body
const { req, res } = createAPITest({
  method: "POST",
  body: { key: "value" },
});

// With headers
const { req, res } = createAPITest({
  method: "POST",
  headers: { "x-api-key": "your-key" },
  body: { data: "value" },
});
```

### Response Assertions

```typescript
// Success responses
const data = responseAssertions.success(res, 200);
const data = responseAssertions.success(res, 201);

// Error responses
responseAssertions.error(res, 400, "Bad Request");
responseAssertions.error(res, 401, "Unauthorized");
responseAssertions.error(res, 429, "Rate limit exceeded");

// Validation errors
responseAssertions.validation(res, "email");
```

---

## 🐛 Quick Debug Tips

### 1. Add Console Logging

```typescript
console.log("🧪 Testing feature");
console.log("📊 Response status:", res._getStatusCode());
console.log("📋 Response data:", JSON.parse(res._getData()));
```

### 2. Check Authentication

```typescript
const { getSession } = require("@auth0/nextjs-auth0");
console.log("Auth mock called:", getSession.mock.calls.length);
```

### 3. Check Database Calls

```typescript
console.log("Database calls:", mockSql.mock.calls.length);
console.log("Database call details:", mockSql.mock.calls);
```

---

## ✅ Success Checklist

- [ ] Test file named `__tests__/api-*.test.ts`
- [ ] Uses `jest.api.config.js`
- [ ] Authentication properly mocked
- [ ] Database responses mocked
- [ ] Both success and error scenarios tested
- [ ] Console logging for debugging

---

## 🆘 Quick Fixes

### Cannot find module '@/middleware/...'

```javascript
// Add to jest.api.setup.js
jest.mock("@/middleware/your-middleware", () => ({
  yourFunction: jest.fn(),
}));
```

### Auth0 getSession not working

```javascript
// Ensure Auth0 is mocked in jest.api.setup.js
jest.mock("@auth0/nextjs-auth0", () => ({
  getSession: jest.fn(),
  withApiAuthRequired: jest.fn((handler) => handler),
}));
```

### Test hanging

```javascript
// In jest.api.config.js
testTimeout: 45000; // Increase timeout
```

---

## 🔄 Test Types Quick Guide

| Test What          | Use               | File Pattern            |
| ------------------ | ----------------- | ----------------------- |
| **Business Logic** | Unit Tests        | `database-*.test.ts`    |
| **API Endpoints**  | API Tests         | `api-*.test.ts`         |
| **Full Workflows** | Integration Tests | `integration-*.test.ts` |

---

**Need more details?** Check [API-Testing-Database-Guide.md](./API-Testing-Database-Guide.md) for comprehensive documentation.
