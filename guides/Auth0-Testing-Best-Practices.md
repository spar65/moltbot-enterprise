# Auth0 Testing Best Practices Guide

## Overview

This guide documents the best practices for testing Auth0 integration in the VibeCoder platform. It captures key learnings from our extensive work fixing test issues and creating reliable authentication test patterns.

## Core Testing Principle

**"Test Real Behavior, Mock External Dependencies"**

This principle transformed our test suite from brittle, over-mocked tests to robust tests that validate actual behavior. By following this principle, we achieved:

- 29 failing tests fixed with a consistent approach
- More reliable test suite with proper isolation
- Tests that validate real behavior, not mock implementations

## Reusable Auth0 Test Utilities

We created centralized test utilities that can be reused across different test files:

```typescript
// tests/utils/auth0-test-utils.ts
import { NextApiRequest, NextApiResponse } from "next";

export interface MockSession {
  user?: {
    sub: string;
    email: string;
    name?: string;
    [key: string]: any;
  } | null;
}

export interface MockAuth0Client {
  getSession: jest.MockedFunction<any>;
  updateUser: jest.MockedFunction<any>;
  middleware: jest.MockedFunction<any>;
}

export function createMockAuth0Client(
  defaultSession: MockSession | null = {}
): MockAuth0Client {
  return {
    getSession: jest
      .fn()
      .mockResolvedValue(
        defaultSession && defaultSession.user
          ? { user: defaultSession.user }
          : null
      ),
    updateUser: jest.fn().mockResolvedValue({}),
    middleware: jest.fn().mockReturnValue(null), // Passthrough by default
  };
}

export function createMockAdminSession() {
  return {
    user: {
      sub: "auth0|admin123",
      email: "admin@vibecoder.com",
      name: "Test Admin",
      "https://vibecoder.com/roles": ["admin"],
    },
  };
}

export function createMockRegularSession() {
  return {
    user: {
      sub: "auth0|user123",
      email: "user@example.com",
      name: "Test User",
    },
  };
}

// Helper to setup Auth0 mocks consistently
export function setupAuth0Mock(
  session: MockSession | null = {}
): MockAuth0Client {
  const mockClient = createMockAuth0Client(session);

  jest.doMock("@auth0/nextjs-auth0", () => ({
    getSession: mockClient.getSession,
    withApiAuthRequired: (handler: any) => handler,
    useUser: () => ({
      user: session && session.user ? session.user : null,
      error: null,
      isLoading: false,
    }),
    UserProvider: ({ children }: any) => children,
  }));

  return mockClient;
}

// Setup test environment variables
export function setupTestEnvironment() {
  process.env.ADMIN_EMAILS = "admin@vibecoder.com,test@admin.com";
  process.env.AUTH0_SECRET = "test-secret-32-characters-long!!";
  process.env.AUTH0_DOMAIN = "test-tenant.auth0.com";
}

// Debug helper for auth state
export function debugAuthState(testName: string, session: any) {
  if (process.env.DEBUG_AUTH_TESTS) {
    console.log(`🔍 ${testName}:`, {
      hasUser: !!session?.user,
      email: session?.user?.email,
      roles: session?.user?.["https://vibecoder.com/roles"],
    });
  }
}
```

## Testing Patterns

### 1. API Handler Testing

Testing API handlers that require Auth0 authentication:

```typescript
// tests/api/admin-subscription-tiers.test.ts
describe("/api/admin/subscription-tiers", () => {
  let mockAuth0: any;
  const mockSql = require("../../src/lib/database").sql;

  beforeEach(() => {
    jest.clearAllMocks();
    setupTestEnvironment();

    // Setup default successful database response
    mockSql.mockResolvedValue([
      {
        id: "basic",
        name: "Basic Plan",
        price_monthly: 9.99,
        features: { support: "email" },
      },
    ]);
  });

  afterEach(() => {
    jest.resetModules();
  });

  it("should allow admin users to access subscription tiers", async () => {
    // Setup admin session
    const adminSession = createMockAdminSession();
    mockAuth0 = setupAuth0Mock(adminSession);
    debugAuthState("admin-subscription-access", adminSession);

    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
      method: "GET",
    });

    // Test the REAL API handler
    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const responseData = JSON.parse(res._getData());
    expect(responseData).toHaveProperty("tiers");
    expect(Array.isArray(responseData.tiers)).toBe(true);
  });
});
```

