# API Testing with Database Infrastructure - Complete Guide

## 🎯 Overview

This guide extends our **proven database testing infrastructure** to cover API endpoint testing, providing patterns for testing Next.js API routes with real database interactions while maintaining test isolation and reliability.

### ✅ What This Guide Covers

- **API endpoint testing** with database integration
- **Middleware dependency management** (auth, rate limiting, etc.)
- **Request/Response testing patterns** using `node-mocks-http`
- **Authentication mocking strategies** (Auth0, API keys)
- **Error handling and validation testing**

### 🚀 Built On Our Proven Foundation

- ✅ **Database infrastructure**: Uses our working Jest + Neon setup
- ✅ **Explicit mock patterns**: No complex chains, clear debugging
- ✅ **Transaction isolation**: Real DB with rollback capabilities
- ✅ **Reusable utilities**: Extends our TestHelpers patterns

---

## 🏗️ Architecture Overview

### API Testing Stack

```
├── jest.api.config.js              # API-specific Jest config
├── jest.api.setup.js               # API environment setup
├── __tests__/api-*.test.ts         # API endpoint tests
├── tests/helpers/api-test-helpers.ts # Reusable API utilities
├── tests/mocks/                     # Centralized mocks
│   ├── auth0.mock.js               # Auth0 session mocking
│   ├── middleware.mock.js          # Middleware mocking
│   └── external-services.mock.js   # Third-party services
└── pages/api/                      # API endpoints under test
```

### Testing Layers

| Layer               | Purpose       | Tools              | Database         |
| ------------------- | ------------- | ------------------ | ---------------- |
| **Unit**            | Core logic    | Proven DB patterns | Mock             |
| **API Integration** | Endpoint + DB | This guide         | Real/Transaction |
| **E2E**             | Full workflow | Cypress/Playwright | Real             |

---

## 🔧 Setup Instructions

### 1. API Jest Configuration

Create `jest.api.config.js`:

```javascript
const nextJest = require("next/jest");

const createJestConfig = nextJest({
  dir: "./",
});

const apiJestConfig = {
  setupFilesAfterEnv: ["<rootDir>/jest.api.setup.js"],
  testEnvironment: "node", // Node environment for API testing

  // Test file patterns - API tests only
  testMatch: [
    "**/__tests__/**/api-*.test.(ts|tsx|js|jsx)",
    "**/tests/api/**/*.test.(ts|tsx|js|jsx)",
  ],

  // Longer timeout for API operations
  testTimeout: 45000,

  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/src/$1",
    "^@/middleware/(.*)$": "<rootDir>/src/middleware/$1",
    "^@/lib/(.*)$": "<rootDir>/src/lib/$1",
    "^@/pages/(.*)$": "<rootDir>/pages/$1",
  },

  // Coverage for API endpoints
  collectCoverageFrom: [
    "pages/api/**/*.{ts,js}",
    "src/middleware/**/*.{ts,js}",
    "!pages/api/_*.{ts,js}", // Exclude Next.js internals
    "!**/*.d.ts",
  ],

  coverageDirectory: "coverage-api",
  verbose: true,
};

module.exports = createJestConfig(apiJestConfig);
```

### 2. API Test Environment Setup

Create `jest.api.setup.js`:

