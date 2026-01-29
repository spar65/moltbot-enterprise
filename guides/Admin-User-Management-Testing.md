# Admin User Management Testing Guide

## Overview

This guide outlines best practices for testing Admin User Management functionality in the VibeCoder platform. It provides practical examples, patterns, and approaches that have been proven effective in our implementation.

## Key Testing Principles

1. **Test Real Behavior, Mock Dependencies**

   - Test actual components and handlers
   - Mock external dependencies (Auth0, database, etc.)
   - Avoid mocking your own application logic

2. **Test Both Success and Error Paths**

   - Don't just test the happy path
   - Include tests for unauthorized access
   - Test error handling and edge cases

3. **Ensure Test Isolation**
   - Properly reset state between tests
   - Use fresh mocks for each test
   - Avoid test interdependencies

## Testing Layers

### Unit Testing Admin Components

Unit tests for admin UI components focus on rendering, user interactions, and state management. Here's how to approach them:

```tsx
// tests/components/AdminUserTable.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AdminUserTable } from "../../src/components/admin/AdminUserTable";

describe("AdminUserTable", () => {
  const mockUsers = [
    {
      id: "user1",
      email: "user1@example.com",
      name: "User One",
      subscription_tier: "basic",
    },
    {
      id: "user2",
      email: "user2@example.com",
      name: "User Two",
      subscription_tier: "premium",
    },
  ];

  it("should render all users provided in props", () => {
    render(<AdminUserTable users={mockUsers} />);

    // Check both users are displayed
    expect(screen.getByText("User One")).toBeInTheDocument();
    expect(screen.getByText("User Two")).toBeInTheDocument();
    expect(screen.getByText("user1@example.com")).toBeInTheDocument();
    expect(screen.getByText("user2@example.com")).toBeInTheDocument();
  });

  it("should allow sorting when column header is clicked", async () => {
    const handleSortMock = jest.fn();
    render(<AdminUserTable users={mockUsers} onSort={handleSortMock} />);

    // Click the email column header
    await userEvent.click(screen.getByRole("columnheader", { name: /email/i }));

    // Check that the sort handler was called with correct arguments
    expect(handleSortMock).toHaveBeenCalledWith("email", "asc");

    // Click again to toggle sort direction
    await userEvent.click(screen.getByRole("columnheader", { name: /email/i }));
    expect(handleSortMock).toHaveBeenCalledWith("email", "desc");
  });

  it("should handle empty user array", () => {
    render(<AdminUserTable users={[]} />);

    // Check empty state message
    expect(screen.getByText(/no users found/i)).toBeInTheDocument();
  });
});
```

### Testing Admin API Handlers

API handler tests verify that endpoints correctly handle admin authorization and perform the expected actions:

```typescript
// tests/api/admin-users.test.ts
import { createMocks } from "node-mocks-http";
import handler from "../../pages/api/admin/users";
import {
  setupAuth0Mock,
  createMockAdminSession,
  createMockRegularSession,
} from "../utils/auth0-test-utils";

// Mock database module
jest.mock("../../src/lib/database", () => ({
  sql: jest.fn().mockImplementation(() =>
    Promise.resolve([
      { id: "user1", email: "user1@example.com", name: "User One" },
      { id: "user2", email: "user2@example.com", name: "User Two" },
    ])
  ),
}));

describe("/api/admin/users", () => {
  let mockAuth0;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.resetModules();
  });

  it("should return users list for admin users", async () => {
    // Setup admin session
    mockAuth0 = setupAuth0Mock(createMockAdminSession());

    const { req, res } = createMocks({
      method: "GET",
    });

    await handler(req, res);

    // Verify response
    expect(res._getStatusCode()).toBe(200);
    const data = JSON.parse(res._getData());
    expect(data).toHaveProperty("users");
    expect(data.users).toHaveLength(2);
    expect(data.users[0].id).toBe("user1");
  });

  it("should block non-admin users with 403", async () => {
    // Setup regular user session (non-admin)
    mockAuth0 = setupAuth0Mock(createMockRegularSession());

    const { req, res } = createMocks({
      method: "GET",
    });

    await handler(req, res);

    // Verify response is 403 forbidden
    expect(res._getStatusCode()).toBe(403);
    const error = JSON.parse(res._getData());
    expect(error).toHaveProperty("error");
  });

  it("should support pagination parameters", async () => {
    // Setup admin session
    mockAuth0 = setupAuth0Mock(createMockAdminSession());

    const { req, res } = createMocks({
      method: "GET",
      query: {
        page: "2",
        limit: "10",
      },
    });

    await handler(req, res);

    // Verify pagination parameters were used
    const { sql } = require("../../src/lib/database");
    expect(sql).toHaveBeenCalledWith(
      expect.stringMatching(/OFFSET \$[0-9]+ LIMIT \$[0-9]+/),
      expect.arrayContaining([10, 10]) // Offset = page * limit - limit, Limit = limit
    );
  });
});
```

