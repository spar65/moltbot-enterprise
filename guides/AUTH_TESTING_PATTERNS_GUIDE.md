# Authentication Testing Patterns Guide

This guide provides practical implementation strategies for testing authentication flows in modern web applications, with a focus on Auth0 integration.

## Introduction

Properly testing authentication is critical for application security and user experience. This guide extends the `400-auth-testing-patterns.mdc` rule with concrete examples and implementation patterns.

## Table of Contents

1. [Testing Pyramid for Authentication](#testing-pyramid-for-authentication)
2. [Setting Up the Testing Environment](#setting-up-the-testing-environment)
3. [Mocking Authentication](#mocking-authentication)
4. [Unit Testing Auth Components](#unit-testing-auth-components)
5. [Testing Protected Routes](#testing-protected-routes)
6. [Testing Authentication Failures](#testing-authentication-failures)
7. [Integration Testing Auth Flows](#integration-testing-auth-flows)
8. [E2E Testing with Cypress](#e2e-testing-with-cypress)
9. [Security-Focused Testing](#security-focused-testing)
10. [Common Pitfalls](#common-pitfalls)

## Testing Pyramid for Authentication

Authentication testing should follow a testing pyramid approach:

```
    /\
   /  \      E2E Tests (Cypress/Playwright)
  /    \     • Full login/logout flows
 /      \    • Session management
/        \   • Protected route access
----------
\        /   Integration Tests
 \      /    • Auth middleware
  \    /     • API + Auth interactions
   \  /      • Token validation flows
    \/
    /\
   /  \      Component Tests
  /    \     • Auth UI components
 /      \    • Conditional rendering
/        \   • Error handling states
----------
\        /   Unit Tests
 \      /    • Auth utilities
  \    /     • Permission checks
   \  /      • Token parsing
    \/
```

## Setting Up the Testing Environment

### Testing Dependencies

```json
// package.json testing dependencies
{
  "devDependencies": {
    "jest": "^29.5.0",
    "jest-environment-jsdom": "^29.5.0",
    "@testing-library/react": "^14.0.0",
    "@testing-library/jest-dom": "^5.16.5",
    "@testing-library/user-event": "^14.4.3",
    "cypress": "^12.12.0",
    "msw": "^1.2.1"
  }
}
```

### Auth0 Test Configuration

```typescript
// test/setup/auth0-config.ts
export const testAuth0Config = {
  domain: "test-tenant.us.auth0.com",
  clientId: "test-client-id",
  audience: "https://test-api.example.com",
  redirectUri: "http://localhost:3000/callback",
  scope: "openid profile email",
};
```

### Mock Service Worker Setup

```typescript
// test/setup/server.ts
import { setupServer } from "msw/node";
import { rest } from "msw";
import { testAuth0Config } from "./auth0-config";

// Mock user profile
const mockUser = {
  sub: "auth0|123456789",
  nickname: "testuser",
  name: "Test User",
  picture: "https://example.com/avatar.png",
  email: "test@example.com",
  email_verified: true,
};

// Mock tokens
const mockTokens = {
  access_token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  id_token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  refresh_token: "V2hhdCBhcmUgeW91IGRlY29kaW5nIHRoaXMgZm9yPw==",
  expires_in: 86400,
  token_type: "Bearer",
};

// Create MSW server with auth endpoints
export const server = setupServer(
  // Mock Auth0 token endpoint
  rest.post(
    `https://${testAuth0Config.domain}/oauth/token`,
    (req, res, ctx) => {
      return res(ctx.json(mockTokens));
    }
  ),

  // Mock Auth0 user info endpoint
  rest.get(`https://${testAuth0Config.domain}/userinfo`, (req, res, ctx) => {
    const authHeader = req.headers.get("authorization");

    if (!authHeader || !authHeader.includes("Bearer")) {
      return res(ctx.status(401));
    }

    return res(ctx.json(mockUser));
  }),

  // Mock your application's API endpoints
  rest.get("*/api/user/profile", (req, res, ctx) => {
    const authHeader = req.headers.get("authorization");

    if (!authHeader || !authHeader.includes("Bearer")) {
      return res(ctx.status(401));
    }

    return res(
      ctx.json({
        id: mockUser.sub,
        name: mockUser.name,
        email: mockUser.email,
        picture: mockUser.picture,
      })
    );
  })
);
```

### Jest Setup

```javascript
// jest.setup.js
import "@testing-library/jest-dom";
import { server } from "./test/setup/server";

// Establish API mocking before all tests
beforeAll(() => server.listen());

// Reset request handlers between tests
afterEach(() => server.resetHandlers());

// Clean up after all tests are done
afterAll(() => server.close());
```

## Mocking Authentication

### Auth Context Mock Provider

```tsx
// test/utils/auth-provider.tsx
import React from "react";
import { AuthContext } from "../../src/contexts/auth";

type AuthState = "authenticated" | "unauthenticated" | "loading";

interface MockUser {
  sub: string;
  name: string;
  email: string;
  picture?: string;
  [key: string]: any;
}

interface MockAuthProviderProps {
  children: React.ReactNode;
  user?: MockUser | null;
  authState?: AuthState;
  error?: Error | null;
}

// Standard test users
export const testUsers = {
  admin: {
    sub: "auth0|admin123",
    name: "Admin User",
    email: "admin@example.com",
    roles: ["admin"],
    permissions: ["read:any", "write:any", "delete:any"],
  },
  user: {
    sub: "auth0|user123",
    name: "Regular User",
    email: "user@example.com",
    roles: ["user"],
    permissions: ["read:own", "write:own"],
  },
  unverified: {
    sub: "auth0|unverified123",
    name: "Unverified User",
    email: "unverified@example.com",
    email_verified: false,
    roles: ["user"],
    permissions: [],
  },
};

export function MockAuthProvider({
  children,
  user = testUsers.user,
  authState = "authenticated",
  error = null,
}: MockAuthProviderProps) {
  // Create mock auth context
  const mockAuthContext = {
    user,
    isAuthenticated: authState === "authenticated",
    isLoading: authState === "loading",
    error,
    login: jest.fn(() => Promise.resolve()),
    logout: jest.fn(() => Promise.resolve()),
    getAccessToken: jest.fn(() => Promise.resolve("mock-access-token")),
  };

  return (
    <AuthContext.Provider value={mockAuthContext}>
      {children}
    </AuthContext.Provider>
  );
}
```

### Helper for Rendering with Auth

```tsx
// test/utils/render-with-auth.tsx
import { render, RenderOptions } from "@testing-library/react";
import { MockAuthProvider, testUsers } from "./auth-provider";

// Utility to render with auth context
export function renderWithAuth(
  ui: React.ReactElement,
  {
    user = testUsers.user,
    authState = "authenticated",
    error = null,
    ...renderOptions
  }: RenderOptions & {
    user?: any;
    authState?: "authenticated" | "unauthenticated" | "loading";
    error?: Error | null;
  } = {}
) {
  return render(
    <MockAuthProvider user={user} authState={authState} error={error}>
      {ui}
    </MockAuthProvider>,
    renderOptions
  );
}

// Usage example:
// const { getByText } = renderWithAuth(<ProfilePage />, { user: testUsers.admin });
```

## Unit Testing Auth Components

### Testing Auth Hooks

```tsx
// src/hooks/useAuth.test.tsx
import { renderHook, act } from "@testing-library/react";
import { useAuth } from "../../src/hooks/useAuth";
import { MockAuthProvider, testUsers } from "../utils/auth-provider";

describe("useAuth hook", () => {
  test("returns authenticated user when provided", async () => {
    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <MockAuthProvider user={testUsers.admin}>{children}</MockAuthProvider>
    );

    const { result } = renderHook(() => useAuth(), { wrapper });

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.user).toEqual(testUsers.admin);
    expect(result.current.isLoading).toBe(false);
  });

  test("returns unauthenticated when no user", async () => {
    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <MockAuthProvider user={null} authState="unauthenticated">
        {children}
      </MockAuthProvider>
    );

    const { result } = renderHook(() => useAuth(), { wrapper });

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.user).toBeNull();
  });

  test("login function is called correctly", async () => {
    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <MockAuthProvider user={null} authState="unauthenticated">
        {children}
      </MockAuthProvider>
    );

    const { result } = renderHook(() => useAuth(), { wrapper });

    await act(async () => {
      await result.current.login();
    });

    expect(result.current.login).toHaveBeenCalled();
  });
});
```

### Testing Auth UI Components

```tsx
// src/components/LoginButton.test.tsx
import { render, screen, fireEvent } from "@testing-library/react";
import { LoginButton } from "../../src/components/LoginButton";
import { MockAuthProvider } from "../utils/auth-provider";

describe("LoginButton", () => {
  test("renders login button when not authenticated", () => {
    render(
      <MockAuthProvider user={null} authState="unauthenticated">
        <LoginButton />
      </MockAuthProvider>
    );

    const loginButton = screen.getByRole("button", { name: /log in/i });
    expect(loginButton).toBeInTheDocument();
  });

  test("does not render when authenticated", () => {
    render(
      <MockAuthProvider>
        <LoginButton />
      </MockAuthProvider>
    );

    const loginButton = screen.queryByRole("button", { name: /log in/i });
    expect(loginButton).not.toBeInTheDocument();
  });

  test("calls login function when clicked", () => {
    const mockLogin = jest.fn();

    render(
      <MockAuthProvider user={null} authState="unauthenticated">
        <LoginButton onClick={mockLogin} />
      </MockAuthProvider>
    );

    const loginButton = screen.getByRole("button", { name: /log in/i });
    fireEvent.click(loginButton);

    expect(mockLogin).toHaveBeenCalledTimes(1);
  });
});
```

### Testing Permission Utilities

```tsx
// src/utils/permissions.test.ts
import { hasPermission, hasRole } from "../../src/utils/permissions";
import { testUsers } from "../utils/auth-provider";

describe("Permission utilities", () => {
  test("hasPermission returns true when user has permission", () => {
    expect(hasPermission(testUsers.admin, "read:any")).toBe(true);
  });

  test("hasPermission returns false when user lacks permission", () => {
    expect(hasPermission(testUsers.user, "delete:any")).toBe(false);
  });

  test("hasPermission returns false when user is null", () => {
    expect(hasPermission(null, "read:any")).toBe(false);
  });

  test("hasRole returns true when user has role", () => {
    expect(hasRole(testUsers.admin, "admin")).toBe(true);
  });

  test("hasRole returns false when user lacks role", () => {
    expect(hasRole(testUsers.user, "admin")).toBe(false);
  });
});
```

## Testing Protected Routes

### Testing Client-Side Route Protection

```tsx
// src/components/ProtectedRoute.test.tsx
import { render, screen } from "@testing-library/react";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import { ProtectedRoute } from "../../src/components/ProtectedRoute";
import { MockAuthProvider, testUsers } from "../utils/auth-provider";

describe("ProtectedRoute", () => {
  test("renders children when user is authenticated", () => {
    render(
      <MockAuthProvider user={testUsers.user}>
        <MemoryRouter initialEntries={["/protected"]}>
          <Routes>
            <Route
              path="/protected"
              element={
                <ProtectedRoute>
                  <div>Protected Content</div>
                </ProtectedRoute>
              }
            />
          </Routes>
        </MemoryRouter>
      </MockAuthProvider>
    );

    expect(screen.getByText("Protected Content")).toBeInTheDocument();
  });

  test("redirects to login when user is not authenticated", () => {
    // Mock useNavigate
    const mockNavigate = jest.fn();
    jest.mock("react-router-dom", () => ({
      ...jest.requireActual("react-router-dom"),
      useNavigate: () => mockNavigate,
    }));

    render(
      <MockAuthProvider user={null} authState="unauthenticated">
        <MemoryRouter initialEntries={["/protected"]}>
          <Routes>
            <Route
              path="/protected"
              element={
                <ProtectedRoute>
                  <div>Protected Content</div>
                </ProtectedRoute>
              }
            />
            <Route path="/login" element={<div>Login Page</div>} />
          </Routes>
        </MemoryRouter>
      </MockAuthProvider>
    );

    // Should not show protected content
    expect(screen.queryByText("Protected Content")).not.toBeInTheDocument();

    // Should have called navigate to redirect
    expect(mockNavigate).toHaveBeenCalledWith("/login", expect.anything());
  });

  test("shows loading state when authentication is being determined", () => {
    render(
      <MockAuthProvider authState="loading">
        <MemoryRouter initialEntries={["/protected"]}>
          <Routes>
            <Route
              path="/protected"
              element={
                <ProtectedRoute>
                  <div>Protected Content</div>
                </ProtectedRoute>
              }
            />
          </Routes>
        </MemoryRouter>
      </MockAuthProvider>
    );

    expect(screen.getByText("Loading...")).toBeInTheDocument();
  });
});
```

### Testing Server-Side Protected API Routes

```typescript
// src/pages/api/protected.test.ts
import { createRequest, createResponse } from "node-mocks-http";
import handler from "../../src/pages/api/protected";
import { testUsers } from "../utils/auth-provider";

// Mock the auth library
jest.mock("../../src/lib/auth", () => ({
  getSession: jest.fn(),
}));

import { getSession } from "../../src/lib/auth";

describe("Protected API Route", () => {
  test("returns 401 when not authenticated", async () => {
    // Mock getSession to return null (unauthenticated)
    (getSession as jest.Mock).mockResolvedValueOnce(null);

    const req = createRequest({
      method: "GET",
    });
    const res = createResponse();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(401);
    expect(JSON.parse(res._getData())).toEqual({
      error: "Not authenticated",
    });
  });

  test("returns 200 with data when authenticated", async () => {
    // Mock getSession to return a user (authenticated)
    (getSession as jest.Mock).mockResolvedValueOnce({
      user: testUsers.user,
    });

    const req = createRequest({
      method: "GET",
    });
    const res = createResponse();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    expect(JSON.parse(res._getData())).toHaveProperty("data");
  });

  test("returns 403 when lacking required permission", async () => {
    // User authenticated but lacks permission
    (getSession as jest.Mock).mockResolvedValueOnce({
      user: {
        ...testUsers.user,
        permissions: [], // No permissions
      },
    });

    const req = createRequest({
      method: "GET",
    });
    const res = createResponse();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(403);
    expect(JSON.parse(res._getData())).toEqual({
      error: "Insufficient permissions",
    });
  });
});
```

## Testing Authentication Failures

### Testing Login Failure Scenarios

```tsx
// src/components/LoginForm.test.tsx
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { rest } from "msw";
import { server } from "../setup/server";
import { LoginForm } from "../../src/components/LoginForm";

describe("LoginForm", () => {
  test("displays error message for invalid credentials", async () => {
    // Override the default mock to return an error
    server.use(
      rest.post("*/api/auth/login", (req, res, ctx) => {
        return res(
          ctx.status(401),
          ctx.json({ error: "Invalid email or password" })
        );
      })
    );

    render(<LoginForm />);

    // Fill and submit form
    await userEvent.type(screen.getByLabelText(/email/i), "user@example.com");
    await userEvent.type(screen.getByLabelText(/password/i), "wrongpassword");
    await userEvent.click(screen.getByRole("button", { name: /sign in/i }));

    // Check for error message
    await waitFor(() => {
      expect(
        screen.getByText(/invalid email or password/i)
      ).toBeInTheDocument();
    });
  });

  test("handles network errors during login", async () => {
    // Override the default mock to simulate a network error
    server.use(
      rest.post("*/api/auth/login", (req, res, ctx) => {
        return res.networkError("Failed to connect");
      })
    );

    render(<LoginForm />);

    // Fill and submit form
    await userEvent.type(screen.getByLabelText(/email/i), "user@example.com");
    await userEvent.type(screen.getByLabelText(/password/i), "password123");
    await userEvent.click(screen.getByRole("button", { name: /sign in/i }));

    // Check for network error message
    await waitFor(() => {
      expect(screen.getByText(/network error/i)).toBeInTheDocument();
    });
  });

  test("handles server errors during login", async () => {
    // Override the default mock to return a server error
    server.use(
      rest.post("*/api/auth/login", (req, res, ctx) => {
        return res(
          ctx.status(500),
          ctx.json({ error: "Internal server error" })
        );
      })
    );

    render(<LoginForm />);

    // Fill and submit form
    await userEvent.type(screen.getByLabelText(/email/i), "user@example.com");
    await userEvent.type(screen.getByLabelText(/password/i), "password123");
    await userEvent.click(screen.getByRole("button", { name: /sign in/i }));

    // Check for server error message
    await waitFor(() => {
      expect(screen.getByText(/server error/i)).toBeInTheDocument();
    });
  });
});
```

### Testing Expired Tokens

```tsx
// src/utils/refreshToken.test.ts
import { refreshAccessToken } from "../../src/utils/refreshToken";
import { rest } from "msw";
import { server } from "../setup/server";

describe("Token refresh functionality", () => {
  test("successfully refreshes expired token", async () => {
    // Mock refresh token response
    server.use(
      rest.post("*/oauth/token", (req, res, ctx) => {
        return res(
          ctx.json({
            access_token: "new-access-token",
            refresh_token: "new-refresh-token",
            expires_in: 86400,
          })
        );
      })
    );

    const result = await refreshAccessToken("expired-token", "refresh-token");

    expect(result).toEqual({
      accessToken: "new-access-token",
      refreshToken: "new-refresh-token",
      expiresIn: 86400,
    });
  });

  test("handles expired refresh token", async () => {
    // Mock invalid refresh token response
    server.use(
      rest.post("*/oauth/token", (req, res, ctx) => {
        return res(
          ctx.status(400),
          ctx.json({
            error: "invalid_grant",
            error_description: "Invalid refresh token",
          })
        );
      })
    );

    await expect(
      refreshAccessToken("expired-token", "invalid-refresh-token")
    ).rejects.toThrow(/invalid refresh token/i);
  });
});
```

## Integration Testing Auth Flows

### Testing Complete Login Flow

```tsx
// src/pages/login.integration.test.tsx
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { rest } from "msw";
import { server } from "../setup/server";
import LoginPage from "../../src/pages/login";

// Mock useNavigate
const mockNavigate = jest.fn();
jest.mock("react-router-dom", () => ({
  ...jest.requireActual("react-router-dom"),
  useNavigate: () => mockNavigate,
}));

describe("Login Page Integration", () => {
  test("successful login flow redirects to dashboard", async () => {
    render(
      <MemoryRouter>
        <LoginPage />
      </MemoryRouter>
    );

    // Fill and submit login form
    await userEvent.type(screen.getByLabelText(/email/i), "user@example.com");
    await userEvent.type(screen.getByLabelText(/password/i), "password123");
    await userEvent.click(screen.getByRole("button", { name: /sign in/i }));

    // Verify redirect after successful login
    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith("/dashboard");
    });
  });

  test("remembers user email with 'Remember me' option", async () => {
    // Setup: Mock localStorage
    const localStorageMock = (() => {
      let store: Record<string, string> = {};
      return {
        getItem: jest.fn((key) => store[key] || null),
        setItem: jest.fn((key, value) => {
          store[key] = value.toString();
        }),
        clear: jest.fn(() => {
          store = {};
        }),
      };
    })();

    Object.defineProperty(window, "localStorage", {
      value: localStorageMock,
    });

    render(
      <MemoryRouter>
        <LoginPage />
      </MemoryRouter>
    );

    // Fill form and check "Remember me"
    await userEvent.type(screen.getByLabelText(/email/i), "user@example.com");
    await userEvent.type(screen.getByLabelText(/password/i), "password123");
    await userEvent.click(screen.getByLabelText(/remember me/i));
    await userEvent.click(screen.getByRole("button", { name: /sign in/i }));

    // Verify email was saved to localStorage
    await waitFor(() => {
      expect(localStorageMock.setItem).toHaveBeenCalledWith(
        "rememberedEmail",
        "user@example.com"
      );
    });
  });
});
```

### Testing Auth Provider Integration

```tsx
// src/contexts/AuthProvider.integration.test.tsx
import { render, screen, waitFor } from "@testing-library/react";
import { rest } from "msw";
import { server } from "../setup/server";
import { AuthProvider, useAuth } from "../../src/contexts/auth";

// Test component that uses auth context
function TestComponent() {
  const { user, isLoading, isAuthenticated, error } = useAuth();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!isAuthenticated) return <div>Not authenticated</div>;

  return <div>Welcome, {user?.name}</div>;
}