```javascript
// ========================================
// API TESTING ENVIRONMENT SETUP
// ========================================

// Extend database setup (proven foundation)
require("./jest.database.setup.js");

// Mock Next.js internals
jest.mock("next/config", () => () => ({
  publicRuntimeConfig: {},
  serverRuntimeConfig: {},
}));

// Mock middleware dependencies BEFORE they're imported
jest.mock("@/middleware/api-auth", () => ({
  validateApiKey: jest.fn(),
  extractAuthInfo: jest.fn(),
}));

jest.mock("@/middleware/database-rate-limit", () => ({
  checkRateLimit: jest.fn(),
  updateRateLimit: jest.fn(),
}));

// Mock Auth0 at module level (critical for API endpoints)
jest.mock("@auth0/nextjs-auth0", () => ({
  getSession: jest.fn(),
  withApiAuthRequired: jest.fn((handler) => handler),
  handleAuth: jest.fn(),
  handleLogin: jest.fn(),
  handleLogout: jest.fn(),
  handleCallback: jest.fn(),
  handleProfile: jest.fn(),
}));

// Mock external services
jest.mock("../src/lib/vibecoder-ai-orchestra-v2", () => ({
  analyzeProjectRequirements: jest.fn(),
  generateTasks: jest.fn(),
  VibeCoderAIOrchestra: jest.fn(),
}));

// Global test utilities
global.createAPITest =
  require("./tests/helpers/api-test-helpers").createAPITest;
global.mockAuth = require("./tests/helpers/api-test-helpers").mockAuth;

console.log("🚀 API test environment initialized");
console.log("✅ Middleware mocks configured");
console.log("✅ Auth0 mocks configured");
console.log("✅ External service mocks configured");
```

### 3. API Test Helpers

Create `tests/helpers/api-test-helpers.ts`:

```typescript
import { createMocks } from "node-mocks-http";
import type { NextApiRequest, NextApiResponse } from "next";

/**
 * API Test Utilities - Built on Proven Database Patterns
 */

export interface APITestConfig {
  method: "GET" | "POST" | "PUT" | "DELETE" | "PATCH";
  url?: string;
  headers?: Record<string, string>;
  body?: any;
  query?: Record<string, string>;
}

export interface MockUser {
  sub: string;
  email: string;
  name?: string;
}

/**
 * Create API test request/response mocks
 */
export function createAPITest(config: APITestConfig) {
  const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
    method: config.method,
    url: config.url,
    headers: {
      "content-type": "application/json",
      ...config.headers,
    },
    body: config.body,
    query: config.query,
  });

  return { req, res };
}

/**
 * Mock authentication (Auth0 + API keys)
 */
export const mockAuth = {
  /**
   * Set up Auth0 session mock
   */
  session: (
    user: MockUser = { sub: "test-user-123", email: "test@example.com" }
  ) => {
    const { getSession } = require("@auth0/nextjs-auth0");
    getSession.mockResolvedValue({ user });
    return user;
  },

  /**
   * Set up API key authentication mock
   */
  apiKey: (keyData: any = {}) => {
    const { validateApiKey } = require("@/middleware/api-auth");
    const defaultKeyData = {
      userId: "api-user-123",
      keyId: "api-key-123",
      environment: "test",
      isValid: true,
    };

    validateApiKey.mockResolvedValue({
      success: true,
      ...defaultKeyData,
      ...keyData,
    });

    return { ...defaultKeyData, ...keyData };
  },

  /**
   * Mock failed authentication
   */
  failed: () => {
    const { getSession } = require("@auth0/nextjs-auth0");
    const { validateApiKey } = require("@/middleware/api-auth");

    getSession.mockResolvedValue(null);
    validateApiKey.mockResolvedValue({
      success: false,
      error: "Invalid API key",
    });
  },

  /**
   * Clear all auth mocks
   */
  clear: () => {
    jest.clearAllMocks();
  },
};

/**
 * Database test utilities (extends proven patterns)
 */
export const dbTestUtils = {
  /**
   * Set up database mocks for API testing
   */
  setupMocks: () => {
    const { sql: mockSql } = require("../src/lib/database");
    const bcrypt = require("bcryptjs");

    bcrypt.hash.mockResolvedValue("$2b$12$hashedkey");
    bcrypt.compare.mockResolvedValue(true);

    return mockSql;
  },

  /**
   * Create test user data
   */
  createUserData: (overrides: any = {}) => ({
    id: "test-user-123",
    sub: "auth0|test-user-123",
    email: "test@example.com",
    name: "Test User",
    created_at: new Date(),
    ...overrides,
  }),

  /**
   * Create test API key data
   */
  createApiKeyData: (overrides: any = {}) => ({
    id: "test-key-123",
    user_id: "test-user-123",
    key_name: "Test API Key",
    key_hash: "$2b$12$hashedkey",
    key_hint: "vibe_test_abc123",
    environment: "test",
    is_active: true,
    expires_at: null,
    rate_limit_per_minute: 60,
    rate_limit_per_hour: 1000,
    burst_allowance: 5,
    created_at: new Date(),
    ...overrides,
  }),
};

/**
 * Response assertion utilities
 */
export const responseAssertions = {
  /**
   * Assert successful API response
   */
  success: (res: NextApiResponse, expectedStatus: number = 200) => {
    expect(res._getStatusCode()).toBe(expectedStatus);

    const data = JSON.parse(res._getData());
    expect(data).toBeDefined();

    return data;
  },

  /**
   * Assert error API response
   */
  error: (
    res: NextApiResponse,
    expectedStatus: number,
    expectedMessage?: string
  ) => {
    expect(res._getStatusCode()).toBe(expectedStatus);

    const data = JSON.parse(res._getData());
    expect(data).toHaveProperty("error");

    if (expectedMessage) {
      expect(data.error).toContain(expectedMessage);
    }

    return data;
  },

  /**
   * Assert validation error response
   */
  validation: (res: NextApiResponse, field?: string) => {
    expect(res._getStatusCode()).toBe(400);

    const data = JSON.parse(res._getData());
    expect(data).toHaveProperty("error");

    if (field) {
      expect(data.error).toContain(field);
    }

    return data;
  },
};

/**
 * Middleware test utilities
 */
export const middlewareUtils = {
  /**
   * Mock rate limiting
   */
  rateLimit: (allowed: boolean = true, remaining: number = 10) => {
    const { checkRateLimit } = require("@/middleware/database-rate-limit");

    checkRateLimit.mockResolvedValue({
      allowed,
      remaining,
      resetTime: Date.now() + 60000,
    });
  },

  /**
   * Mock rate limit exceeded
   */
  rateLimitExceeded: () => {
    const { checkRateLimit } = require("@/middleware/database-rate-limit");

    checkRateLimit.mockResolvedValue({
      allowed: false,
      remaining: 0,
      resetTime: Date.now() + 60000,
    });
  },
};
```