### Testing Admin Authentication Middleware

Test middleware that protects admin routes:

```typescript
// tests/middleware/admin-middleware.test.ts
import { createMocks } from "node-mocks-http";
import { adminMiddleware } from "../../src/middleware/admin";
import {
  setupAuth0Mock,
  createMockAdminSession,
  createMockRegularSession,
} from "../utils/auth0-test-utils";

describe("Admin Middleware", () => {
  let mockAuth0;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.resetModules();
  });

  it("should call next() for admin users", async () => {
    // Setup admin session
    mockAuth0 = setupAuth0Mock(createMockAdminSession());

    const { req, res } = createMocks();
    const next = jest.fn();

    await adminMiddleware(req, res, next);

    // Verify next was called
    expect(next).toHaveBeenCalled();
    expect(res._getStatusCode()).not.toBe(403); // No forbidden response
  });

  it("should return 403 for non-admin users", async () => {
    // Setup regular user session
    mockAuth0 = setupAuth0Mock(createMockRegularSession());

    const { req, res } = createMocks();
    const next = jest.fn();

    await adminMiddleware(req, res, next);

    // Verify 403 response
    expect(res._getStatusCode()).toBe(403);
    expect(next).not.toHaveBeenCalled();
  });

  it("should return 401 for unauthenticated users", async () => {
    // Setup null session (no user)
    mockAuth0 = setupAuth0Mock(null);

    const { req, res } = createMocks();
    const next = jest.fn();

    await adminMiddleware(req, res, next);

    // Verify 401 response
    expect(res._getStatusCode()).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("should handle Auth0 errors gracefully", async () => {
    // Setup Auth0 to throw an error
    mockAuth0 = setupAuth0Mock();
    mockAuth0.getSession.mockRejectedValue(new Error("Auth0 Error"));

    const { req, res } = createMocks();
    const next = jest.fn();

    await adminMiddleware(req, res, next);

    // Verify 500 response
    expect(res._getStatusCode()).toBe(500);
    expect(next).not.toHaveBeenCalled();
  });
});
```

### Integration Testing Admin Workflows

Test complete admin workflows that span multiple API calls:

```typescript
// tests/integration/admin-user-workflow.test.ts
import { createMocks } from "node-mocks-http";
import {
  setupAuth0Mock,
  createMockAdminSession,
} from "../utils/auth0-test-utils";
import listHandler from "../../pages/api/admin/users";
import detailHandler from "../../pages/api/admin/users/[userId]";
import updateHandler from "../../pages/api/admin/users/[userId]/update";

// Mock database responses
jest.mock("../../src/lib/database", () => {
  const users = [
    {
      id: "user1",
      email: "user1@example.com",
      name: "User One",
      subscription_tier: "basic",
    },
    {
      id: "user2",
      email: "user2@example.com",
      name: "User Two",
      subscription_tier: "premium",
    },
  ];

  return {
    sql: jest.fn().mockImplementation((query, params) => {
      // Return different results based on the query
      if (query.toString().includes("SELECT * FROM users")) {
        if (params && params.includes("user1")) {
          return Promise.resolve([users[0]]);
        }
        return Promise.resolve(users);
      }

      if (query.toString().includes("UPDATE users")) {
        // Mock successful update
        return Promise.resolve({ rowCount: 1 });
      }

      return Promise.resolve([]);
    }),
  };
});

describe("Admin User Management Workflow", () => {
  let mockAuth0;

  beforeEach(() => {
    jest.clearAllMocks();
    // Setup admin session for all tests
    mockAuth0 = setupAuth0Mock(createMockAdminSession());
  });

  afterEach(() => {
    jest.resetModules();
  });

  it("should allow searching, viewing, and updating a user", async () => {
    // Step 1: List users to find the target user
    const listReq = createMocks({
      method: "GET",
      query: { search: "user1" },
    });

    await listHandler(listReq.req, listReq.res);

    // Verify user list response
    expect(listReq.res._getStatusCode()).toBe(200);
    const listData = JSON.parse(listReq.res._getData());
    expect(listData.users).toHaveLength(2);
    const userId = listData.users[0].id; // Get user ID for next step

    // Step 2: Get user details
    const detailReq = createMocks({
      method: "GET",
      query: { userId },
    });

    await detailHandler(detailReq.req, detailReq.res);

    // Verify user details response
    expect(detailReq.res._getStatusCode()).toBe(200);
    const userData = JSON.parse(detailReq.res._getData());
    expect(userData.user.id).toBe("user1");

    // Step 3: Update the user's subscription tier
    const updateReq = createMocks({
      method: "POST",
      query: { userId },
      body: {
        subscription_tier: "premium",
      },
    });

    await updateHandler(updateReq.req, updateReq.res);

    // Verify update response
    expect(updateReq.res._getStatusCode()).toBe(200);
    const updateData = JSON.parse(updateReq.res._getData());
    expect(updateData.success).toBe(true);

    // Verify database was called with correct parameters
    const { sql } = require("../../src/lib/database");
    const updateCall = sql.mock.calls.find((call) =>
      call[0].toString().includes("UPDATE users")
    );

    expect(updateCall).toBeDefined();
    expect(updateCall[1]).toContain("premium"); // New subscription tier
    expect(updateCall[1]).toContain("user1"); // User ID
  });
});
```