describe("AuthProvider Integration", () => {
  test("loads user on mount when token exists", async () => {
    // Mock token in localStorage
    Object.defineProperty(window, "localStorage", {
      value: {
        getItem: jest.fn(() => "mock-token"),
        setItem: jest.fn(),
        removeItem: jest.fn(),
      },
      writable: true,
    });

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    // Should show loading initially
    expect(screen.getByText("Loading...")).toBeInTheDocument();

    // Then should show authenticated user
    await waitFor(() => {
      expect(screen.getByText(/welcome, test user/i)).toBeInTheDocument();
    });
  });

  test("handles authentication errors", async () => {
    // Mock token in localStorage
    Object.defineProperty(window, "localStorage", {
      value: {
        getItem: jest.fn(() => "invalid-token"),
        setItem: jest.fn(),
        removeItem: jest.fn(),
      },
      writable: true,
    });

    // Mock auth error
    server.use(
      rest.get("*/userinfo", (req, res, ctx) => {
        return res(ctx.status(401));
      })
    );

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    // Should show error after attempting to load user
    await waitFor(() => {
      expect(screen.getByText(/error/i)).toBeInTheDocument();
    });

    // Should clear the invalid token
    expect(window.localStorage.removeItem).toHaveBeenCalledWith("auth_token");
  });
});
```

## E2E Testing with Cypress

### Auth0 Login E2E Setup

```typescript
// cypress/support/commands.ts
declare global {
  namespace Cypress {
    interface Chainable {
      login: (email?: string, password?: string) => void;
      logout: () => void;
    }
  }
}