---

## 🧪 API Testing Patterns

### Pattern 1: API Key Generation Endpoint

```typescript
import apiKeysHandler from "../pages/api/user/api-keys";
import {
  createAPITest,
  mockAuth,
  dbTestUtils,
  responseAssertions,
} from "../tests/helpers/api-test-helpers";

describe("API: User API Keys Management", () => {
  let mockSql: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mockSql = dbTestUtils.setupMocks();
  });

  test("✅ POST /api/user/api-keys - Generate new API key", async () => {
    console.log("🧪 Testing API key generation endpoint");

    // Set up authentication
    mockAuth.session({ sub: "user-123", email: "test@example.com" });

    // Set up database mocks (proven pattern)
    mockSql
      .mockResolvedValueOnce([{ count: 0 }]) // Count check
      .mockResolvedValueOnce([{ id: "new-key-123", created_at: new Date() }]) // Insert
      .mockResolvedValueOnce([]); // Audit log

    // Create API request
    const { req, res } = createAPITest({
      method: "POST",
      body: {
        keyName: "My CLI Key",
        environment: "test",
      },
    });

    // Execute API handler
    await apiKeysHandler(req, res);

    // Assert response
    const data = responseAssertions.success(res, 201);
    expect(data.id).toBe("new-key-123");
    expect(data.key).toMatch(/^vibe_test_/);
    expect(data.environment).toBe("test");

    console.log("✅ API key generation endpoint working");
  });

  test("✅ GET /api/user/api-keys - List user API keys", async () => {
    console.log("🧪 Testing API keys list endpoint");

    // Set up authentication
    mockAuth.session({ sub: "user-123", email: "test@example.com" });

    // Mock database response with multiple keys
    const mockKeys = [
      dbTestUtils.createApiKeyData({ key_name: "CLI Key", usage_count: 42 }),
      dbTestUtils.createApiKeyData({
        id: "key-2",
        key_name: "Production Key",
        environment: "live",
        usage_count: 0,
      }),
    ];

    mockSql.mockResolvedValueOnce(mockKeys);

    // Create API request
    const { req, res } = createAPITest({ method: "GET" });

    // Execute API handler
    await apiKeysHandler(req, res);

    // Assert response
    const data = responseAssertions.success(res, 200);
    expect(data.keys).toHaveLength(2);
    expect(data.keys[0].keyName).toBe("CLI Key");
    expect(data.keys[0].usageCount).toBe(42);
    expect(data.keys[1].keyName).toBe("Production Key");

    console.log("✅ API keys list endpoint working");
  });

  test("❌ POST /api/user/api-keys - Unauthorized request", async () => {
    console.log("🧪 Testing unauthorized API key generation");

    // No authentication setup (should fail)
    mockAuth.failed();

    const { req, res } = createAPITest({
      method: "POST",
      body: { keyName: "Unauthorized Key" },
    });

    await apiKeysHandler(req, res);

    responseAssertions.error(res, 401, "Unauthorized");

    console.log("✅ Unauthorized access properly rejected");
  });
});
```