### End-to-End Testing with Cypress

Test the complete admin user interface using Cypress:

```typescript
// cypress/e2e/admin-user-management.cy.ts
describe("Admin User Management", () => {
  beforeEach(() => {
    // Custom Cypress command to log in as admin
    cy.loginAsAdmin();
  });

  it("should display user listing with search and filter", () => {
    cy.visit("/admin/users");

    // Check page structure
    cy.get("h1").should("contain", "User Management");
    cy.get(".user-table").should("be.visible");

    // Test search functionality
    cy.get(".search-input").type("test@example.com");
    cy.get(".search-button").click();

    // Wait for search results
    cy.get(".user-table tbody tr").should("have.length.at.least", 1);
    cy.get(".user-table").should("contain", "test@example.com");

    // Test filtering
    cy.get(".filter-dropdown").click();
    cy.get(".filter-option[data-value='premium']").click();

    // Check that filtered results contain premium users
    cy.get(".user-table tbody tr").each(($row) => {
      cy.wrap($row).should("contain", "Premium");
    });
  });

  it("should navigate to user details and perform subscription update", () => {
    // First visit the users page
    cy.visit("/admin/users");

    // Click on first user to view details
    cy.get(".user-table tbody tr").first().click();

    // Check we're on the user detail page
    cy.url().should("include", "/admin/users/");
    cy.get(".user-profile-header").should("be.visible");

    // Check subscription section
    cy.get(".subscription-details").should("be.visible");

    // Open edit subscription form
    cy.get(".edit-subscription-button").click();

    // Select new subscription tier
    cy.get("select[name=subscription_tier]").select("premium");

    // Submit form
    cy.get(".update-subscription-form").submit();

    // Check success message
    cy.get(".success-message").should("be.visible");
    cy.get(".success-message").should("contain", "Subscription updated");

    // Verify updated tier is displayed
    cy.get(".subscription-tier-badge").should("contain", "Premium");
  });
});
```

## Common Testing Patterns

### 1. Testing User Role Access

Test different access levels based on user roles:

```typescript
describe("Access Control Tests", () => {
  it("should allow admin access to admin page", async () => {
    // Setup admin session
    setupAuth0Mock(createMockAdminSession());

    const { result } = renderHook(() => useAdminCheck());
    await waitFor(() => {
      expect(result.current.isAdmin).toBe(true);
      expect(result.current.isLoading).toBe(false);
    });
  });

  it("should deny regular user access to admin page", async () => {
    // Setup regular user session
    setupAuth0Mock(createMockRegularSession());

    const { result } = renderHook(() => useAdminCheck());
    await waitFor(() => {
      expect(result.current.isAdmin).toBe(false);
      expect(result.current.isLoading).toBe(false);
    });
  });
});
```

### 2. Testing Data Filtering

Test filtering functionality in admin interfaces:

```typescript
it("should filter users by subscription status", async () => {
  // Setup admin session
  setupAuth0Mock(createMockAdminSession());

  const { req, res } = createMocks({
    method: "GET",
    query: {
      subscription_status: "active",
    },
  });

  await handler(req, res);

  // Verify database query included filter
  const { sql } = require("../../src/lib/database");
  expect(sql).toHaveBeenCalledWith(
    expect.stringMatching(/subscription_status = \$[0-9]+/),
    expect.arrayContaining(["active"])
  );
});
```

### 3. Testing Form Submissions

Test form submissions with validation:

```tsx
it("should validate form inputs before submission", async () => {
  render(<UserEditForm userId="user1" />);

  // Try to submit with invalid data
  await userEvent.clear(screen.getByLabelText(/email/i));
  await userEvent.type(screen.getByLabelText(/email/i), "invalid-email");

  // Submit form
  await userEvent.click(screen.getByRole("button", { name: /save/i }));

  // Check validation error is displayed
  expect(screen.getByText(/valid email/i)).toBeInTheDocument();

  // API should not be called with invalid data
  expect(mockUpdateUser).not.toHaveBeenCalled();

  // Fix the input and submit again
  await userEvent.clear(screen.getByLabelText(/email/i));
  await userEvent.type(screen.getByLabelText(/email/i), "valid@example.com");

  // Submit form
  await userEvent.click(screen.getByRole("button", { name: /save/i }));

  // API should be called now
  expect(mockUpdateUser).toHaveBeenCalledWith(
    "user1",
    expect.objectContaining({
      email: "valid@example.com",
    })
  );
});
```

