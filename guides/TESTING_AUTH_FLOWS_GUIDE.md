# Testing Authentication Flows Guide

## Introduction

This guide provides practical strategies for testing authentication and authorization in web applications. It complements the `130-testing-auth-flows.mdc` rule with real-world examples and best practices.

## Table of Contents

1. [Authentication Testing Pyramid](#authentication-testing-pyramid)
2. [Unit Testing Authentication](#unit-testing-authentication)
3. [Component Testing](#component-testing)
4. [API Testing](#api-testing)
5. [Integration Testing](#integration-testing)
6. [E2E Testing](#e2e-testing)
7. [Security Testing](#security-testing)
8. [Advanced RBAC Testing](#advanced-rbac-testing)
9. [Common Pitfalls](#common-pitfalls)
10. [Test Setup & Mocking](#test-setup--mocking)
11. [Best Practices](#best-practices)

## Authentication Testing Pyramid

A comprehensive testing strategy for auth follows the testing pyramid:

```
    /\
   /  \      E2E Tests (Cypress, Playwright)
  /    \     • Complete login flows
 /      \    • Session persistence
/        \   • Redirects and protected routes
----------
\        /   Integration Tests
 \      /    • API + Auth middleware
  \    /     • Protected pages with auth
   \  /      • Permission checks
    \/
    /\
   /  \      Component Tests
  /    \     • Login forms
 /      \    • Auth UI components
/        \   • Permission-based rendering
----------
\        /   Unit Tests
 \      /    • Token validation
  \    /     • Auth utilities
   \  /      • Permission logic
    \/
```

## Unit Testing Authentication

### Token Utilities

Test JWT creation, validation, and expiration:

```typescript
// Token utility tests
test("verifyAuthToken rejects an expired token", async () => {
  // Create an expired token
  const expiredToken = jwt.sign(
    { sub: "user123", exp: Math.floor(Date.now() / 1000) - 3600 },
    "secret"
  );

  await expect(verifyAuthToken(expiredToken)).rejects.toThrow(/expired/i);
});
```

### Permission Logic

Test role-based access control:

```typescript
// Permission logic tests
test("hasPermission returns correct values based on user roles", () => {
  const adminUser = { roles: ["admin"] };
  const regularUser = { roles: ["user"] };

  expect(hasPermission(adminUser, "manage:users")).toBe(true);
  expect(hasPermission(regularUser, "manage:users")).toBe(false);
  expect(hasPermission(regularUser, "read:own")).toBe(true);
});
```

### Auth Hooks

Test custom authentication hooks:

```typescript
// Auth hook tests
test("useAuth fetches and sets user on initialization", async () => {
  // Mock API response
  mockFetch.mockResolvedValueOnce({
    ok: true,
    json: async () => ({ id: "user123", name: "Test User" }),
  });

  const { result, waitForNextUpdate } = renderHook(() => useAuth());

  // Initially loading with no user
  expect(result.current.loading).toBe(true);
  expect(result.current.user).toBe(null);

  // Wait for effect to run
  await waitForNextUpdate();

  // User loaded successfully
  expect(result.current.loading).toBe(false);
  expect(result.current.user).toEqual({ id: "user123", name: "Test User" });
});
```

## Component Testing

### Testing Login Forms

Test the login form UI and validation:

```typescript
// Login form tests
test("displays validation errors", async () => {
  render(<LoginForm />);

  // Submit empty form
  fireEvent.click(screen.getByRole("button", { name: /sign in/i }));

  // Check for validation errors
  expect(screen.getByText(/email is required/i)).toBeInTheDocument();
  expect(screen.getByText(/password is required/i)).toBeInTheDocument();
});
```

### Testing Protected Components

Test components that require authentication:

```typescript
// Protected component tests
test("renders content when user has required permission", () => {
  const user = { id: "user123", roles: ["editor"] };

  render(
    <AuthContext.Provider value={{ user, isAuthenticated: true }}>
      <ProtectedComponent requiredPermission="edit:content" />
    </AuthContext.Provider>
  );

  expect(screen.getByText(/protected content/i)).toBeInTheDocument();
});

test("does not render content when user lacks permission", () => {
  const user = { id: "user123", roles: ["viewer"] };

  render(
    <AuthContext.Provider value={{ user, isAuthenticated: true }}>
      <ProtectedComponent requiredPermission="edit:content" />
    </AuthContext.Provider>
  );

  expect(screen.queryByText(/protected content/i)).not.toBeInTheDocument();
});
```

## API Testing

### Testing Protected API Routes

Test API routes with authentication:

```typescript
// API route tests
test("returns 401 when not authenticated", async () => {
  // Mock auth to return null (not authenticated)
  mockGetServerUser.mockResolvedValueOnce(null);

  const { req, res } = createMocks({
    method: "GET",
    url: "/api/protected-data",
  });

  await handler(req, res);

  expect(res._getStatusCode()).toBe(401);
});

test("returns data when authenticated", async () => {
  // Mock authenticated user
  const mockUser = { id: "user123" };
  mockGetServerUser.mockResolvedValueOnce(mockUser);

  const { req, res } = createMocks({
    method: "GET",
    url: "/api/protected-data",
  });

  await handler(req, res);

  expect(res._getStatusCode()).toBe(200);
  expect(JSON.parse(res._getData())).toEqual(
    expect.objectContaining({ success: true })
  );
});
```

### Testing Auth Middleware

Test your authentication middleware:

```typescript
// Middleware tests
test("redirects to login for protected routes without token", async () => {
  const req = mockRequest({
    url: "/dashboard",
    cookies: {},
  });

  await middleware(req);

  // Verify redirect
  expect(NextResponse.redirect).toHaveBeenCalledWith(
    expect.stringContaining("/login")
  );
});
```

## Integration Testing

### Testing Protected Pages

Test server-side authentication for protected pages:

```typescript
// getServerSideProps authentication tests
test("redirects when not authenticated", async () => {
  // Mock auth check to fail
  mockGetServerUser.mockResolvedValueOnce(null);

  const context = {
    req: {},
    res: {},
    resolvedUrl: "/dashboard",
  };

  const result = await getServerSideProps(context);

  expect(result).toEqual({
    redirect: {
      destination: expect.stringContaining("/login"),
      permanent: false,
    },
  });
});
```

### Testing Auth Flows

Test complete authentication flows:

```typescript
// Auth flow tests
test("login success flow redirects to dashboard", async () => {
  // Setup
  mockRouter.push = jest.fn();
  mockFetch.mockResolvedValueOnce({
    ok: true,
    json: async () => ({ user: { id: "user123" } }),
  });

  render(<LoginPage />);

  // Enter credentials
  fireEvent.change(screen.getByLabelText(/email/i), {
    target: { value: "user@example.com" },
  });
  fireEvent.change(screen.getByLabelText(/password/i), {
    target: { value: "password123" },
  });

  // Submit form
  fireEvent.click(screen.getByRole("button", { name: /sign in/i }));

  // Verify redirect after successful login
  await waitFor(() => {
    expect(mockRouter.push).toHaveBeenCalledWith("/dashboard");
  });
});
```

## E2E Testing

### Cypress Auth Testing

Test complete auth flows with Cypress:

```typescript
// Cypress auth tests
describe("Authentication", () => {
  it("redirects to login when accessing protected page", () => {
    cy.visit("/dashboard");
    cy.url().should("include", "/login");
  });

  it("allows login and access to protected pages", () => {
    // Visit login page
    cy.visit("/login");

    // Enter credentials
    cy.get('[data-testid="email-input"]').type("user@example.com");
    cy.get('[data-testid="password-input"]').type("password123");

    // Submit form
    cy.get('[data-testid="login-button"]').click();

    // Should redirect to dashboard
    cy.url().should("include", "/dashboard");

    // Should display user information
    cy.get('[data-testid="user-greeting"]').should("contain", "Welcome");
  });
});
```

### Session Persistence

Test session persistence across page refreshes:

```typescript
// Session persistence tests
it("maintains session after page refresh", () => {
  // Login first
  cy.login("user@example.com", "password123");

  // Visit dashboard
  cy.visit("/dashboard");

  // Verify logged in
  cy.get('[data-testid="user-menu"]').should("be.visible");

  // Refresh the page
  cy.reload();

  // Still logged in
  cy.get('[data-testid="user-menu"]').should("be.visible");
});
```

## Security Testing

### XSS Protection

Test protection against XSS in auth forms:

```typescript
// XSS protection tests
test("sanitizes user inputs", async () => {
  // Mock fetch to inspect request body
  global.fetch = jest.fn().mockImplementation((url, options) => {
    requestBody = JSON.parse(options.body);
    return Promise.resolve({
      ok: true,
      json: () => Promise.resolve({ success: true }),
    });
  });

  const email = 'user@example.com<script>alert("XSS")</script>';
  const password = "password123";

  await login(email, password);

  // Email should be sanitized
  expect(requestBody.email).not.toContain("<script>");
  expect(requestBody.email).toBe("user@example.com");
});
```

### CSRF Protection

Test CSRF protection in authentication endpoints:

```typescript
// CSRF protection tests
test("rejects requests without CSRF token", async () => {
  const { req, res } = createMocks({
    method: "POST",
    url: "/api/auth/login",
    // Missing CSRF token
  });

  await loginHandler(req, res);

  expect(res._getStatusCode()).toBe(403);
  expect(JSON.parse(res._getData())).toEqual(
    expect.objectContaining({
      error: expect.stringMatching(/csrf/i),
    })
  );
});
```

## Advanced RBAC Testing

Role-Based Access Control (RBAC) requires thorough testing across different levels of your application. Here are comprehensive strategies for testing RBAC implementation:

### Testing Role Hierarchy

Test that role hierarchy is properly implemented:

```typescript
// src/lib/auth/__tests__/role-hierarchy.test.ts
import {
  ROLES,
  ROLE_HIERARCHY,
  ROLE_PERMISSIONS,
  userHasPermission,
} from "../rbac";

describe("Role Hierarchy", () => {
  // Test users with different roles
  const adminUser = { id: "admin-123", roles: [ROLES.ADMIN] };
  const editorUser = { id: "editor-123", roles: [ROLES.EDITOR] };
  const regularUser = { id: "user-123", roles: [ROLES.USER] };
  const guestUser = { id: "guest-123", roles: [ROLES.GUEST] };

  test("higher roles inherit permissions from lower roles", () => {
    // Get all permissions from lower roles
    const userPermissions = ROLE_PERMISSIONS[ROLES.USER];
    const guestPermissions = ROLE_PERMISSIONS[ROLES.GUEST];

    // Admin should have all permissions from USER role
    userPermissions.forEach((permission) => {
      expect(userHasPermission(adminUser, permission)).toBe(true);
    });

    // Editor should have all permissions from USER role
    userPermissions.forEach((permission) => {
      expect(userHasPermission(editorUser, permission)).toBe(true);
    });

    // User should have all permissions from GUEST role
    guestPermissions.forEach((permission) => {
      expect(userHasPermission(regularUser, permission)).toBe(true);
    });
  });

  test("lower roles do not have permissions from higher roles", () => {
    // Get admin-specific permissions
    const adminPermissions = ROLE_PERMISSIONS[ROLES.ADMIN];

    // Editor should not have admin permissions
    adminPermissions.forEach((permission) => {
      if (!ROLE_PERMISSIONS[ROLES.EDITOR].includes(permission)) {
        expect(userHasPermission(editorUser, permission)).toBe(false);
      }
    });

    // User should not have editor permissions
    const editorPermissions = ROLE_PERMISSIONS[ROLES.EDITOR];
    editorPermissions.forEach((permission) => {
      if (!ROLE_PERMISSIONS[ROLES.USER].includes(permission)) {
        expect(userHasPermission(regularUser, permission)).toBe(false);
      }
    });
  });

  test("users with multiple roles have combined permissions", () => {
    const multiRoleUser = {
      id: "multi-123",
      roles: [ROLES.USER, ROLES.EDITOR],
    };

    // Should have user permissions
    expect(userHasPermission(multiRoleUser, "read:own")).toBe(true);

    // Should have editor permissions
    expect(userHasPermission(multiRoleUser, "publish:any")).toBe(true);

    // Should not have admin permissions
    expect(userHasPermission(multiRoleUser, "manage:users")).toBe(false);
  });
});
```

### Testing Permission Boundary Components

Test components that enforce permission boundaries:

```typescript
// src/components/__tests__/PermissionBoundary.test.tsx
import { render, screen } from "@testing-library/react";
import { PermissionBoundary } from "../PermissionBoundary";
import { AuthContext } from "../../lib/auth/context";

describe("PermissionBoundary", () => {
  // Test users
  const adminUser = {
    id: "admin-123",
    roles: ["admin"],
    permissions: ["manage:users", "manage:content", "read:any", "write:any"],
  };

  const editorUser = {
    id: "editor-123",
    roles: ["editor"],
    permissions: ["read:any", "write:any", "publish:any"],
  };

  const regularUser = {
    id: "user-123",
    roles: ["user"],
    permissions: ["read:own", "write:own"],
  };

  // Mock AuthContext provider
  const renderWithAuth = (ui, user) => {
    return render(
      <AuthContext.Provider
        value={{
          user,
          isAuthenticated: !!user,
          hasPermission: (permission) =>
            user?.permissions.includes(permission) || false,
        }}
      >
        {ui}
      </AuthContext.Provider>
    );
  };

  test("renders children when user has all required permissions", () => {
    renderWithAuth(
      <PermissionBoundary requiredPermissions={["read:any", "write:any"]}>
        <div data-testid="protected-content">Protected Content</div>
      </PermissionBoundary>,
      adminUser
    );

    expect(screen.getByTestId("protected-content")).toBeInTheDocument();
  });

  test("renders children when user has any required permission with requireAll=false", () => {
    renderWithAuth(
      <PermissionBoundary
        requiredPermissions={["manage:users", "publish:any"]}
        requireAll={false}
      >
        <div data-testid="protected-content">Protected Content</div>
      </PermissionBoundary>,
      editorUser
    );

    expect(screen.getByTestId("protected-content")).toBeInTheDocument();
  });

  test("does not render children when user lacks all required permissions", () => {
    renderWithAuth(
      <PermissionBoundary requiredPermissions={["manage:users"]}>
        <div data-testid="protected-content">Protected Content</div>
      </PermissionBoundary>,
      regularUser
    );

    expect(screen.queryByTestId("protected-content")).not.toBeInTheDocument();
  });

  test("renders fallback when provided and user lacks permissions", () => {
    renderWithAuth(
      <PermissionBoundary
        requiredPermissions={["manage:users"]}
        fallback={<div data-testid="fallback">Access Denied</div>}
      >
        <div data-testid="protected-content">Protected Content</div>
      </PermissionBoundary>,
      regularUser
    );

    expect(screen.queryByTestId("protected-content")).not.toBeInTheDocument();
    expect(screen.getByTestId("fallback")).toBeInTheDocument();
  });
});
```

### Testing Permission HOCs

Test Higher-Order Components that enforce permissions:

```typescript
// src/lib/auth/__tests__/withPermission.test.tsx
import { render, screen } from "@testing-library/react";
import { withPermission } from "../permissions";
import { AuthContext } from "../context";

describe("withPermission HOC", () => {
  // Create a test component
  const TestComponent = () => (
    <div data-testid="test-component">Test Component</div>
  );

  // Create a fallback component
  const FallbackComponent = () => (
    <div data-testid="fallback-component">Access Denied</div>
  );

  // Mock auth context
  const mockAuthContext = (user = null) => ({
    user,
    isAuthenticated: !!user,
    hasPermission: (permission) =>
      user?.permissions?.includes(permission) || false,
  });

  test("renders component when user has required permission", () => {
    // Create protected component
    const ProtectedComponent = withPermission(TestComponent, "read:any");

    // Render with auth context
    render(
      <AuthContext.Provider
        value={mockAuthContext({
          id: "user-123",
          permissions: ["read:any", "write:own"],
        })}
      >
        <ProtectedComponent />
      </AuthContext.Provider>
    );

    // Component should be rendered
    expect(screen.getByTestId("test-component")).toBeInTheDocument();
  });

  test("renders fallback when user lacks required permission", () => {
    // Create protected component with fallback
    const ProtectedComponent = withPermission(
      TestComponent,
      "manage:users",
      FallbackComponent
    );

    // Render with auth context
    render(
      <AuthContext.Provider
        value={mockAuthContext({
          id: "user-123",
          permissions: ["read:own", "write:own"],
        })}
      >
        <ProtectedComponent />
      </AuthContext.Provider>
    );

    // Fallback should be rendered instead
    expect(screen.queryByTestId("test-component")).not.toBeInTheDocument();
    expect(screen.getByTestId("fallback-component")).toBeInTheDocument();
  });

  test("renders nothing when no fallback provided and user lacks permission", () => {
    // Create protected component without fallback
    const ProtectedComponent = withPermission(TestComponent, "manage:users");

    // Render with auth context
    render(
      <AuthContext.Provider
        value={mockAuthContext({
          id: "user-123",
          permissions: ["read:own", "write:own"],
        })}
      >
        <ProtectedComponent />
      </AuthContext.Provider>
    );

    // Nothing should be rendered
    expect(screen.queryByTestId("test-component")).not.toBeInTheDocument();
    expect(screen.queryByTestId("fallback-component")).not.toBeInTheDocument();
  });
});
```

### Testing API Authorization

Test that API endpoints enforce proper authorization:

```typescript
// src/pages/api/__tests__/users.test.ts
import { createMocks } from "node-mocks-http";
import usersHandler from "../users";
import * as authUtils from "../../../lib/auth/server";

// Mock auth utilities
jest.mock("../../../lib/auth/server");

describe("Users API Authorization", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("returns 403 when user lacks required permission", async () => {
    // Mock authenticated user without required permission
    const mockUser = {
      id: "user-123",
      roles: ["user"],
      permissions: ["read:own", "write:own"],
    };

    (authUtils.getServerUser as jest.Mock).mockResolvedValueOnce(mockUser);
    (authUtils.hasPermission as jest.Mock).mockReturnValueOnce(false);

    const { req, res } = createMocks({
      method: "GET",
    });

    await usersHandler(req, res);

    expect(res._getStatusCode()).toBe(403);
    expect(JSON.parse(res._getData())).toEqual(
      expect.objectContaining({
        error: expect.stringMatching(/insufficient permissions/i),
      })
    );
  });

  test("allows access when user has required permission", async () => {
    // Mock authenticated user with required permission
    const mockUser = {
      id: "admin-123",
      roles: ["admin"],
      permissions: ["manage:users", "read:any"],
    };

    (authUtils.getServerUser as jest.Mock).mockResolvedValueOnce(mockUser);
    (authUtils.hasPermission as jest.Mock).mockReturnValueOnce(true);

    const { req, res } = createMocks({
      method: "GET",
    });

    await usersHandler(req, res);

    expect(res._getStatusCode()).toBe(200);
  });

  test("enforces different permissions for different methods", async () => {
    // Mock authenticated user with read permission but not write
    const mockUser = {
      id: "editor-123",
      roles: ["editor"],
      permissions: ["read:any", "write:own"],
    };

    (authUtils.getServerUser as jest.Mock).mockResolvedValueOnce(mockUser);

    // For GET request (requires read:any) - should allow
    (authUtils.hasPermission as jest.Mock).mockReturnValueOnce(true);

    const { req: getReq, res: getRes } = createMocks({
      method: "GET",
    });

    await usersHandler(getReq, getRes);

    expect(getRes._getStatusCode()).toBe(200);

    // Reset mocks
    jest.clearAllMocks();

    // For POST request (requires manage:users) - should deny
    (authUtils.getServerUser as jest.Mock).mockResolvedValueOnce(mockUser);
    (authUtils.hasPermission as jest.Mock).mockReturnValueOnce(false);

    const { req: postReq, res: postRes } = createMocks({
      method: "POST",
      body: { name: "New User" },
    });

    await usersHandler(postReq, postRes);

    expect(postRes._getStatusCode()).toBe(403);
  });
});
```

### Testing Resource-Based Authorization

Test authorization based on resource ownership:

```typescript
// src/lib/auth/__tests__/resource-permissions.test.ts
import { canAccessResource } from "../resource-permissions";

describe("Resource Permission Checks", () => {
  // Test users
  const regularUser = {
    id: "user-123",
    roles: ["user"],
    permissions: ["read:own", "write:own", "delete:own"],
  };

  const adminUser = {
    id: "admin-123",
    roles: ["admin"],
    permissions: ["read:any", "write:any", "delete:any"],
  };

  // Test resources
  const userOwnedResource = {
    id: "resource-123",
    owner_id: "user-123",
    title: "User Resource",
  };

  const otherUserResource = {
    id: "resource-456",
    owner_id: "other-user-789",
    title: "Other User Resource",
  };

  test("user can access their own resources", () => {
    expect(canAccessResource(regularUser, userOwnedResource, "read")).toBe(
      true
    );
    expect(canAccessResource(regularUser, userOwnedResource, "write")).toBe(
      true
    );
    expect(canAccessResource(regularUser, userOwnedResource, "delete")).toBe(
      true
    );
  });

  test("user cannot access resources owned by others", () => {
    expect(canAccessResource(regularUser, otherUserResource, "read")).toBe(
      false
    );
    expect(canAccessResource(regularUser, otherUserResource, "write")).toBe(
      false
    );
    expect(canAccessResource(regularUser, otherUserResource, "delete")).toBe(
      false
    );
  });

  test("admin can access any resource", () => {
    expect(canAccessResource(adminUser, userOwnedResource, "read")).toBe(true);
    expect(canAccessResource(adminUser, otherUserResource, "read")).toBe(true);
    expect(canAccessResource(adminUser, otherUserResource, "write")).toBe(true);
    expect(canAccessResource(adminUser, otherUserResource, "delete")).toBe(
      true
    );
  });

  test("handles resources with different owner field names", () => {
    const customResource = {
      id: "custom-123",
      userId: "user-123", // Different field name
      title: "Custom Resource",
    };

    // Test with custom owner field
    expect(
      canAccessResource(regularUser, customResource, "read", {
        ownerField: "userId",
      })
    ).toBe(true);
  });

  test("handles team-based resource sharing", () => {
    const teamResource = {
      id: "team-resource-123",
      owner_id: "other-user-456",
      team_ids: ["team-123", "team-456"],
      title: "Team Resource",
    };

    const userWithTeam = {
      id: "user-123",
      roles: ["user"],
      teams: ["team-123"],
      permissions: ["read:team", "write:team"],
    };

    expect(
      canAccessResource(userWithTeam, teamResource, "read", {
        checkTeamAccess: true,
        userTeamsField: "teams",
        resourceTeamsField: "team_ids",
      })
    ).toBe(true);
  });
});
```

### E2E Testing of Role-Based UI Elements

Create end-to-end tests for role-based UI visibility:

```typescript
// cypress/integration/rbac-ui.spec.ts
describe("Role-Based UI Elements", () => {
  it("shows admin features for admin users", () => {
    // Login as admin
    cy.login("admin@example.com", "password123");

    // Visit dashboard
    cy.visit("/dashboard");

    // Admin-only UI elements should be visible
    cy.get('[data-testid="admin-panel"]').should("be.visible");
    cy.get('[data-testid="user-management"]').should("be.visible");
    cy.get('[data-testid="settings-button"]').should("be.visible");
  });

  it("hides admin features for regular users", () => {
    // Login as regular user
    cy.login("user@example.com", "password123");

    // Visit dashboard
    cy.visit("/dashboard");

    // Admin-only UI elements should not be visible
    cy.get('[data-testid="admin-panel"]').should("not.exist");
    cy.get('[data-testid="user-management"]').should("not.exist");

    // User should still see their own settings
    cy.get('[data-testid="user-settings"]').should("be.visible");
  });

  it("shows editor features for editor role", () => {
    // Login as editor
    cy.login("editor@example.com", "password123");

    // Visit content section
    cy.visit("/content");

    // Editor UI elements should be visible
    cy.get('[data-testid="publish-button"]').should("be.visible");
    cy.get('[data-testid="edit-button"]').should("be.visible");

    // Admin-only elements should be hidden
    cy.get('[data-testid="delete-all-button"]').should("not.exist");
  });

  it("handles dynamic permission changes", () => {
    // Login as regular user
    cy.login("user@example.com", "password123");

    // Visit dashboard
    cy.visit("/dashboard");

    // Initially shouldn't see admin panel
    cy.get('[data-testid="admin-panel"]').should("not.exist");

    // Use test API to upgrade user role to admin
    cy.request("POST", "/api/test/upgrade-role", {
      email: "user@example.com",
      role: "admin",
    });

    // Refresh page to reflect new permissions
    cy.reload();

    // Should now see admin panel
    cy.get('[data-testid="admin-panel"]').should("be.visible");
  });
});
```

## Common Pitfalls

### 1. Using Real Credentials in Tests

**Bad:**

```typescript
test("user can login", async () => {
  await login("real-user@company.com", "actual-password");
  // ...
});
```

**Good:**

```typescript
test("user can login", async () => {
  // Mock the auth service response
  mockAuthService.login.mockResolvedValueOnce({ success: true });

  await login("test@example.com", "test-password");
  // ...
});
```

### 2. Not Testing Error Scenarios

**Bad:**

```typescript
// Only testing the happy path
test("user can login", async () => {
  // Only test successful login
});
```

**Good:**

```typescript
// Testing both success and failure
test("shows error message on invalid credentials", async () => {
  mockFetch.mockResolvedValueOnce({
    ok: false,
    status: 401,
    json: async () => ({ error: "Invalid credentials" }),
  });

  // Test form submission and error display
});
```

### 3. Not Mocking External Auth Services

**Bad:**

```typescript
// Test makes real calls to Auth0
test("can get user profile", async () => {
  const profile = await auth0Client.getUser();
  expect(profile).toBeDefined();
});
```

**Good:**

```typescript
// Mock external auth service
jest.mock("@auth0/auth0-react");

test("can get user profile", async () => {
  // Mock the response
  mockAuth0.getUser.mockResolvedValueOnce({
    sub: "auth0|123",
    name: "Test User",
  });

  const profile = await authService.getUserProfile();
  expect(profile).toEqual(
    expect.objectContaining({
      id: "auth0|123",
      name: "Test User",
    })
  );
});
```

## Test Setup & Mocking

### Authentication Context Mocking

Create helpers for mocking auth context:

```typescript
// Auth context test helpers
function renderWithAuth(ui, { user = null, loading = false } = {}) {
  return render(
    <AuthContext.Provider value={{ user, loading, isAuthenticated: !!user }}>
      {ui}
    </AuthContext.Provider>
  );
}

// Usage
test("protected component with auth context", () => {
  const mockUser = { id: "user123", roles: ["admin"] };

  renderWithAuth(<ProtectedComponent />, { user: mockUser });

  // Test assertions...
});
```

### JWT Mocking

Create test JWT tokens:

```typescript
// JWT test helpers
function createTestToken(payload, options = {}) {
  const { expiresIn = "1h", secret = "test-secret" } = options;

  return jwt.sign(
    {
      sub: "user123",
      email: "test@example.com",
      ...payload,
    },
    secret,
    { expiresIn }
  );
}

// Usage
test("token validation", async () => {
  const token = createTestToken({ roles: ["admin"] });
  const user = await verifyAuthToken(token);

  expect(user).toEqual(
    expect.objectContaining({
      id: "user123",
      roles: ["admin"],
    })
  );
});
```

### Cypress Auth Commands

Create custom Cypress commands for authentication:

```typescript
// Cypress auth commands
Cypress.Commands.add("login", (email, password) => {
  // Either programmatically login via API
  cy.request({
    method: "POST",
    url: "/api/auth/login",
    body: { email, password },
  });

  // Or set auth cookies/localStorage directly
  cy.setCookie("auth_token", "test-token");
});

// Usage
it("test protected feature", () => {
  cy.login("test@example.com", "password123");
  cy.visit("/dashboard");
  // Test protected feature...
});
```

## Best Practices

1. **Mock Auth Providers**: Always mock external auth providers to avoid dependencies on external services
2. **Test Both Success & Failure**: Test successful login/authentication and failure scenarios
3. **Test Permission Logic**: Verify RBAC works correctly for different user roles
4. **Secure Test Credentials**: Never use real credentials in tests; use test fixtures instead
5. **Test Security Concerns**: Test token expiration, CSRF protection, and XSS prevention
6. **Test Redirects**: Verify unauthenticated users are properly redirected to login
7. **Test Return URLs**: Verify successful login redirects to the original destination
8. **Create Auth Testing Helpers**: Build reusable test utilities for auth testing
9. **Test Middleware & SSR**: Test server-side authentication logic thoroughly
10. **Test Logout Flow**: Verify logout properly clears authentication state

For detailed implementation examples, refer to the `130-testing-auth-flows.mdc` rule in your project.

## Conclusion

Comprehensive authentication testing is crucial for application security and reliability. By implementing the patterns in this guide, you can ensure your authentication system works correctly across all scenarios, from happy paths to edge cases and security vulnerabilities.

For more details on authentication testing requirements and specifications, refer to the `130-testing-auth-flows.mdc` rule.