### Pattern 2: CLI API Endpoint Testing

```typescript
import parseHandler from "../pages/api/vibecoder/parse-prd";
import {
  createAPITest,
  mockAuth,
  dbTestUtils,
  responseAssertions,
} from "../tests/helpers/api-test-helpers";

describe("API: VibeCoder Parse PRD", () => {
  let mockSql: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mockSql = dbTestUtils.setupMocks();

    // Mock AI orchestra
    const mockOrchestra = require("../src/lib/vibecoder-ai-orchestra-v2");
    mockOrchestra.analyzeProjectRequirements = jest.fn();
  });

  test("✅ POST /api/vibecoder/parse-prd - CLI authentication with API key", async () => {
    console.log("🧪 Testing CLI PRD parsing with API key auth");

    // Set up API key authentication
    const keyData = mockAuth.apiKey({
      userId: "cli-user-123",
      environment: "test",
    });

    // Mock API key validation database query
    mockSql.mockResolvedValueOnce([
      dbTestUtils.createApiKeyData({
        user_id: keyData.userId,
        environment: "test",
      }),
    ]);

    // Mock AI analysis response
    const mockOrchestra = require("../src/lib/vibecoder-ai-orchestra-v2");
    mockOrchestra.analyzeProjectRequirements.mockResolvedValue({
      success: true,
      analysis: {
        summary: "Todo app with authentication",
        features: ["User management", "Task CRUD", "Authentication"],
        complexity: "medium",
        estimatedHours: 40,
      },
    });

    // Create API request with API key
    const { req, res } = createAPITest({
      method: "POST",
      headers: {
        "x-api-key": "vibe_test_" + "a".repeat(64),
      },
      body: {
        requirements:
          "Build a todo app with user authentication and task management",
      },
    });

    // Execute API handler
    await parseHandler(req, res);

    // Assert response
    const data = responseAssertions.success(res, 200);
    expect(data.success).toBe(true);
    expect(data.analysis).toBeDefined();
    expect(data.analysis.features).toContain("User management");
    expect(data.analysis.complexity).toBe("medium");

    console.log("✅ CLI PRD parsing with API key successful");
  });

  test("❌ POST /api/vibecoder/parse-prd - Invalid API key", async () => {
    console.log("🧪 Testing PRD parsing with invalid API key");

    // Mock failed API key validation
    mockAuth.failed();
    mockSql.mockResolvedValueOnce([]); // No matching API key

    const { req, res } = createAPITest({
      method: "POST",
      headers: {
        "x-api-key": "invalid_key",
      },
      body: {
        requirements: "Build something",
      },
    });

    await parseHandler(req, res);

    responseAssertions.error(res, 401, "Invalid API key");

    console.log("✅ Invalid API key properly rejected");
  });
});
```

