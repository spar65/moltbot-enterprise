# Auth0 Testing Guide

This guide outlines the testing patterns for Auth0 integration in our application. Auth0 is critical to our authentication and authorization systems, so comprehensive testing is essential.

## Test Suite Organization

We have implemented five key test suites:

1. **Token Verification Tests** (`tests/auth0/token-verification.test.ts`)

   - Tests JWT token validation and handling
   - Covers token expiration, invalid signatures, and proper validation

2. **API Authorization Tests** (`tests/auth0/api-authorization.test.ts`)

   - Tests permission-based access control for API routes
   - Ensures users with proper permissions can access resources
   - Ensures users without proper permissions are denied access

3. **User Database Synchronization Tests** (`tests/auth0/user-db-sync.test.ts`)

   - Tests synchronization between Auth0 user profiles and our database
   - Covers error handling for synchronization failures
   - Tests profile updates across both systems

4. **Error Handling Tests** (`tests/auth0/error-handling.test.ts`)

   - Tests client-side and server-side error handling for Auth0 failures
   - Ensures user-friendly error messages
   - Covers all common Auth0 error scenarios

5. **Roles and Permissions Tests** (`tests/auth0/roles.test.ts`)
   - Tests role-based access control
   - Verifies proper application of roles and permissions
   - Tests admin vs. regular user permissions

## Mocking Auth0

When testing Auth0 integration, we mock the Auth0 SDK to isolate our code from the actual Auth0 service. Common mocking patterns:

```typescript
// Mock the Auth0 SDK
jest.mock("@auth0/nextjs-auth0", () => ({
  withApiAuthRequired: jest.fn((handler) => handler),
  getSession: jest.fn(),
  getAccessToken: jest.fn(),
}));

// For client-side tests
jest.mock("@auth0/nextjs-auth0/client", () => ({
  useUser: jest.fn(),
}));
```

## Testing Protected API Routes

```typescript
import { createMocks } from "node-mocks-http";

// Create mock request/response
const { req, res } = createMocks({
  method: "GET",
  headers: {
    authorization: "Bearer mock-token",
  },
});

// Call your API handler
await apiHandler(req, res);

// Assert response
expect(res._getStatusCode()).toBe(200);
expect(JSON.parse(res._getData())).toEqual(expectedData);
```

## Testing Permission-Based Access

```typescript
// Test with permissions
const { req, res } = createMocks({
  method: "GET",
  headers: {
    "x-user-permissions": "read:data,write:data",
  },
});

// Call API with permission check
await apiWithPermissionCheck(req, res);

// Assert access granted
expect(res._getStatusCode()).toBe(200);
```

## Testing JWT Verification

```typescript
// Mock JWT library
jest.mock("jsonwebtoken", () => ({
  verify: jest.fn(),
  decode: jest.fn(),
}));

// Mock a valid token verification
(jwt.verify as jest.Mock).mockReturnValue({
  sub: "auth0|123456789",
  permissions: ["read:data"],
});

// Test with token
const result = await verifyToken("valid.mock.token");
expect(result.valid).toBe(true);
```

## Future Testing Areas

Additional testing areas to consider:

1. **Multi-Factor Authentication (MFA)** - Test MFA enrollment and verification
2. **Social Login Flows** - Test integration with social identity providers
3. **User Registration** - Test signup flows and email verification
4. **Session Management** - Test session timeout and refresh behaviors
5. **Rate Limiting** - Test protection against brute force attacks
6. **Performance Testing** - Test Auth0 integration under load

## Running Auth0 Tests

```bash
# Run all Auth0 tests
npx jest tests/auth0 --config=jest.config.mjs

# Run a specific test suite
npx jest tests/auth0/token-verification.test.ts --config=jest.config.mjs
```

## Required Dependencies

For Auth0 testing, ensure these dependencies are installed:

```bash
npm install --save-dev jsonwebtoken @types/jsonwebtoken node-mocks-http
```

## Integrating with CI/CD

Auth0 tests should be included in the CI/CD pipeline to ensure authentication and authorization remain secure through all code changes. Configure your CI system to run these tests on all PRs and commits to protected branches.