// Programmatic login command
Cypress.Commands.add(
  "login",
  (email = "test@example.com", password = "Password123!") => {
    // Auth0 login using Auth0 universal login - non-interactive login
    cy.log("Logging in programmatically");

    const options = {
      method: "POST",
      url: Cypress.env("auth0_token_url"),
      body: {
        grant_type: "password",
        username: email,
        password: password,
        audience: Cypress.env("auth0_audience"),
        scope: "openid profile email",
        client_id: Cypress.env("auth0_client_id"),
        client_secret: Cypress.env("auth0_client_secret"),
      },
    };

    cy.request(options).then(({ body }) => {
      // Store tokens in localStorage
      cy.window().then((win) => {
        win.localStorage.setItem("auth_token", body.access_token);
        win.localStorage.setItem("id_token", body.id_token);
        win.localStorage.setItem("refresh_token", body.refresh_token);
        win.localStorage.setItem(
          "expires_at",
          String(Date.now() + body.expires_in * 1000)
        );
      });
    });

    // Reload page to apply authentication
    cy.reload();
  }
);

// Logout command
Cypress.Commands.add("logout", () => {
  cy.log("Logging out programmatically");

  cy.window().then((win) => {
    win.localStorage.removeItem("auth_token");
    win.localStorage.removeItem("id_token");
    win.localStorage.removeItem("refresh_token");
    win.localStorage.removeItem("expires_at");
  });

  // Reload page to apply logout
  cy.reload();
});
```

### E2E Tests for Authentication Flows

```typescript
// cypress/e2e/auth.cy.ts
describe("Authentication Flows", () => {
  beforeEach(() => {
    cy.clearLocalStorage();
  });

  it("redirects to login when accessing protected page", () => {
    cy.visit("/dashboard");
    cy.url().should("include", "/login");
    cy.contains("Sign in").should("be.visible");
  });

  it("allows user to login and access protected pages", () => {
    cy.visit("/login");
    cy.get('input[name="email"]').type(Cypress.env("auth_username"));
    cy.get('input[name="password"]').type(Cypress.env("auth_password"));
    cy.get('button[type="submit"]').click();

    // Should redirect to dashboard
    cy.url().should("include", "/dashboard");
    cy.contains("Welcome").should("be.visible");
  });

  it("allows programmatic login via custom command", () => {
    cy.login();
    cy.visit("/dashboard");

    // Should be logged in and see dashboard
    cy.url().should("include", "/dashboard");
    cy.contains("Welcome").should("be.visible");
  });

  it("maintains auth state after page refresh", () => {
    cy.login();
    cy.visit("/dashboard");

    // Verify logged in
    cy.contains("Welcome").should("be.visible");

    // Refresh page
    cy.reload();

    // Still logged in
    cy.contains("Welcome").should("be.visible");
  });

  it("logs out user correctly", () => {
    cy.login();
    cy.visit("/dashboard");

    // Verify logged in
    cy.contains("Welcome").should("be.visible");

    // Find and click logout button
    cy.contains("Logout").click();

    // Should redirect to login page
    cy.url().should("include", "/login");
  });
});
```

## Security-Focused Testing

### Testing XSS Prevention

```typescript
// src/security/xssPrevention.test.ts
import { sanitizeInput, validateToken } from "../../src/security/auth";