### Pattern 3: Rate Limiting Testing

```typescript
import statusHandler from "../pages/api/vibecoder/status";
import {
  createAPITest,
  mockAuth,
  middlewareUtils,
  responseAssertions,
} from "../tests/helpers/api-test-helpers";

describe("API: Rate Limiting", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("✅ Rate limiting allows normal usage", async () => {
    console.log("🧪 Testing normal rate limiting");

    // Set up authentication and rate limiting
    mockAuth.apiKey();
    middlewareUtils.rateLimit(true, 59); // 59 requests remaining

    const { req, res } = createAPITest({
      method: "GET",
      headers: {
        "x-api-key": "vibe_test_" + "a".repeat(64),
      },
    });

    await statusHandler(req, res);

    const data = responseAssertions.success(res, 200);
    expect(data.rateLimit).toBeDefined();
    expect(data.rateLimit.remaining).toBe(59);

    console.log("✅ Rate limiting working normally");
  });

  test("❌ Rate limiting blocks excessive usage", async () => {
    console.log("🧪 Testing rate limit exceeded");

    // Set up authentication but rate limit exceeded
    mockAuth.apiKey();
    middlewareUtils.rateLimitExceeded();

    const { req, res } = createAPITest({
      method: "GET",
      headers: {
        "x-api-key": "vibe_test_" + "a".repeat(64),
      },
    });

    await statusHandler(req, res);

    responseAssertions.error(res, 429, "Rate limit exceeded");

    console.log("✅ Rate limiting properly blocking excessive usage");
  });
});
```

---

## 🎯 Best Practices

### ✅ DO: Use Clear Test Structure

```typescript
describe("API: Feature Name", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSql = dbTestUtils.setupMocks();
  });

  test("✅ Happy path description", async () => {
    // 1. Setup authentication
    // 2. Setup database mocks
    // 3. Create API request
    // 4. Execute handler
    // 5. Assert response
  });

  test("❌ Error path description", async () => {
    // Test error scenarios
  });
});
```

### ✅ DO: Test Authentication Scenarios

```typescript
// Test both session and API key auth
test("Web user access with session", async () => {
  mockAuth.session({ sub: "web-user" });
  // ... test logic
});

test("CLI access with API key", async () => {
  mockAuth.apiKey({ userId: "cli-user" });
  // ... test logic
});

test("Unauthorized access", async () => {
  mockAuth.failed();
  // ... expect 401
});
```

### ✅ DO: Use Transaction Rollback for Integration Tests

```typescript
import { withTransaction } from "../src/lib/transaction-test-manager";

test("Full integration with real database", async () => {
  await withTransaction(async (sql) => {
    // Create real test data
    const user = await createTestUser(sql);
    const apiKey = await createTestApiKey(sql, user.id);

    // Test API endpoint with real data
    const { req, res } = createAPITest({
      method: "GET",
      headers: { "x-api-key": apiKey.raw_key },
    });

    await apiHandler(req, res);

    // Assert results
    // Data automatically rolled back
  });
});
```

### ❌ DON'T: Test API Endpoints Without Proper Setup

```typescript
// BAD: Direct import without middleware mocking
import apiHandler from "../pages/api/some-endpoint";

test("API test", async () => {
  // This will fail with missing middleware errors
  await apiHandler(req, res);
});
```

### ❌ DON'T: Mix Unit and API Testing

