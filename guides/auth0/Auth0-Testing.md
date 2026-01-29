# Auth0 v4.6.0 Testing Guide

This guide explains how to properly test Auth0 v4.6.0 integration in our application.

## Table of Contents

1. [Testing Environment Setup](#testing-environment-setup)
2. [Mocking Auth0 SDK](#mocking-auth0-sdk)
3. [Testing API Routes](#testing-api-routes)
4. [Testing Middleware](#testing-middleware)
5. [Testing Client-Side Components](#testing-client-side-components)
6. [Testing Database Integration](#testing-database-integration)

## Testing Environment Setup

### Environment Variables

Create a `.env.test` file with the following Auth0 test variables:

```env
# Auth0 v4.6.0 Required Variables (PLACEHOLDER VALUES ONLY)
APP_BASE_URL=http://localhost:3000
AUTH0_DOMAIN=test-tenant.us.auth0.com
AUTH0_CLIENT_ID=test-client-id
AUTH0_CLIENT_SECRET=test-client-secret
AUTH0_SECRET=test-secret-must-be-at-least-32-chars-long
```

### Jest Setup

In your Jest setup file (`tests/setup.ts`), ensure Auth0 is properly mocked:

```typescript
// Mock Auth0 SDK
jest.mock("@auth0/nextjs-auth0", () => ({
  auth: jest.fn().mockReturnValue({
    getSession: jest.fn(),
    handleLogin: jest.fn(),
    handleLogout: jest.fn(),
    handleCallback: jest.fn(),
    withApiAuthRequired: jest.fn((handler) => handler),
  }),

  // For client-side testing
  useAuth0: jest.fn(() => ({
    isAuthenticated: true,
    user: {
      sub: "auth0|12345",
      name: "Test User",
      email: "test@example.com",
      email_verified: true,
      picture: "https://example.com/avatar.png",
    },
    isLoading: false,
    getAccessTokenSilently: jest.fn().mockResolvedValue("mock-access-token"),
    loginWithRedirect: jest.fn(),
    logout: jest.fn(),
  })),

  Auth0Provider: ({ children }) => children,
  withAuthenticationRequired: (component) => component,
}));
```

## Mocking Auth0 SDK

### Server-Side Mocking

Use the following pattern to mock Auth0 SDK for server-side tests:

```typescript
// Create a mock Auth0 client
const mockGetSession = jest.fn();
const mockAuth0Client = {
  getSession: mockGetSession,
  handleLogin: jest.fn(),
  handleLogout: jest.fn(),
  handleCallback: jest.fn(),
  withApiAuthRequired: jest.fn((handler) => handler),
};

// Mock the Auth0 SDK
jest.mock("@auth0/nextjs-auth0", () => ({
  auth: jest.fn(() => mockAuth0Client),
}));

// In your test:
mockGetSession.mockResolvedValueOnce({
  user: {
    sub: "auth0|12345",
    name: "Test User",
    email: "test@example.com",
  },
  accessToken: "mock-access-token",
});
```

### Client-Side Mocking

For React components using the Auth0 hooks:

```typescript
jest.mock("@auth0/auth0-react", () => ({
  useAuth0: jest.fn(() => ({
    isAuthenticated: true,
    user: {
      sub: "auth0|12345",
      name: "Test User",
      email: "test@example.com",
    },
    isLoading: false,
    loginWithRedirect: jest.fn(),
    logout: jest.fn(),
    getAccessTokenSilently: jest.fn().mockResolvedValue("mock-token"),
  })),
  Auth0Provider: ({ children }) => children,
  withAuthenticationRequired: (component) => component,
}));
```

## Testing API Routes

### Example: Testing a Protected API Route

```typescript
import { createMocks } from "node-mocks-http";
import { auth } from "@auth0/nextjs-auth0";
import userProfileHandler from "../../../src/pages/api/user/profile";

// Mock Auth0 client
jest.mock("@auth0/nextjs-auth0", () => ({
  auth: jest.fn().mockReturnValue({
    getSession: jest.fn(),
    withApiAuthRequired: jest.fn((handler) => handler),
  }),
}));

// In your test:
it("returns user profile when authenticated", async () => {
  const mockSession = {
    user: {
      sub: "auth0|12345",
      email: "test@example.com",
    },
    accessToken: "mock-access-token",
  };

  const mockAuth0 = auth();
  mockAuth0.getSession.mockResolvedValueOnce(mockSession);

  const { req, res } = createMocks({ method: "GET" });

  await userProfileHandler(req, res);

  expect(res._getStatusCode()).toBe(200);
  expect(mockAuth0.getSession).toHaveBeenCalledWith(req);
});
```

## Testing Middleware

### Example: Testing Auth Middleware

```typescript
import { NextRequest } from "next/server";
import { withAuth } from "../../src/middleware/auth";

// Mock cookies to simulate auth state
const mockCookies = {
  get: jest.fn(),
};

// Mock NextRequest
jest.mock("next/server", () => {
  const original = jest.requireActual("next/server");
  return {
    ...original,
    NextRequest: jest.fn().mockImplementation((url) => ({
      ...new original.NextRequest(url),
      cookies: mockCookies,
      nextUrl: new URL(url),
    })),
  };
});

// In your test:
it("allows authenticated users to access protected routes", async () => {
  mockCookies.get.mockReturnValueOnce({
    name: "appSession",
    value: "mock-session-value",
  });

  const req = new NextRequest("http://localhost:3000/dashboard");
  const context = { params: {} };

  const response = await withAuth(req, context);

  expect(response).toBeUndefined(); // No redirect = allowed
  expect(mockCookies.get).toHaveBeenCalledWith("appSession");
});
```

## Testing Client-Side Components

### Example: Testing Protected Component

```typescript
import { render, screen } from "@testing-library/react";
import { useAuth0 } from "@auth0/auth0-react";
import ProtectedComponent from "../../src/components/ProtectedComponent";

// Mock Auth0 hook
jest.mock("@auth0/auth0-react", () => ({
  useAuth0: jest.fn(),
}));

// In your test:
it("displays user information when authenticated", () => {
  (useAuth0 as jest.Mock).mockReturnValue({
    isAuthenticated: true,
    user: {
      name: "Test User",
      email: "test@example.com",
    },
    isLoading: false,
  });

  render(<ProtectedComponent />);

  expect(screen.getByText("Test User")).toBeInTheDocument();
});

it("shows loading state", () => {
  (useAuth0 as jest.Mock).mockReturnValue({
    isAuthenticated: false,
    user: null,
    isLoading: true,
  });

  render(<ProtectedComponent />);

  expect(screen.getByText("Loading...")).toBeInTheDocument();
});
```

## Testing Database Integration

### Example: Testing Auth0 User Synchronization with Database

```typescript
import { getUser, upsertUser } from "../../src/lib/database";

// Mock database operations
jest.mock("../../src/lib/database", () => ({
  getUser: jest.fn(),
  upsertUser: jest.fn(),
}));

// Mock Auth0
const mockGetSession = jest.fn();
jest.mock("@auth0/nextjs-auth0", () => ({
  auth: jest.fn(() => ({
    getSession: mockGetSession,
  })),
}));

// In your test:
it("synchronizes Auth0 user with database", async () => {
  const mockSession = {
    user: {
      sub: "auth0|12345",
      email: "test@example.com",
      name: "Test User",
    },
  };

  mockGetSession.mockResolvedValueOnce(mockSession);
  (upsertUser as jest.Mock).mockResolvedValueOnce({
    id: "auth0|12345",
    email: "test@example.com",
    name: "Test User",
  });

  // Test your actual integration logic here
  // For example:
  const { req } = createMocks({ method: "GET" });
  const authClient = auth();
  const session = await authClient.getSession(req);

  if (session?.user) {
    await upsertUser(session.user);
  }

  expect(upsertUser).toHaveBeenCalledWith(mockSession.user);
});
```

## Best Practices

1. **Never use real Auth0 credentials in tests** - Always use placeholders
2. **Mock at the module level** - This ensures consistent behavior across tests
3. **Test both authenticated and unauthenticated states**
4. **Test error handling** - Simulate Auth0 service errors
5. **Use different mocks for client-side vs server-side** - Auth0 has different APIs for each
6. **Validate that correct Auth0 methods are called** - Use `expect(mockFunction).toHaveBeenCalledWith()`

## Common Issues and Solutions

### Token Verification in Middleware

For middleware tests, you'll need to mock JWT verification:

```typescript
// Custom getSession implementation for middleware
const getSession = async (req: NextRequest) => {
  const authCookie = req.cookies.get("appSession");
  if (!authCookie) return null;

  // In tests, simulate a decoded payload
  return {
    user: { sub: "test-user", email: "test@example.com" },
    accessToken: "mock-token",
  };
};
```

### Client-Side Route Protection

When testing components that use withAuthenticationRequired:

```typescript
// Mock the higher-order component
jest.mock("@auth0/auth0-react", () => ({
  ...jest.requireActual("@auth0/auth0-react"),
  withAuthenticationRequired: jest.fn((component) => component),
}));
```

### Testing Both Auth0 v4.6.0 and Previous Versions

If your app supports both versions during migration:

```typescript
// Define version flag in setup
const useAuth0v4 = process.env.USE_AUTH0_V4 === "true";

// Then conditionally mock
if (useAuth0v4) {
  jest.mock("@auth0/nextjs-auth0", () => ({
    auth: jest.fn().mockReturnValue({
      getSession: jest.fn(),
      // v4.6.0 methods
    }),
  }));
} else {
  jest.mock("@auth0/nextjs-auth0", () => ({
    getSession: jest.fn(),
    // Legacy methods
  }));
}
```