describe("XSS Prevention", () => {
  test("sanitizes input with script tags", () => {
    const malicious = '<script>alert("XSS")</script>test@example.com';
    const sanitized = sanitizeInput(malicious);

    expect(sanitized).toBe("test@example.com");
    expect(sanitized).not.toContain("<script>");
  });

  test("sanitizes input with dangerous attributes", () => {
    const malicious = '<img src="x" onerror="alert(\'XSS\')" />';
    const sanitized = sanitizeInput(malicious);

    expect(sanitized).not.toContain("onerror");
  });
});
```

### Testing CSRF Protection

```typescript
// src/pages/api/auth/login.csrf.test.ts
import { createRequest, createResponse } from "node-mocks-http";
import handler from "../../../src/pages/api/auth/login";

// Mock CSRF validation
jest.mock("../../../src/lib/csrf", () => ({
  validateCSRFToken: jest.fn(),
}));

import { validateCSRFToken } from "../../../src/lib/csrf";

describe("CSRF Protection", () => {
  test("rejects requests without CSRF token", async () => {
    // Mock CSRF validation to fail
    (validateCSRFToken as jest.Mock).mockReturnValueOnce(false);

    const req = createRequest({
      method: "POST",
      body: {
        email: "user@example.com",
        password: "password123",
      },
    });
    const res = createResponse();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(403);
    expect(JSON.parse(res._getData())).toEqual({
      error: "Invalid CSRF token",
    });
  });

  test("processes requests with valid CSRF token", async () => {
    // Mock CSRF validation to pass
    (validateCSRFToken as jest.Mock).mockReturnValueOnce(true);

    const req = createRequest({
      method: "POST",
      body: {
        email: "user@example.com",
        password: "password123",
        csrfToken: "valid-token",
      },
    });
    const res = createResponse();

    await handler(req, res);

    // Should not get CSRF error (might get other auth errors but that's not what we're testing)
    expect(res._getStatusCode()).not.toBe(403);
    expect(JSON.parse(res._getData())).not.toHaveProperty(
      "error",
      "Invalid CSRF token"
    );
  });
});
```

## Common Pitfalls

### Using Real Credentials in Tests

❌ **Don't:** Use real credentials in test files

```typescript
// Don't do this
test("logs in successfully", async () => {
  const result = await loginUser(
    "real-admin@company.com",
    "ActualPassword123!"
  );
  expect(result.success).toBe(true);
});
```

✅ **Do:** Use environment variables or test accounts

```typescript
// Better approach
test("logs in successfully", async () => {
  const result = await loginUser(
    Cypress.env("auth_username"),
    Cypress.env("auth_password")
  );
  expect(result.success).toBe(true);
});