## Best Practices

### 1. Centralize Auth0 Testing Utilities

Create reusable utilities for Auth0 testing:

```typescript
// tests/utils/auth0-test-utils.ts
export function setupAuth0Mock(session = null) {
  const mockGetSession = jest.fn().mockResolvedValue(session);

  jest.doMock("@auth0/nextjs-auth0", () => ({
    getSession: mockGetSession,
    withApiAuthRequired: (handler) => handler,
    useUser: () => ({
      user: session?.user || null,
      isLoading: false,
      error: null,
    }),
  }));

  return { getSession: mockGetSession };
}

export function createMockAdminSession() {
  return {
    user: {
      sub: "auth0|admin123",
      email: "admin@example.com",
      name: "Admin User",
      "https://vibecoder.com/roles": ["admin"],
    },
  };
}

export function createMockRegularSession() {
  return {
    user: {
      sub: "auth0|user123",
      email: "user@example.com",
      name: "Regular User",
    },
  };
}
```

### 2. Isolate Tests with Proper Setup and Teardown

Always use proper test isolation patterns:

```typescript
describe("AdminComponent", () => {
  beforeEach(() => {
    // Clear all mocks to prevent test interference
    jest.clearAllMocks();

    // Setup environment variables
    process.env.ADMIN_EMAILS = "admin@example.com";
  });

  afterEach(() => {
    // Reset modules to prevent state leaking between tests
    jest.resetModules();
  });

  // Tests...
});
```

### 3. Simulate API Responses

Create realistic API response simulations:

```typescript
// Mock database to return realistic data
const mockDb = {
  query: jest.fn().mockImplementation((query) => {
    // Return different mock data based on the query
    if (query.includes("users")) {
      return Promise.resolve([
        { id: "user1", name: "User One", email: "user1@example.com" },
        { id: "user2", name: "User Two", email: "user2@example.com" },
      ]);
    }

    if (query.includes("subscriptions")) {
      return Promise.resolve([
        { id: "sub1", user_id: "user1", tier: "premium", status: "active" },
      ]);
    }

    return Promise.resolve([]);
  }),
};

jest.mock("../../src/lib/database", () => ({
  sql: mockDb.query,
}));
```

## Common Testing Pitfalls

### 1. Testing State Leakage

**Problem:** Tests influence each other due to shared state.

**Solution:** Always reset mocks and modules between tests.

```typescript
// Bad - state leaks between tests
describe("AdminTests", () => {
  it("test1", async () => {
    // Mock that affects global state
  });

  it("test2", async () => {
    // Affected by previous test's state
  });
});

// Good - isolated tests
describe("AdminTests", () => {
  afterEach(() => {
    jest.resetAllMocks();
    jest.resetModules();
  });

  it("test1", async () => {
    // Setup isolated state
  });

  it("test2", async () => {
    // Fresh state, not affected by previous test
  });
});
```

### 2. Inconsistent Mock Implementations

**Problem:** Different mock implementations across tests create inconsistent behavior.

**Solution:** Centralize mock implementations in utilities.

```typescript
// Bad - inconsistent mocking
it("test1", () => {
  jest.doMock("@auth0/nextjs-auth0", () => ({
    getSession: () => ({ user: { email: "admin@example.com" } }),
    // Missing other properties
  }));
});

// Good - consistent mocking
it("test1", () => {
  setupAuth0Mock(createMockAdminSession());
  // Uses standardized mock implementation
});
```

### 3. Over-Mocking

**Problem:** Mocking too much code, including your own application logic.

**Solution:** Mock external dependencies, test real application code.

```typescript
// Bad - mocking our own components
jest.mock("../../components/AdminTable", () => ({
  AdminTable: () => <div>Mocked Table</div>,
}));

// Good - testing real components with mocked data
render(<AdminTable users={mockUsers} />);
```

## Conclusion

Testing Admin User Management functionality requires a comprehensive approach that validates both UI components and API endpoints. By following the patterns and best practices in this guide, you can create reliable tests that verify admin functionality while maintaining good test isolation and performance.

Remember the core principles:

1. Test real behavior, mock dependencies
2. Test both success and error paths
3. Ensure proper test isolation

These principles will help you create a robust test suite for your Admin User Management features.