### 2. Error Handling Testing

Testing Auth0 error handling scenarios:

```typescript
// tests/auth0/error-handling.test.ts
describe("Auth0 Error Handling", () => {
  let mockAuth0: any;

  beforeEach(() => {
    jest.clearAllMocks();
    setupTestEnvironment();
  });

  afterEach(() => {
    jest.resetModules();
  });

  it("should handle identity provider errors with 502 status", async () => {
    // Setup mock to throw identity provider error
    mockAuth0 = setupAuth0Mock();
    mockAuth0.getSession.mockRejectedValue({
      name: "IdentityProviderError",
      statusCode: 502,
      message: "Identity provider unavailable",
    });

    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
      method: "GET",
    });

    // Call the real error handler with the mocked request/response
    await handleAuth0Error(req, res, async () => {
      // This will trigger the error
      const { getSession } = require("@auth0/nextjs-auth0");
      await getSession(req, res);
    });

    // Verify the error was handled correctly
    expect(res._getStatusCode()).toBe(502);
    expect(JSON.parse(res._getData())).toMatchObject({
      error: "identity_provider_error",
      message: expect.stringContaining("temporarily unavailable"),
    });
  });
});
```

### 3. User Database Sync Testing

Testing synchronization between Auth0 and your database:

```typescript
// tests/auth0/user-db-sync.test.ts
describe("Auth0 User Database Synchronization", () => {
  let mockAuth0: any;

  beforeEach(() => {
    jest.clearAllMocks();
    setupTestEnvironment();

    // Default mock implementations for database functions
    (getUserById as jest.Mock).mockResolvedValue(null);
    (createUser as jest.Mock).mockImplementation((userData) => userData);
    (updateUser as jest.Mock).mockImplementation((id, userData) => ({
      id,
      ...userData,
    }));
  });

  test("should create new user when not found in database", async () => {
    // Setup mock session for authenticated user not in database
    const userSession = {
      user: {
        sub: "auth0|new-user",
        email: "new@example.com",
        name: "New User",
      },
    };
    mockAuth0 = setupAuth0Mock(userSession);

    // Create mock request/response
    const { req, res } = createMocks({
      method: "GET",
    });

    // Call handler
    await userSyncHandler(req, res);

    // Verify response
    expect(res._getStatusCode()).toBe(201);
    expect(JSON.parse(res._getData()).message).toBe(
      "User created and synchronized"
    );

    // Verify database operations
    expect(getUserById).toHaveBeenCalledWith("auth0|new-user");
    expect(createUser).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "auth0|new-user",
        email: "new@example.com",
        name: "New User",
      })
    );
  });
});
```

### 4. Component Testing with Auth0

Testing React components that use Auth0 authentication:

```typescript
// tests/components/protected-content.test.tsx
describe("Protected Content Component", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    setupTestEnvironment();
  });

  afterEach(() => {
    jest.resetModules();
  });

  it("should render content for authenticated users", async () => {
    // Setup authenticated user session
    const userSession = createMockRegularSession();
    mockAuth0 = setupAuth0Mock(userSession);

    render(
      <SubscriptionProvider>
        <ProtectedContent>
          <div data-testid="protected-content">Secret Content</div>
        </ProtectedContent>
      </SubscriptionProvider>
    );

    // Content should be visible for authenticated users
    expect(screen.getByTestId("protected-content")).toBeInTheDocument();
    expect(screen.getByText("Secret Content")).toBeInTheDocument();
  });

  it("should not render content for unauthenticated users", async () => {
    // Setup unauthenticated session (null)
    mockAuth0 = setupAuth0Mock(null);

    render(
      <SubscriptionProvider>
        <ProtectedContent>
          <div data-testid="protected-content">Secret Content</div>
        </ProtectedContent>
      </SubscriptionProvider>
    );

    // Content should not be visible
    expect(screen.queryByTestId("protected-content")).not.toBeInTheDocument();
    expect(screen.queryByText("Secret Content")).not.toBeInTheDocument();
    // Should show login prompt
    expect(screen.getByText(/log in/i)).toBeInTheDocument();
  });
});
```