```typescript
// BAD: Testing both core logic and API in same file
describe("Mixed Tests", () => {
  test("Core logic test", async () => {
    // Test ApiKeyManager directly
  });

  test("API endpoint test", async () => {
    // Test API handler
  });
});
```

---

## 🛠️ Reusable Test Suites

### Standard API Key Endpoint Tests

```typescript
export function createApiKeyEndpointTests(handlerPath: string) {
  return describe(`API Key Endpoint: ${handlerPath}`, () => {
    const handler = require(handlerPath);
    let mockSql: jest.Mock;

    beforeEach(() => {
      jest.clearAllMocks();
      mockSql = dbTestUtils.setupMocks();
    });

    test("✅ Authenticated request succeeds", async () => {
      mockAuth.session();
      // Standard success test
    });

    test("❌ Unauthenticated request fails", async () => {
      mockAuth.failed();
      // Standard auth failure test
    });

    test("❌ Rate limit exceeded", async () => {
      mockAuth.session();
      middlewareUtils.rateLimitExceeded();
      // Standard rate limit test
    });
  });
}

// Usage
createApiKeyEndpointTests("../pages/api/user/api-keys");
createApiKeyEndpointTests("../pages/api/user/profile");
```

---

## 🚀 Running API Tests

### API Tests Only

```bash
npx jest __tests__/api-*.test.ts --config=jest.api.config.js --verbose
```

### Specific API Endpoint

```bash
npx jest __tests__/api-user-keys.test.ts --config=jest.api.config.js --verbose
```

### With Coverage

```bash
npx jest --config=jest.api.config.js --coverage
```

### Debug Mode

```bash
npx jest __tests__/api-*.test.ts --config=jest.api.config.js --verbose --detectOpenHandles
```

---

## 🔄 Migration from Unit to API Testing

### Step 1: Identify What to Test

| Test Type       | Use For             | Example                            |
| --------------- | ------------------- | ---------------------------------- |
| **Unit**        | Core business logic | `ApiKeyManager.generateApiKey()`   |
| **API**         | HTTP endpoints      | `POST /api/user/api-keys`          |
| **Integration** | Full workflows      | Generate key → Use key → Parse PRD |

### Step 2: Convert Unit Test to API Test

```typescript
// BEFORE: Unit test
test("Generate API key", async () => {
  const result = await ApiKeyManager.generateApiKey(userId, options);
  expect(result.keyId).toBeDefined();
});

// AFTER: API test
test("POST /api/user/api-keys", async () => {
  mockAuth.session({ sub: userId });
  mockSql.mockImplementationForGeneration();

  const { req, res } = createAPITest({
    method: "POST",
    body: options,
  });

  await apiKeysHandler(req, res);

  const data = responseAssertions.success(res, 201);
  expect(data.id).toBeDefined();
});
```

---

## 🆘 Troubleshooting

### Issue: Cannot find module '@/middleware/...'

**Solution**: Add middleware mocks in `jest.api.setup.js` before any imports

### Issue: Auth0 getSession is not a function

**Solution**: Ensure Auth0 is mocked at module level in setup file

### Issue: Tests hanging with API calls

**Solution**: Check for unmocked external service calls, add mocks

### Issue: Database connection errors in API tests

**Solution**: Verify `jest.api.setup.js` extends `jest.database.setup.js`

---

## 🏆 Success Metrics

### API Testing Goals

- ✅ **Authentication flows tested**: Session + API key
- ✅ **Error scenarios covered**: 401, 403, 429, 500
- ✅ **Request/Response validation**: Input validation + output format
- ✅ **Integration scenarios**: Multi-step workflows
- ✅ **Performance**: Rate limiting and timeout handling

---

**Created by**: API Testing Infrastructure Team  
**Last Updated**: January 2025  
**Status**: ✅ Production Ready  
**Extends**: [Database Testing Infrastructure](./Database-Testing-Infrastructure-Guide.md)