// Even better: mock the auth service
test("logs in successfully", async () => {
  // Mock auth service to avoid real calls
  mockAuthService.login.mockResolvedValueOnce({ success: true });

  const result = await loginUser("test@example.com", "test-password");
  expect(result.success).toBe(true);
});
```

### Testing Only the Happy Path

❌ **Don't:** Only test successful authentication

```typescript
// Only testing successful login
test("user can log in", async () => {
  render(<LoginForm />);
  // Fill form...
  // Submit...
  // Verify success...
});
```

✅ **Do:** Test multiple scenarios including failures

```typescript
// Test both success and failure paths
describe("LoginForm", () => {
  test("user can log in successfully", async () => {
    // Test success case
  });

  test("shows validation errors for empty fields", async () => {
    // Test validation
  });

  test("shows error for invalid credentials", async () => {
    // Test auth failure
  });

  test("handles server errors gracefully", async () => {
    // Test 500 error
  });

  test("handles network errors", async () => {
    // Test network failure
  });
});
```

### Not Testing Token Refresh

❌ **Don't:** Ignore token refresh scenarios

```typescript
// Only testing initial authentication
test("authenticated user can access dashboard", async () => {
  // Login
  // Visit dashboard
  // Verify content
});
```

✅ **Do:** Test token refresh and expiry handling

```typescript
// Testing token refresh
test("refreshes token when expired", async () => {
  // Setup with expired token
  mockAuthService.getAccessToken.mockImplementationOnce(() => {
    throw new Error("Token expired");
  });

  mockAuthService.refreshToken.mockResolvedValueOnce({
    accessToken: "new-token",
    expiresIn: 3600,
  });

  // Attempt to access protected resource
  const result = await authClient.fetchProtectedResource();

  // Verify token was refreshed
  expect(mockAuthService.refreshToken).toHaveBeenCalled();
  expect(result.success).toBe(true);
});
```

## Conclusion

Comprehensive authentication testing is crucial for application security and reliability. By implementing the patterns in this guide, you can ensure your authentication system works correctly across all scenarios, from happy paths to edge cases and security vulnerabilities.

For more details on authentication testing requirements, refer to the `400-auth-testing-patterns.mdc` rule.

## Resources

- [Testing Library Documentation](https://testing-library.com/docs/)
- [Cypress Authentication Recipes](https://docs.cypress.io/guides/testing-strategies/auth0-authentication)
- [Mock Service Worker Documentation](https://mswjs.io/docs/)
- [Auth0 Testing Best Practices](https://auth0.com/docs/secure/security-guidance/data-security/testing)