## Best Practices

### 1. Test Setup and Teardown

Always follow these patterns for Auth0 testing:

```typescript
beforeEach(() => {
  // Clear all mocks to prevent test interference
  jest.clearAllMocks();

  // Setup test environment variables
  setupTestEnvironment();

  // Mock external dependencies but not your components
  mockDatabase = jest.spyOn(database, "query").mockImplementation(() => []);
});

afterEach(() => {
  // Reset modules to prevent leaking state between tests
  jest.resetModules();
});
```

### 2. Testing Real Components

**Good Pattern**: Testing real components with mocked dependencies

```typescript
// Import real component
import UserManagementPage from "../../pages/admin/users";

// Test the real component with mocked external dependencies
render(<UserManagementPage />);
```

**Bad Pattern**: Testing fake mocked components

```typescript
// DON'T DO THIS
jest.mock("../../pages/admin/users", () => {
  return function MockUserManagementPage() {
    return <div>Fake content</div>; // Not testing real logic
  };
});
```

### 3. Proper Error Testing

**Good Pattern**: Testing real error handlers with mocked errors

```typescript
// Mock Auth0 to throw specific error
mockAuth0.getSession.mockRejectedValue({
  name: "IdentityProviderError",
  statusCode: 502,
  message: "Identity provider unavailable",
});

// Test real error handler with mocked error
await handleAuth0Error(req, res, async () => {
  const { getSession } = require("@auth0/nextjs-auth0");
  await getSession(req, res);
});

// Verify correct error handling
expect(res._getStatusCode()).toBe(502);
```

## Common Auth0 Testing Challenges

### Challenge 1: Session Mocking

**Problem**: Tests failing because Auth0 sessions aren't properly mocked.

**Solution**: Use centralized session mocking with proper cleanup:

```typescript
// Setup consistent session mock
const adminSession = createMockAdminSession();
mockAuth0 = setupAuth0Mock(adminSession);

// Clean up after test
afterEach(() => {
  jest.resetModules(); // Prevents session leaking between tests
});
```

### Challenge 2: Testing Authorization Logic

**Problem**: Admin-only routes are difficult to test.

**Solution**: Test with both admin and non-admin sessions:

```typescript
it("should block non-admin users", async () => {
  // Setup regular user session (not admin)
  mockAuth0 = setupAuth0Mock(createMockRegularSession());

  const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
    method: "GET",
  });

  await handler(req, res);

  expect(res._getStatusCode()).toBe(403);
});

it("should allow admin users", async () => {
  // Setup admin user session
  mockAuth0 = setupAuth0Mock(createMockAdminSession());

  const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
    method: "GET",
  });

  await handler(req, res);

  expect(res._getStatusCode()).toBe(200);
});
```

### Challenge 3: Middleware Testing

**Problem**: Auth0 middleware is difficult to test because it involves complex Next.js request/response objects.

**Solution**: Use simplified middleware testing:

```typescript
// Mock Next.js middleware requirements
jest.mock("next/server", () => ({
  ...jest.requireActual("next/server"),
  NextResponse: {
    next: jest.fn().mockReturnValue({ type: "next" }),
    redirect: jest.fn((url) => ({ type: "redirect", url })),
  },
}));

it("should redirect unauthenticated users", async () => {
  // Mock Auth0 middleware to simulate redirect
  mockAuth0.middleware.mockReturnValue({
    type: "redirect",
    url: "/auth/login",
  });

  const request = new NextRequest("http://localhost:3000/protected");
  const result = await middleware(request);

  expect(result).toEqual({ type: "redirect", url: "/auth/login" });
});
```

## Conclusion

By adopting these Auth0 testing best practices, we've transformed our test suite from brittle and unreliable to robust and maintainable. The key insights are:

1. **Test real behavior, mock external dependencies** - Don't mock your own components
2. **Use centralized utilities** for consistent Auth0 mocking
3. **Ensure proper test isolation** with appropriate setup and teardown
4. **Test both success and failure paths** for comprehensive coverage

These practices have allowed us to validate our Auth0 integration with confidence while making the tests easier to maintain and extend.
